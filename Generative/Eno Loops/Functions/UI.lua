--@noindex
function GuiInit(ScriptName)
    ctx = reaper.ImGui_CreateContext(ScriptName) -- Add VERSION TODO
    -- Define Globals GUI
    Gui_W,Gui_H= 250,412
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
            local bol = IsLoopItemSelected()
            if not bol then
                SelectedItemsGUI()
            else
                LoopItemGUI()
            end
        else
            reaper.ImGui_Text(ctx, '--- Select Some Item ---')
        end
        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_Button(ctx, 'Apply Generative Loops', -FLT_MIN) then
            local command = reaper.NamedCommandLookup('_RSd814491aaee8f3200e2fce379d5b51faa9e07a02')
            reaper.Main_OnCommand(command, 0)
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
    local item = reaper.GetSelectedMediaItem(proj, 0)
    local take = reaper.GetActiveTake(item)
    if OldTake ~= take then -- only when chaning the selected take, so it dont constantly change value
        rnd_values = GetOptions(rnd_values, item, take)
    end
    OldTake = take

    local change
    local w_av,  h_av = reaper.ImGui_GetContentRegionAvail(ctx)
    reaper.ImGui_PushItemWidth(ctx, w_av-150)


    change, rnd_values.RandomizeTakes = reaper.ImGui_Checkbox(ctx, 'Randomize Takes', rnd_values.RandomizeTakes)
    if change then
        ApplyOptions()
    end
    --reaper.ImGui_SameLine(ctx)
    change, rnd_values.TakeChance = reaper.ImGui_InputDouble(ctx, 'Take Chance', rnd_values.TakeChance, 0, 0, "%.1f")
    if change then
        ApplyOptions()
    end

    reaper.ImGui_Separator(ctx) ------------------------
    change, rnd_values.TimeRandomMin = reaper.ImGui_InputDouble(ctx, 'Time Random Min', rnd_values.TimeRandomMin, 0, 0, "%.3f")
    if change then
        if rnd_values.TimeRandomMin > rnd_values.TimeRandomMax then rnd_values.TimeRandomMax = rnd_values.TimeRandomMin end
        ApplyOptions()
    end
    change, rnd_values.TimeRandomMax = reaper.ImGui_InputDouble(ctx, 'Time Random Max', rnd_values.TimeRandomMax, 0, 0, "%.3f")
    if change then
        if rnd_values.TimeRandomMin > rnd_values.TimeRandomMax then rnd_values.TimeRandomMin = rnd_values.TimeRandomMax end
        ApplyOptions()
    end
    change, rnd_values.TimeQuantize = reaper.ImGui_InputDouble(ctx, 'Time Quantize (sec)', rnd_values.TimeQuantize, 0, 0, "%.3f")
    if change then
        ApplyOptions()
    end
        
    reaper.ImGui_Separator(ctx) ------------------------
    change, rnd_values.PitchRandomMin = reaper.ImGui_InputDouble(ctx, 'Pitch Random Min', rnd_values.PitchRandomMin, 0, 0, "%.3f")
    if change then
        if rnd_values.PitchRandomMin > rnd_values.PitchRandomMax then rnd_values.PitchRandomMax = rnd_values.PitchRandomMin end
        ApplyOptions()
    end
    change, rnd_values.PitchRandomMax = reaper.ImGui_InputDouble(ctx, 'Pitch Random Max', rnd_values.PitchRandomMax, 0, 0, "%.3f")
    if change then
        if rnd_values.PitchRandomMin > rnd_values.PitchRandomMax then rnd_values.PitchRandomMin = rnd_values.PitchRandomMax end
        ApplyOptions()
    end
    change, rnd_values.PitchQuantize = reaper.ImGui_InputDouble(ctx, 'Pitch Quantize', rnd_values.PitchQuantize, 0, 0, "%.3f")
    if change then
        ApplyOptions()
    end

    reaper.ImGui_Separator(ctx) ------------------------
    change, rnd_values.PlayRateRandomMin = reaper.ImGui_InputDouble(ctx, 'Play Rate Random Min', rnd_values.PlayRateRandomMin, 0, 0, "%.3f")
    if change then
        rnd_values.PlayRateRandomMin = (rnd_values.PlayRateRandomMin <= 0 and 0.001) or rnd_values.PlayRateRandomMin -- cant have a play rate of 0 
        if rnd_values.PlayRateRandomMin > rnd_values.PlayRateRandomMax then rnd_values.PlayRateRandomMax = rnd_values.PlayRateRandomMin end
        ApplyOptions()
    end
    change, rnd_values.PlayRateRandomMax = reaper.ImGui_InputDouble(ctx, 'Play Rate Random Max', rnd_values.PlayRateRandomMax, 0, 0, "%.3f")
    if change then
        rnd_values.PlayRateRandomMax = (rnd_values.PlayRateRandomMax <= 0 and 0.001) or rnd_values.PlayRateRandomMax-- cant have a play rate of 0 
        if rnd_values.PlayRateRandomMin > rnd_values.PlayRateRandomMax then rnd_values.PlayRateRandomMin = rnd_values.PlayRateRandomMax end
        ApplyOptions()
    end
    change, rnd_values.PlayRateQuantize = reaper.ImGui_InputDouble(ctx, 'Play Rate Quantize', rnd_values.PlayRateQuantize, 0, 0, "%.3f")
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
    if reaper.ImGui_Button(ctx, 'Reset Settings', -FLT_MIN) then
        ResetToDefault()
    end
