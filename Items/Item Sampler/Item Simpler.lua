-- @noindex


local version = '1.0.3'
local info = debug.getinfo(1, 'S');
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]];


--- Loading
dofile(script_path .. 'General Functions.lua') -- General Functions needed
dofile(script_path .. 'GUI Functions.lua') -- General Functions needed
dofile(script_path .. 'presets.lua') -- General Functions needed
dofile(script_path .. 'REAPER Functions.lua') -- preset to work with Tables


if not CheckSWS() or not CheckReaImGUI() or not CheckJS() then return end
-- Imgui shims to 0.7.2 (added after the news at 0.8)
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.7.2')

LoadInitialPreset()


function TableMin(tab)
    local min = math.huge
    for i = 1, #test_1  do
        min = min < test_1[i] and min or test_1[i]
    end
    return min
end

function ListItems()
    local list = {}
    local count = reaper.CountSelectedMediaItems(0)
    for i = 0, count do
        local loop_item = reaper.GetSelectedMediaItem(0, i)
        table.insert(list, loop_item)
    end
    return list
end

function CleanArea()
    local track_erase_list = {}
    -- Get list of tracks
    for k,item_loop in ipairs(list_sequence) do
        track_erase_list[reaper.GetMediaItemTrack(item_loop)] = 1
    end
    -- Make RE and delte
    local edge = 0.01 -- A liitle time folga
    for track_loop,_ in pairs(track_erase_list) do
        for _,midi_item in ipairs(list_midi) do
            local item_start = reaper.GetMediaItemInfo_Value(midi_item, "D_POSITION") 
            local item_len = reaper.GetMediaItemInfo_Value(midi_item, "D_LENGTH") 
            -- Clean with Comparasion
            local count_items = reaper.CountTrackMediaItems( track_loop )
            for item_track_loop_idx = count_items-1,0,-1 do 
                local item_comparasion = reaper.GetTrackMediaItem( track_loop, item_track_loop_idx )
                local item_comparasion_start = reaper.GetMediaItemInfo_Value(item_comparasion, "D_POSITION")
                if item_comparasion_start >= item_start-edge and item_comparasion_start <= (item_start+item_len)+edge then -- If item start at the middle of the midi item
                    reaper.DeleteTrackMediaItem( track_loop, item_comparasion )
                end
                -- break sooner 
                --if item_comparasion_start < item_start then break end
            end 
            -- Clean with RE
            reaper.Main_OnCommand(42406, 0) --Razor edit: Clear all areas
            SetTrackRazorEdit(track_loop, item_start, item_start+item_len , true) --track, areaStart, areaEnd, clearSelection)
            reaper.Main_OnCommand(40697, 0) -- Remove items/tracks/envelope points (depending on focus)
        end
    end
end

function Check() -- Return false if fails tests; return true if pass all tests

    if not list_midi then 
        print("Select some MIDI!")
        return false
    end

    if not list_sequence then
        print("Select some Items Sequence!")
        return false
    end

    if #list_midi < 1 then
        print("Select some MIDI!")
        return false
    end

    if #list_sequence < 1  then
        print("Select some Items Sequence!")
        return false
    end

    for k,item in pairs(list_midi) do
        local bol = reaper.ValidatePtr( item, 'MediaItem*' )
        if bol == false then
            print('At least one MIDI item is missing')
            print('Please reselect your Midi Items')
            return false
        end
    end

    
    for k,item in pairs(list_sequence) do
        local bol = reaper.ValidatePtr( item, 'MediaItem*' )
        if bol == false then
            print('At least one item in your sequence is missing')
            print('Please reselect your Item Sequence')
            return false
        end
    end

    return true
end

function Check2() -- Return false if fails tests; return true if pass all tests

    for k,item in pairs(list_midi) do
        local bol = reaper.ValidatePtr( item, 'MediaItem*' )
        if bol == false then
            print('ERROR: At least one MIDI item is in the Paste area')
            print('Please move it away')
            print('Action canceled')
            return false
        end
    end

    
    for k,item in pairs(list_sequence) do
        local bol = reaper.ValidatePtr( item, 'MediaItem*' )
        if bol == false then
            print('ERROR: At least one item from Item Sequence is in the Paste area')
            print('Please move it away')
            print('Action canceled')
            return false
        end
    end

    return true
end

