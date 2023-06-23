--@noindex
function GuiInit(ScriptName)
    ctx = reaper.ImGui_CreateContext(ScriptName) -- Add VERSION TODO
    -- Define Globals GUI
    Gui_W,Gui_H= 250,385
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
    local item = reaper.GetSelectedMediaItem(proj, 0)
    local take = reaper.GetActiveTake(item)
    if OldTake ~= take then -- only when chaning the selected take, so it dont constantly change value
        rnd_values = GetOptions(rnd_values, item, take)
        print(rnd_values.TimeRandomMin)
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

    reaper.ImGui_Separator(ctx) ------------------------
    change, LoopOption.PlayRateRandomMin = reaper.ImGui_InputDouble(ctx, 'Play Rate Random Min', LoopOption.PlayRateRandomMin, 0, 0, "%.3f")
    if change then
        LoopOption.PlayRateRandomMin = (LoopOption.PlayRateRandomMin <= 0 and 0.001) or LoopOption.PlayRateRandomMin -- cant have a play rate of 0 
        if LoopOption.PlayRateRandomMin > LoopOption.PlayRateRandomMax then LoopOption.PlayRateRandomMax = LoopOption.PlayRateRandomMin end
        ApplyLoopOptions()
    end
    change, LoopOption.PlayRateRandomMax = reaper.ImGui_InputDouble(ctx, 'Play Rate Random Max', LoopOption.PlayRateRandomMax, 0, 0, "%.3f")
    if change then
        LoopOption.PlayRateRandomMax = (LoopOption.PlayRateRandomMax <= 0 and 0.001) or LoopOption.PlayRateRandomMax-- cant have a play rate of 0 
        if LoopOption.PlayRateRandomMin > LoopOption.PlayRateRandomMax then LoopOption.PlayRateRandomMin = LoopOption.PlayRateRandomMax end
        ApplyLoopOptions()
    end
    change, LoopOption.PlayRateQuantize = reaper.ImGui_InputDouble(ctx, 'Play Rate Quantize', LoopOption.PlayRateQuantize, 0, 0, "%.3f")
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

----- Loop Items
function ApplyLoopOptions()
    for selected_item in enumSelectedItems(proj) do
        local take = reaper.GetActiveTake(selected_item)
        SetItemExtState(selected_item, Ext_Name, Ext_Loop_RandomizeTake, tostring(LoopOption.RandomizeTakes))
        SetTakeExtState(take, Ext_Name, Ext_Loop_TakeChance, tostring(LoopOption.TakeChance))
        SetTakeExtState(take, Ext_Name, Ext_Loop_MinRate, tostring(LoopOption.PlayRateRandomMin)) -- cannot be 0!
        SetTakeExtState(take, Ext_Name, Ext_Loop_MaxRate, tostring(LoopOption.PlayRateRandomMax)) -- cannot be 0!
        SetTakeExtState(take, Ext_Name, Ext_Loop_QuantizeRate, tostring(LoopOption.PlayRateQuantize))
    end    
end


----- Items
function ApplyOptions()
    for selected_item in enumSelectedItems(proj) do
        local take = reaper.GetActiveTake(selected_item)
        SetItemExtState(selected_item, Ext_Name, Ext_RandomizeTake, tostring(rnd_values.RandomizeTakes))
        SetTakeExtState(take, Ext_Name, Ext_TakeChance, tostring(rnd_values.TakeChance))
        SetItemExtState(selected_item, Ext_Name, Ext_MinTime, tostring(rnd_values.TimeRandomMin))
        SetItemExtState(selected_item, Ext_Name, Ext_MaxTime, tostring(rnd_values.TimeRandomMax))
        SetItemExtState(selected_item, Ext_Name, Ext_QuantizeTime, tostring(rnd_values.TimeQuantize))
        SetTakeExtState(take, Ext_Name, Ext_MinPitch, tostring(rnd_values.PitchRandomMin))
        SetTakeExtState(take, Ext_Name, Ext_MaxPitch, tostring(rnd_values.PitchRandomMax))
        SetTakeExtState(take, Ext_Name, Ext_QuantizePitch, tostring(rnd_values.PitchQuantize))
        SetTakeExtState(take, Ext_Name, Ext_MinRate, tostring(rnd_values.PlayRateRandomMin)) -- cannot be 0!
        SetTakeExtState(take, Ext_Name, Ext_MaxRate, tostring(rnd_values.PlayRateRandomMax)) -- cannot be 0!
        SetTakeExtState(take, Ext_Name, Ext_QuantizeRate, tostring(rnd_values.PlayRateQuantize))
    end    
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