end

function LoopItemGUI()
    local item = reaper.GetSelectedMediaItem(proj, 0)
    local take = reaper.GetActiveTake(item)
    if OldTake ~= take then -- only when chaning the selected take, so it dont constantly change value
        LoopOption = GetLoopOptions(item,take)
    end

    local change
    local w_av,  h_av = reaper.ImGui_GetContentRegionAvail(ctx)
    reaper.ImGui_PushItemWidth(ctx, w_av-150)
    change, LoopOption.RandomizeTakes = reaper.ImGui_Checkbox(ctx, 'Randomize Takes', LoopOption.RandomizeTakes)
    if change then
        ApplyLoopOptions()
    end

    change, LoopOption.TakeChance = reaper.ImGui_InputDouble(ctx, 'Take Chance', LoopOption.TakeChance, 0, 0, "%.1f")
    if change then
        ApplyLoopOptions()
    end
    ----------------------------------------------------- PlayRate
    reaper.ImGui_Separator(ctx) ------------------------
    change, LoopOption.PlayRateRandomMin = reaper.ImGui_InputDouble(ctx, 'Playrate Random Min', LoopOption.PlayRateRandomMin, 0, 0, "%.3f")
    if change then
        LoopOption.PlayRateRandomMin = (LoopOption.PlayRateRandomMin <= 0 and 0.001) or LoopOption.PlayRateRandomMin -- cant have a play rate of 0 
        if LoopOption.PlayRateRandomMin > LoopOption.PlayRateRandomMax then LoopOption.PlayRateRandomMax = LoopOption.PlayRateRandomMin end
        ApplyLoopOptions()
    end
    change, LoopOption.PlayRateRandomMax = reaper.ImGui_InputDouble(ctx, 'Playrate Random Max', LoopOption.PlayRateRandomMax, 0, 0, "%.3f")
    if change then
        LoopOption.PlayRateRandomMax = (LoopOption.PlayRateRandomMax <= 0 and 0.001) or LoopOption.PlayRateRandomMax-- cant have a play rate of 0 
        if LoopOption.PlayRateRandomMin > LoopOption.PlayRateRandomMax then LoopOption.PlayRateRandomMin = LoopOption.PlayRateRandomMax end
        ApplyLoopOptions()
    end
    change, LoopOption.PlayRateQuantize = reaper.ImGui_InputDouble(ctx, 'Playrate Quantize', LoopOption.PlayRateQuantize, 0, 0, "%.3f")
    if change then
        ApplyLoopOptions()
    end
    ----------------------------------------------------- Pitch
    reaper.ImGui_Separator(ctx) ------------------------
    change, LoopOption.PitchRandomMin = reaper.ImGui_InputDouble(ctx, 'Pitch Random Min', LoopOption.PitchRandomMin, 0, 0, "%.3f")
    if change then
        if LoopOption.PitchRandomMin > LoopOption.PitchRandomMax then LoopOption.PitchRandomMax = LoopOption.PitchRandomMin end
        ApplyLoopOptions()
    end
    change, LoopOption.PitchRandomMax = reaper.ImGui_InputDouble(ctx, 'Pitch Random Max', LoopOption.PitchRandomMax, 0, 0, "%.3f")
    if change then
        if LoopOption.PitchRandomMin > LoopOption.PitchRandomMax then LoopOption.PitchRandomMin = LoopOption.PitchRandomMax end
        ApplyLoopOptions()
    end
    change, LoopOption.PitchQuantize = reaper.ImGui_InputDouble(ctx, 'Pitch Quantize', LoopOption.PitchQuantize, 0, 0, "%.3f")
    if change then
        ApplyLoopOptions()
    end
    ----------------------------------------------------- Length
    reaper.ImGui_Separator(ctx) ------------------------
    change, LoopOption.LengthRandomMin = reaper.ImGui_InputDouble(ctx, 'Length Random Min', LoopOption.LengthRandomMin, 0, 0, "%.3f")
    if change then
        LoopOption.LengthRandomMin = (LoopOption.LengthRandomMin <= 0 and 0.001) or LoopOption.LengthRandomMin -- cant have a length of 0 
        if LoopOption.LengthRandomMin > LoopOption.LengthRandomMax then LoopOption.LengthRandomMax = LoopOption.LengthRandomMin end
        ApplyLoopOptions()
    end
    change, LoopOption.LengthRandomMax = reaper.ImGui_InputDouble(ctx, 'Length Random Max', LoopOption.LengthRandomMax, 0, 0, "%.3f")
    if change then
        LoopOption.LengthRandomMax = (LoopOption.LengthRandomMax <= 0 and 0.001) or LoopOption.LengthRandomMax-- cant have a length of 0 
        if LoopOption.LengthRandomMin > LoopOption.LengthRandomMax then LoopOption.LengthRandomMin = LoopOption.LengthRandomMax end
        ApplyLoopOptions()
    end
    change, LoopOption.LengthQuantize = reaper.ImGui_InputDouble(ctx, 'Length Quantize', LoopOption.LengthQuantize, 0, 0, "%.3f")
    if change then
        ApplyLoopOptions()
    end

    reaper.ImGui_Separator(ctx) ------------------------
    reaper.ImGui_PopItemWidth(ctx)
    if reaper.ImGui_Button(ctx, 'Copy Settings', -FLT_MIN) then
        CopyLoopOptions()
    end
    if reaper.ImGui_Button(ctx, 'Paste Settings', -FLT_MIN) then
        PasteLoopOptions()
    end
    if reaper.ImGui_Button(ctx, 'Reset Settings', -FLT_MIN) then
        ResetToLoopDefault()
    end
    OldTake = take    
end



function ResetToDefault()
    rnd_values = SetDefaults()
    ApplyOptions()    
end

function CopyOptions()
    CopyRndValues = TableCopy(rnd_values)
end

function PasteOptions()
    if CopyRndValues then
        rnd_values = TableCopy(CopyRndValues)
        ApplyOptions()
    else
        print('Copy Something First!')
    end
end

function CopyLoopOptions()
    CopyLoopValues = TableCopy(LoopOption)
end

function PasteLoopOptions()
    if CopyLoopValues then
        LoopOption = TableCopy(CopyLoopValues)
        ApplyLoopOptions()
    else
        print('Copy Something First!')
    end
end

function ResetToLoopDefault()
    LoopOption = SetDefaultsLoopItem()
    ApplyLoopOptions()
end
