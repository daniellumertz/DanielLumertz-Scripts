--@noindex
function GuiInit(ScriptName)
    ctx = reaper.ImGui_CreateContext(ScriptName) -- Add VERSION TODO
    -- Define Globals GUI
    Gui_W,Gui_H= 250,360
    FLT_MIN, FLT_MAX = reaper.ImGui_NumericLimits_Float()
    
    --- Text Font
    FontText = reaper.ImGui_CreateFont('sans-serif', 14) -- Create the fonts you need
    reaper.ImGui_Attach(ctx, FontText)-- Attach the fonts you need
end

function main_loop()
    PushTheme()
    --demo.PushStyle(ctx)
    --demo.ShowDemoWindow(ctx)

    if not reaper.ImGui_IsAnyItemActive(ctx)  then -- maybe overcome TableHaveAnything
        PassKeys()
    end

    --- Window management
    local window_flags = reaper.ImGui_WindowFlags_NoResize()  --reaper.ImGui_WindowFlags_MenuBar() -- | reaper.ImGui_WindowFlags_NoResize() | 
    if Pin then 
        window_flags = window_flags | reaper.ImGui_WindowFlags_TopMost()
    end 
    reaper.ImGui_SetNextWindowSize(ctx, Gui_W, Gui_H, reaper.ImGui_Cond_Once())-- Set the size of the windows.  Use in the 4th argument reaper.ImGui_Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2
    reaper.ImGui_PushFont(ctx, FontText) -- Says you want to start using a specific font

    local visible, open  = reaper.ImGui_Begin(ctx, ScriptName..' '..Version, true, window_flags)

    local _ --  values I will throw away
    if visible then
        --- GUI MAIN: 
        if reaper.CountSelectedMediaItems(proj) ~= 0 then
            SelectedItemsGUI()
        else
            reaper.ImGui_Text(ctx, 'Select Some Item')
        end
        ------------
        reaper.ImGui_End(ctx)
    end 
    
    -- OpenPopups() 
    reaper.ImGui_PopFont(ctx) -- Pop Font
    PopTheme()

    if open then
        --demo.PopStyle(ctx)
        reaper.defer(main_loop)
    else
        reaper.ImGui_DestroyContext(ctx)
    end
end

function SelectedItemsGUI()
    GetOptions()
    local change
    local w_av,  h_av = reaper.ImGui_GetContentRegionAvail(ctx)
    reaper.ImGui_PushItemWidth(ctx, w_av-150)

    change, RandomizeTakes = reaper.ImGui_Checkbox(ctx, 'Randomize Takes', RandomizeTakes)
    if change then
        ApplyOptions()
    end
    --reaper.ImGui_SameLine(ctx)
    change, TakeChance = reaper.ImGui_InputDouble(ctx, 'Take Chance', TakeChance, 0, 0, "%.1f")
    if change then
        ApplyOptions()
    end

    reaper.ImGui_Separator(ctx) ------------------------
    change, TimeRandomMin = reaper.ImGui_InputDouble(ctx, 'Time Random Min', TimeRandomMin, 0, 0, "%.3f")
    if change then
        if TimeRandomMin > TimeRandomMax then TimeRandomMax = TimeRandomMin end
        ApplyOptions()
    end
    change, TimeRandomMax = reaper.ImGui_InputDouble(ctx, 'Time Random Max', TimeRandomMax, 0, 0, "%.3f")
    if change then
        if TimeRandomMin > TimeRandomMax then TimeRandomMin = TimeRandomMax end
        ApplyOptions()
    end
    change, TimeQuantize = reaper.ImGui_InputDouble(ctx, 'Time Quantize (sec)', TimeQuantize, 0, 0, "%.3f")
    if change then
        ApplyOptions()
    end
        
    reaper.ImGui_Separator(ctx) ------------------------
    change, PitchRandomMin = reaper.ImGui_InputDouble(ctx, 'Pitch Random Min', PitchRandomMin, 0, 0, "%.3f")
    if change then
        if PitchRandomMin > PitchRandomMax then PitchRandomMax = PitchRandomMin end
        ApplyOptions()
    end
    change, PitchRandomMax = reaper.ImGui_InputDouble(ctx, 'Pitch Random Max', PitchRandomMax, 0, 0, "%.3f")
    if change then
        if PitchRandomMin > PitchRandomMax then PitchRandomMin = PitchRandomMax end
        ApplyOptions()
    end
    change, PitchQuantize = reaper.ImGui_InputDouble(ctx, 'Pitch Quantize', PitchQuantize, 0, 0, "%.3f")
    if change then
        ApplyOptions()
    end

    reaper.ImGui_Separator(ctx) ------------------------
    change, PlayRateRandomMin = reaper.ImGui_InputDouble(ctx, 'Play Rate Random Min', PlayRateRandomMin, 0, 0, "%.3f")
    if change then
        PlayRateRandomMin = (PlayRateRandomMin == 0 and 0.001) or PlayRateRandomMin -- cant have a play rate of 0 
        if PlayRateRandomMin > PlayRateRandomMax then PlayRateRandomMax = PlayRateRandomMin end
        ApplyOptions()
    end
    change, PlayRateRandomMax = reaper.ImGui_InputDouble(ctx, 'Play Rate Random Max', PlayRateRandomMax, 0, 0, "%.3f")
    if change then
        PlayRateRandomMax = (PlayRateRandomMax == 0 and 0.001) or PlayRateRandomMax-- cant have a play rate of 0 
        if PlayRateRandomMin > PlayRateRandomMax then PlayRateRandomMin = PlayRateRandomMax end
        ApplyOptions()
    end
    change, PlayRateQuantize = reaper.ImGui_InputDouble(ctx, 'Play Rate Quantize', PlayRateQuantize, 0, 0, "%.3f")
    if change then
        ApplyOptions()
    end

    reaper.ImGui_Separator(ctx) ------------------------
    reaper.ImGui_PopItemWidth(ctx)
    if reaper.ImGui_Button(ctx, 'Copy Settings', -FLT_MIN) then
        CopyOptions()
    end
    if reaper.ImGui_Button(ctx, 'Paste Settings', -FLT_MIN) then
        PasteOptions()
    end