function CleanArea2()
    local track_erase_list = {}
    -- Get list of tracks
    for k,item_loop in ipairs(list_sequence) do
        track_erase_list[reaper.GetMediaItemTrack(item_loop)] = 1
    end

    local edge = 0.01 -- A liitle time folga
    for track_loop,_ in pairs(track_erase_list) do
        for _,midi_item in ipairs(list_midi) do
            local item_start = reaper.GetMediaItemInfo_Value(midi_item, "D_POSITION") 
            local item_len = reaper.GetMediaItemInfo_Value(midi_item, "D_LENGTH") 
            -- Clean with Comparasion
            local count_items = reaper.CountTrackMediaItems( track_loop )
            for item_track_loop_idx = count_items-1,0,-1 do 
                local item_comparasion = reaper.GetTrackMediaItem( track_loop, item_track_loop_idx )
                local  retval, string = reaper.GetSetMediaItemInfo_String( item_comparasion, 'P_EXT:Simpler', '', false ) -- Get Ext
                if string ~= 'pasted' then 
                    goto continue
                end
                local item_comparasion_start = reaper.GetMediaItemInfo_Value(item_comparasion, "D_POSITION")
                if item_comparasion_start >= item_start-edge and item_comparasion_start <= (item_start+item_len)+edge then -- If item start at the middle of the midi item
                    reaper.DeleteTrackMediaItem( track_loop, item_comparasion )
                elseif item_comparasion_start < item_start then -- break sooner 
                    break
                end
                ::continue::
            end
        end
    end
    
end

function ChangeVolume(pasted_item, vel, Vel_OriginalVal, Vel_Min, Vel_Max)
    local vol_before = reaper.GetMediaItemInfo_Value(pasted_item, 'D_VOL' )
    local delta
    if vel < Vel_OriginalVal then
        delta = scale(vel,1,Vel_OriginalVal,Vel_Min,0) -- Scale vel (1 to Vel_Original)"MIDI" to (delta Settings.Vel_Min, 0)
    elseif vel > Vel_OriginalVal then
        delta = scale(vel,Vel_OriginalVal,127,0,Vel_Max) -- Scale vel (Vel_Original to 127)"MIDI" to (delta Settings.Vel_Min, 0)
    else -- vel == Vel_OriginalVal
        return
    end
    local new_val = AddDBinLinear(vol_before, delta)
    reaper.SetMediaItemInfo_Value( pasted_item, 'D_VOL',new_val)
end


function ChangePitch(pasted_item, pitch, Pitch_Original)
    local item_take = reaper.GetMediaItemTake(pasted_item, 0)
    local pitch_before = reaper.GetMediaItemTakeInfo_Value( item_take, 'D_PITCH' )
    local delta = pitch - Pitch_Original
    reaper.SetMediaItemTakeInfo_Value( item_take, 'D_PITCH', delta + pitch_before )    
end

