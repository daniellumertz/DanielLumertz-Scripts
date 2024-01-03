--@noindex
function GuiInitAI(ScriptName)
    ctx = reaper.ImGui_CreateContext(ScriptName) -- Add VERSION TODO
    -- Define Globals GUI
    Gui_W,Gui_H= 275,300
    FLT_MIN, FLT_MAX = reaper.ImGui_NumericLimits_Float()
    
    --- Text Font
    FontText = reaper.ImGui_CreateFont('sans-serif', 14) -- Create the fonts you need
    reaper.ImGui_Attach(ctx, FontText)-- Attach the fonts you need
end

function main_loop_ai()
    PushTheme()
    --demo.PushStyle(ctx)
    --demo.ShowDemoWindow(ctx)

    if not reaper.ImGui_IsAnyItemActive(ctx)  then -- maybe overcome TableHaveAnything
        PassKeys()
    end

    --- Window management
    local window_flags = reaper.ImGui_WindowFlags_NoResize() | reaper.ImGui_WindowFlags_AlwaysAutoResize() --reaper.ImGui_WindowFlags_MenuBar() -- | reaper.ImGui_WindowFlags_NoResize() | 
    if Pin then 
        window_flags = window_flags | reaper.ImGui_WindowFlags_TopMost()
    end 
    reaper.ImGui_SetNextWindowSize(ctx, Gui_W, Gui_H, reaper.ImGui_Cond_Once())-- Set the size of the windows.  Use in the 4th argument reaper.ImGui_Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2
    reaper.ImGui_PushFont(ctx, FontText) -- Says you want to start using a specific font

    local visible, open  = reaper.ImGui_Begin(ctx, ScriptName..' '..Version, true, window_flags)

    local _ --  values I will throw away
    if visible then
        --- GUI MAIN: 
        gui_ai()

        reaper.ImGui_End(ctx)
    end 
    
    -- OpenPopups() 
    reaper.ImGui_PopFont(ctx) -- Pop Font
    PopTheme()

    if open then
        --demo.PopStyle(ctx)
        reaper.defer(main_loop_ai)
    else
        reaper.ImGui_DestroyContext(ctx)
    end
end

function gui_ai()
    local _
    local ctrl = reaper.ImGui_IsKeyDown(ctx,  reaper.ImGui_Mod_Ctrl())
    local gset = ctrl and 'Select' or 'Set'
    if reaper.ImGui_Button(ctx, gset..' Source Track', -FLT_MIN) then
        if not ctrl then -- get
            options.source_track = reaper.GetSelectedTrack2(proj, 0, false)
        else -- select
            if options.source_track then
                reaper.SetOnlyTrackSelected(options.source_track)
            end
        end
    end
    if reaper.ImGui_Button(ctx, gset..' Destination Track', -FLT_MIN) then
        if not ctrl then -- get
            options.dest_track = {}
            for track in enumSelectedTracks2(proj,false) do
                if track ~= options.source_track then
                    table.insert(options.dest_track,track)
                else
                    print('Source Track Cant Be a Destination Track!')
                end
            end
        else -- select
            SelectTrackList(options.dest_track, true, proj)
        end
    end

    _, options.regions_textinput = reaper.ImGui_InputText(ctx, 'AI Regions', options.regions_textinput)
    --------------------------------------------------------------- Randomize Area
    local w_av,  h_av = reaper.ImGui_GetContentRegionAvail(ctx)
    reaper.ImGui_PushItemWidth(ctx, w_av-175)

    _, options.randomize = reaper.ImGui_Checkbox(ctx, 'Randomize Region per Paste', options.randomize)

    local change
    change, options.playrate_min = reaper.ImGui_InputDouble(ctx, 'Play Rate Random Min', options.playrate_min, 0, 0, "%.3f")
    if change then
        options.playrate_min = (options.playrate_min <= 0 and 0.001) or options.playrate_min -- cant have a play rate of 0 
        if options.playrate_min > options.playrate_max then options.playrate_max = options.playrate_min end
    end
    change, options.playrate_max = reaper.ImGui_InputDouble(ctx, 'Play Rate Random Max', options.playrate_max, 0, 0, "%.3f")
    if change then
        options.playrate_max = (options.playrate_max <= 0 and 0.001) or options.playrate_max-- cant have a play rate of 0 
        if options.playrate_min > options.playrate_max then options.playrate_min = options.playrate_max end
    end
    change, options.playrate_quantize = reaper.ImGui_InputDouble(ctx, 'Play Rate Random Quantize', options.playrate_quantize, 0, 0, "%.3f")
    if change then
        options.playrate_quantize = (options.playrate_quantize >= 0 and options.playrate_quantize) or 0
    end

    reaper.ImGui_PopItemWidth(ctx)
    --------------------------------------------------------------------

    if reaper.ImGui_Button(ctx,'Apply', -FLT_MIN) then
        apply_ai_gen()
    end