end

function GetOptions()
    local first_item = reaper.GetSelectedMediaItem(proj, 0)
    local take = reaper.GetActiveTake(first_item)

    if OldTake ~= take then -- only when chaning the selected take, so it dont constantly change value
        local retval, min_time = GetTakeExtState(take, Ext_Name, Ext_MinTime) -- check with just one if present then get all
        if min_time ~= '' then
            RandomizeTakes = (select(2, GetItemExtState(first_item, Ext_Name, Ext_RandomizeTake))) == 'true'
            TakeChance = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_TakeChance)))
            TimeRandomMin = tonumber(min_time)
            TimeRandomMax = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_MaxTime)))
            TimeQuantize = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_QuantizeTime)))
            PitchRandomMin = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_MinPitch)))
            PitchRandomMax = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_MaxPitch)))
            PitchQuantize = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_QuantizePitch)))
            PlayRateRandomMin = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_MinRate)))-- cannot be 0!
            PlayRateRandomMax = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_MaxRate))) -- cannot be 0!
            PlayRateQuantize = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_QuantizeRate)))
        else -- current item dont have ext states values load default
            SetDefaults()
        end
    end

    OldTake = take
end

function GetTakeOptions()
    
end

function ApplyOptions()
    for selected_item in enumSelectedItems(proj) do
        local take = reaper.GetActiveTake(selected_item)
        SetItemExtState(selected_item, Ext_Name, Ext_RandomizeTake, tostring(RandomizeTakes))
        SetTakeExtState(take, Ext_Name, Ext_TakeChance, TakeChance)
        SetTakeExtState(take, Ext_Name, Ext_MinTime, TimeRandomMin)
        SetTakeExtState(take, Ext_Name, Ext_MaxTime, TimeRandomMax)
        SetTakeExtState(take, Ext_Name, Ext_QuantizeTime, TimeQuantize)
        SetTakeExtState(take, Ext_Name, Ext_MinPitch, PitchRandomMin)
        SetTakeExtState(take, Ext_Name, Ext_MaxPitch, PitchRandomMax)
        SetTakeExtState(take, Ext_Name, Ext_QuantizePitch, PitchQuantize)
        SetTakeExtState(take, Ext_Name, Ext_MinRate, PlayRateRandomMin) -- cannot be 0!
        SetTakeExtState(take, Ext_Name, Ext_MaxRate, PlayRateRandomMax) -- cannot be 0!
        SetTakeExtState(take, Ext_Name, Ext_QuantizeRate, PlayRateQuantize)
    end    
end

function CopyOptions()
    CopyRandomizeTakes = RandomizeTakes
    CopyTakeChance = TakeChance
    CopyTimeRandomMin = TimeRandomMin
    CopyTimeRandomMax = TimeRandomMax
    CopyTimeQuantize = TimeQuantize
    CopyPitchRandomMin = PitchRandomMin
    CopyPitchRandomMax = PitchRandomMax
    CopyPitchQuantize = PitchQuantize
    CopyPlayRateRandomMin = PlayRateRandomMin -- cannot be 0!
    CopyPlayRateRandomMax = PlayRateRandomMax -- cannot be 0!
    CopyPlayRateQuantize = PlayRateQuantize
end

function PasteOptions()
    if CopyTimeRandomMin then
        RandomizeTakes = CopyRandomizeTakes
        TakeChance = CopyTakeChance
        TimeRandomMin = CopyTimeRandomMin
        TimeRandomMax = CopyTimeRandomMax
        TimeQuantize = CopyTimeQuantize
        PitchRandomMin = CopyPitchRandomMin
        PitchRandomMax = CopyPitchRandomMax
        PitchQuantize = CopyPitchQuantize
        PlayRateRandomMin = CopyPlayRateRandomMin -- cannot be 0!
        PlayRateRandomMax = CopyPlayRateRandomMax -- cannot be 0!
        PlayRateQuantize = CopyPlayRateQuantize
        ApplyOptions()
    else
        print('Copy Something First!')
    end
end