function Place_Sequence(is_random,sequence_reverse,isrand_sequence)
    -- Check 
    if Check() == false then return end
    --Save Info
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    
    local selected_items = SaveSelectedItems()
    local selected_tracks = SaveSelectedTracks()

    -- Clean at MIDI item Not used for now Delete with time
    --[[ if Settings.Erase == true then
        CleanArea()
        if Check2() == false then
            reaper.Undo_EndBlock("Item Sequencer: Place", -1)
            reaper.Undo_DoUndo2(0)
            reaper.PreventUIRefresh(-1)
            return 
        end
    end ]]

    if Settings.Erase == true then
        CleanArea2(item)
    end

    -- Paste
    if is_random == true and isrand_sequence == true then
        not_used = {}
        for i = 1, #list_sequence do
            not_used[i] = i
        end
    end
    local counter = 0
    for i_midi = 1, #list_midi do
        local item = list_midi[i_midi]
        local item_take = reaper.GetMediaItemTake(item, 0)
        local retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(item_take)
        for idx_note = 0, notecnt-1 do
            local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( item_take, idx_note )
            local quarter = reaper.MIDI_GetProjQNFromPPQPos( item_take, startppqpos )
            local time = reaper.TimeMap2_QNToTime( 0, quarter )
            -- Filter if note start is out of item bounds (before and after)

            -- Choose Item
            local list_idx = 0
            if is_random == true then
                if isrand_sequence == false then -- Choose random can repeat 
                    list_idx = math.random(#list_sequence)
                else -- Choose random whitout repeating till start again
                    local rand_num = math.random(#list_sequence-(#list_sequence-#not_used))
                    list_idx = not_used[rand_num]
                    table.remove(not_used, rand_num) 
                    if #not_used == 0 then  --reset not_used list when full
                        for i = 1, #list_sequence do
                            not_used[i] = i
                        end
                    end
                end
            else
            -- Get item list idx
                if sequence_reverse == false then
                    list_idx = (counter%#list_sequence)+1
                else
                    list_idx = #list_sequence - (counter%#list_sequence)
                end
            end

            --  Copy 
            local paste_track = reaper.GetMediaItemTrack(list_sequence[list_idx])
            local pasted_item = CopyMediaItemToTrack(list_sequence[list_idx], paste_track, time )

            -- Set Volume Items 
            if Settings.Velocity == true then
                ChangeVolume(pasted_item, vel, Settings.Vel_OriginalVal,Settings.Vel_Min,Settings.Vel_Max)
            end
            
            -- Set Pitch 
            if Settings.Pitch == true then
                ChangePitch(pasted_item, pitch, Settings.Pitch_Original)
            end            
            

            -- Trim Item
            TrimItem(pasted_item, item, idx_note, notecnt, item_take, endppqpos )

            -- Set Ext State
            local  retval, stringNeedBig = reaper.GetSetMediaItemInfo_String( pasted_item, 'P_EXT:Simpler', 'pasted', true ) -- Set

            counter = counter + 1
        end
    end

    --Reset Things back
    LoadSelectedItems(selected_items)
    LoadSelectedTracks(selected_tracks)

    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Item Sequencer: Place", -1)
end

------ Gui Func
function HSV(h, s, v, a)
    local r, g, b = reaper.ImGui_ColorConvertHSVtoRGB(h, s, v)
    return reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a or 1.0)
end

function ChangeColor(H,S,V,A)
    reaper.ImGui_PushID(ctx, 3)
    local button = HSV( H, S, V, A)
    local hover =  HSV( H, S , (V+0.4 < 1) and V+0.4 or 1 , A)
    local active = HSV( H, S, (V+0.2 < 1) and V+0.2 or 1 , A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),  button)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), hover)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  active)
end

function ToolTip(text)
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_BeginTooltip(ctx)
        reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 35.0)
        reaper.ImGui_Text(ctx, text)
        reaper.ImGui_PopTextWrapPos(ctx)
        reaper.ImGui_EndTooltip(ctx)
    end
end

-- GUI init
function GuiInit()
    ctx = reaper.ImGui_CreateContext('Item Simpler') -- Add VERSION TODO
    FONT = reaper.ImGui_CreateFont('sans-serif', 15) -- Create the fonts you need
    reaper.ImGui_AttachFont(ctx, FONT)-- Attach the fonts you need
end