end

function apply_ai_gen()
    -- Check if all is OK
    if #options.dest_track == 0 then
        print('Select Destination Tracks')
        return
    end
    if not options.source_track then
        print('Select Source Tracks')
        return
    end
    for k,dest_track in ipairs(options.dest_track) do
        if options.source_track == dest_track then 
            print('Source Track Cant be a Destination Track!!')
            return
        end
    end
    -- count regions
    local regions_ids = {}
    for id in options.regions_textinput:gmatch('%d+') do
        id = tonumber(id)
        if GetMarkByID(proj,id,2) then -- need to check if it is a valid ID
            regions_ids[#regions_ids+1] = id
        end
    end
    if #regions_ids == 0 then
        print('Select Regions')
        return
    end

    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2(proj)

    -- Copy Automation Items
    local start, fim = reaper.GetSet_LoopTimeRange2(proj, false, true, 0, 0, false)
    for _, dest_track in ipairs(options.dest_track) do
        local dest_env  = { } -- table with common envelopes between source and destination. Will only copy if the envelope already exist. { {source = env, destination = dest_env_loop}, {source = env, destination = dest_env_loop} etc}
        for env in enumTrackEnvelopes(options.source_track) do
            local retval, env_name = reaper.GetEnvelopeName( env )
            for dest_env_loop in enumTrackEnvelopes(dest_track) do -- Check if the track have this specific envelope (volume, pan etc)
                local retval, env_dest_name = reaper.GetEnvelopeName( dest_env_loop )
                if env_name == env_dest_name then
                    table.insert(dest_env,{source = env, destination = dest_env_loop}) 
                    break
                end
            end
        end
        if #dest_env == 0 then goto continue end
        for k, envelopes in ipairs(dest_env) do
            local paste_start = start -- start pasting at the start of the loop
            local env_source = envelopes.source
            local env_destination = envelopes.destination
            -- select region
            local region = tonumber(GetFromTableRandom(regions_ids))
            -- Delete current AI 
            DeleteAutomationItemsInRange(proj,start,fim,false,false,env_destination)
            ---- Copy AI from regions
            while true do -- until the paste goes above the region_end
                if options.randomize then
                    region = tonumber(GetFromTableRandom(regions_ids))
                end

                local random_rate = RandomNumberFloat(options.playrate_min, options.playrate_max, true) 
                random_rate = QuantizeNumber(random_rate,options.playrate_quantize) 
                random_rate = random_rate > 0 and random_rate or options.playrate_quantize -- rate cannot be zero and quantize can quantize to zero if there is some quantization, then use the quantize value. ex. minrate = 0.2 quantize = 0.5 if it generate 0.2 it will quantize to 0 .
                -- Get AI in region
                local retval, isrgn, start_region, fim_region, mark_name, markrgnindexnumber, color, idx = GetMarkByID(proj,region,2)
                local paste_len = (fim_region - start_region) / random_rate

                local ai_items = GetAutomationItemsInRange(env_source, start_region,fim_region,false,false) -- get ai that passes by the region need to trim them after pasting
                for k , ai in ipairs(ai_items) do
                    local ai_id = reaper.GetSetAutomationItemInfo(env_source, ai, 'D_POOL_ID', 0, false)
                    local ai_pos = reaper.GetSetAutomationItemInfo(env_source, ai, 'D_POSITION', 0, false)
                    local ai_len = reaper.GetSetAutomationItemInfo(env_source, ai, 'D_LENGTH', 0, false)
                    local ai_rate = reaper.GetSetAutomationItemInfo(env_source, ai, 'D_PLAYRATE', 0, false)

                    local source_delta = ai_pos - start_region 

                    local new_pos = paste_start + (source_delta / random_rate)
                    if new_pos >= fim then break end  -- this item would be after the selected area
                    local new_len = ai_len / random_rate
                    local new_rate = ai_rate * random_rate
                    local new_ai = reaper.InsertAutomationItem(env_destination, ai_id, new_pos , new_len)
                    reaper.GetSetAutomationItemInfo(env_destination, new_ai, 'D_PLAYRATE', new_rate, true)
                    local trim_end = math.min(paste_start + paste_len, fim) -- trim items that goes beyond paste
                    CopyAutomationItemsInfo_Value(env_source, env_destination, ai, new_ai, {'D_BASELINE', 'D_AMPLITUDE', 'D_LOOPSRC', 'D_STARTOFFS'})
                    CropAutomationItem(env_destination,new_ai,paste_start,trim_end) -- paste start, end loop
                    
                end
                paste_start = paste_start + paste_len
                if paste_start >= fim then break end 
            end
        end

        ::continue:: -- jump destination track

    end

    reaper.UpdateArrange()
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock2(proj, 'Apply Generative Loops Automation Items', -1)
end