function loop()
    if not PreventPassKeys2 then -- Passthrough keys
        PassThorugh()
    end
    Ctrl, Shift, Alt = GetModKeys()
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(),              0x000000FF)

    local window_flags = reaper.ImGui_WindowFlags_MenuBar() 
    reaper.ImGui_SetNextWindowSize(ctx, 270, 300, reaper.ImGui_Cond_Once())-- Set the size of the windows.  Use in the 4th argument reaper.ImGui_Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2
    reaper.ImGui_PushFont(ctx, FONT)

    local visible, open  = reaper.ImGui_Begin(ctx, 'Item Simpler ' ..version, true, window_flags)


    local gui_w , gui_h = reaper.ImGui_GetContentRegionAvail( ctx)
    gui_w = gui_w -- 15
    gui_h = gui_h - 15
    --- GUI HERE
    n_lines = 4

    if visible then
        if reaper.ImGui_BeginMenuBar(ctx) then
            if reaper.ImGui_BeginMenu(ctx, 'Trim') then

                if reaper.ImGui_MenuItem(ctx, 'Clean Area Before Paste',"",Settings.Erase) then
                    Settings.Erase = not Settings.Erase
                end
                if Settings.Tips then ToolTip("Before pasting delete Any Item\nin the space of the Pasted Items") end

                if reaper.ImGui_MenuItem(ctx, 'Trim Items Using MIDI Item End',"",Settings.Is_trim_ItemEnd) then
                    Settings.Is_trim_ItemEnd = not Settings.Is_trim_ItemEnd
                end
                if Settings.Tips then ToolTip("The pasted items will be trimmed\nat the end of the MIDI item") end

                if reaper.ImGui_MenuItem(ctx, 'Trim Items Using Start Next Midi Note',"",Settings.Is_trim_StartNextNote) then
                    Settings.Is_trim_StartNextNote = not Settings.Is_trim_StartNextNote
                end
                if Settings.Tips then ToolTip("The pasted items will be trimmed\nat the start of the next MIDI note") end

                if reaper.ImGui_MenuItem(ctx, 'Trim Items Using End MIDI Note',"",Settings.Is_trim_EndNote) then
                    Settings.Is_trim_EndNote = not Settings.Is_trim_EndNote
                end
                if Settings.Tips then ToolTip("The pasted items will be trimmed\nat the end of the MIDI note") end


                
                
                reaper.ImGui_EndMenu(ctx)
            end
            reaper.ImGui_EndMenuBar(ctx)
        end

        if reaper.ImGui_BeginMenuBar(ctx) then
            if reaper.ImGui_BeginMenu(ctx, 'Velocity') then

                if reaper.ImGui_Checkbox(ctx, 'Velocity Change Item dB',Settings.Velocity) then
                    Settings.Velocity = not Settings.Velocity
                end
                local _

                local name =  'Max dB added'
                _, Settings.Vel_Max = reaper.ImGui_InputInt(ctx, name, Settings.Vel_Max)
                local focus = reaper.ImGui_IsItemFocused(ctx)
                PreventPassKeys2 = CheckPreventPassThrough(focus, name,PreventPassKeys2)

                local name = 'Max dB reduce'
                _, Settings.Vel_Min = reaper.ImGui_InputInt(ctx,  'Max dB reduce', Settings.Vel_Min)
                local focus = reaper.ImGui_IsItemFocused(ctx)
                PreventPassKeys2 = CheckPreventPassThrough(focus, name,PreventPassKeys2)

                _, Settings.Vel_OriginalVal = reaper.ImGui_SliderInt(ctx, 'Velocity to use original Item dB', Settings.Vel_OriginalVal, 0, 127)
                

                reaper.ImGui_EndMenu(ctx)

            end
            reaper.ImGui_EndMenuBar(ctx)
        end
        
        if reaper.ImGui_BeginMenuBar(ctx) then
            if reaper.ImGui_BeginMenu(ctx, 'Pitch') then

                if reaper.ImGui_Checkbox(ctx, 'MIDI Pitch Note Change Item Pitch',Settings.Pitch) then
                    Settings.Pitch = not Settings.Pitch
                end
                local _

                _, Settings.Pitch_Original = reaper.ImGui_SliderInt(ctx, 'Original Pitch at MIDI Note', Settings.Pitch_Original, 0, 127, NumberToNote(Settings.Pitch_Original, true))
                --_, Settings.Pitch_Original = reaper.ImGui_SliderInt(ctx, 'Original Pitch at MIDI Note', Settings.Pitch_Original, 0, 127)
                

                reaper.ImGui_EndMenu(ctx)

            end
            reaper.ImGui_EndMenuBar(ctx)
        end

        if reaper.ImGui_BeginMenuBar(ctx) then
            if reaper.ImGui_BeginMenu(ctx, 'Extra') then

                if reaper.ImGui_MenuItem(ctx, 'Show Tool Tips',"",Settings.Tips) then
                    Settings.Tips = not Settings.Tips
                end

                reaper.ImGui_EndMenu(ctx)

            end
            reaper.ImGui_EndMenuBar(ctx)
        end

        if reaper.ImGui_BeginMenuBar(ctx) then
            if reaper.ImGui_BeginMenu(ctx, 'Presets') then
                -- Save

                if reaper.ImGui_Button(ctx, 'Save Preset') then
                    reaper.ImGui_OpenPopup(ctx, 'Save Preset')
                end

                local center = {reaper.ImGui_Viewport_GetCenter(reaper.ImGui_GetMainViewport(ctx))}
                reaper.ImGui_SetNextWindowPos(ctx, center[1], center[2], reaper.ImGui_Cond_Appearing(), 0.5, 0.5)

                if reaper.ImGui_BeginPopupModal(ctx, 'Save Preset', nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
                    if reaper.ImGui_IsWindowAppearing(ctx) then
                        PreventPassKeys2 = CheckPreventPassThrough(true, 'preset', PreventPassKeys2)
                    end
                    _, GUI_String_save = reaper.ImGui_InputText( ctx, 'Preset Name', GUI_String_save)
                    reaper.ImGui_Separator(ctx)

                    if reaper.ImGui_Button(ctx, 'Save', 120, 0) then
                        if GUI_String_save == '' then
                            local tlen = TableLen2(UserPresets)+1
                            GUI_String_save = 'Preset Nº '..tlen
                        end

                        UserPresets[GUI_String_save] = table_copy(Settings)
                        save_json(script_path, 'user_presets', UserPresets)
                        PreventPassKeys2 = CheckPreventPassThrough(false, 'preset', PreventPassKeys2)
                        reaper.ImGui_CloseCurrentPopup(ctx)
                    end
                    reaper.ImGui_SameLine(ctx)
                    if reaper.ImGui_Button(ctx, 'Cancel', 120, 0) then 
                        PreventPassKeys2 = CheckPreventPassThrough(false, 'preset', PreventPassKeys2)
                        reaper.ImGui_CloseCurrentPopup(ctx) 
                    end
                    reaper.ImGui_EndPopup(ctx)
                end

                -- Load
                if reaper.ImGui_BeginMenu(ctx, 'Load') then

                    for key, value in pairs(UserPresets) do
                        if key == 'LS_Hide' then 
                            goto gui_continue 
                        end

                       if reaper.ImGui_MenuItem( ctx,  key) then
                           Settings = table_copy(UserPresets[key])
                       end

                       ::gui_continue::
                    end
                    reaper.ImGui_EndMenu(ctx)
                end

                --Remove
                if reaper.ImGui_BeginMenu(ctx, 'Remove') then

                    for key, value in pairs(UserPresets) do
                        if key == 'LS_Hide' or key == 'Default' then 
                            goto gui_continue 
                        end

                       if reaper.ImGui_MenuItem( ctx,  key) then
                            UserPresets[key] = nil
                            save_json(script_path, 'user_presets', UserPresets)
                       end

                       ::gui_continue::
                    end
                    reaper.ImGui_EndMenu(ctx)
                end
                
                reaper.ImGui_EndMenu(ctx)
            end
            reaper.ImGui_EndMenuBar(ctx)
        end




        
        --------- Get MIDI button
        ChangeColor(0.4,1,0.4,1)
        reaper.ImGui_Button(ctx, 'Get MIDI Item', gui_w, gui_h/n_lines)
        if reaper.ImGui_IsItemClicked( ctx) then
            list_midi = ListItems()
        end
        if Settings.Tips then ToolTip("Select the MIDI items with the notes\nwhere the items will be placed") end
        reaper.ImGui_PopStyleColor(ctx, 3); reaper.ImGui_PopID(ctx)

        --------- Get Items sequence Buttons
        reaper.ImGui_Button(ctx, 'Get Item Sequence', gui_w, gui_h/n_lines)
        if reaper.ImGui_IsItemClicked( ctx) then
            list_sequence = ListItems()
        end
        if Settings.Tips then ToolTip("Select a sequence of items to be placed\non the notes of the MIDI objects") end


        --------Place Button
        ChangeColor(1,1,0.4,1)
        reaper.ImGui_Button(ctx, 'Place in Sequence', gui_w, gui_h/n_lines)
        if reaper.ImGui_IsItemClicked( ctx) then
            local is_reverse = Ctrl
            Place_Sequence(false, is_reverse, false) -- (is_random,sequence_reverse,isrand_sequence)
        end
        if Settings.Tips then ToolTip("Click: Paste the items sequence in order\nCtrl+Click: Paste the sequence in reverse order") end
        reaper.ImGui_PopStyleColor(ctx, 3); reaper.ImGui_PopID(ctx)
        --------Place Random
        ChangeColor(0.15,1,0.4,1)
        reaper.ImGui_Button(ctx, 'Place Random', gui_w, gui_h/n_lines)
        if reaper.ImGui_IsItemClicked( ctx) then
            local is_rand_sequence = Ctrl
            Place_Sequence(true, false, is_rand_sequence)   --isrand_sequence     
        end
        if Settings.Tips then ToolTip("Click: Paste the items sequence randomly\nCtrl+Click: Paste the sequence randomly without repetitions") end
        reaper.ImGui_PopStyleColor(ctx, 3); reaper.ImGui_PopID(ctx)

        --------
        ----
        reaper.ImGui_End(ctx)
    end        
    reaper.ImGui_PopFont(ctx) 
    reaper.ImGui_PopStyleColor(ctx) -- pop background

        
    if open then
        reaper.defer(loop)
    else
        reaper.ImGui_DestroyContext(ctx)
    end
end

function encerrar()
    UserPresets.LS_Hide = table_copy(Settings)
    save_json(script_path, 'user_presets', UserPresets)
end

GuiInit()
loop()
reaper.atexit(encerrar)
