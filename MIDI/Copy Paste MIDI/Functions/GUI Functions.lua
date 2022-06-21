-- @noindex
-- GUI
function GuiInit()
    ctx = reaper.ImGui_CreateContext('Copy Paste MIDI') -- Add VERSION TODO
    -- Define Globals GUI
    W,H= 200,375
    local difference_gap = 98
    local n_buttons = 7
    Btn_size = (H/n_buttons) - (difference_gap/n_buttons)
end

function MenuBar()
    if reaper.ImGui_BeginMenuBar(ctx) then
        if reaper.ImGui_BeginMenu(ctx, 'Gap') then
            local _
            _, IsGap = reaper.ImGui_MenuItem(ctx, 'Gap', optional_shortcutIn, IsGap, optional_enabledIn)
            reaper.ImGui_SetNextItemWidth(ctx, 70)
            _, Gap = reaper.ImGui_InputInt(ctx, 'Gap Size', Gap,0)
            Gap= LimitNumber(Gap,0)
            reaper.ImGui_EndMenu(ctx)
        end
        reaper.ImGui_EndMenuBar(ctx)
    end
end

function loop()
    reaper.ImGui_SetNextWindowSize(ctx, W, H, reaper.ImGui_Cond_Once())-- Set the size of the windows.  Use in the 4th argument reaper.ImGui_Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2
    local window_flags = reaper.ImGui_WindowFlags_NoResize() | reaper.ImGui_WindowFlags_MenuBar()
    local visible, open  = reaper.ImGui_Begin(ctx, ScriptName..' '..Version, true, window_flags)

    local _ -- values I will throw away
    if visible then
        MenuBar()


        ------------------Copy
        if reaper.ImGui_Button(ctx,'Copy', -1,Btn_size) then
            CopyList = CopyMIDIParameters(take)
        end
        ------------------Paste
        reaper.ImGui_Separator(ctx)
        ------
        local text_w, _ = reaper.ImGui_CalcTextSize(ctx, 'Paste')
        reaper.ImGui_SetCursorPosX(ctx, (W/2) - (text_w/2)) 
        reaper.ImGui_Text(ctx, 'Paste')
    
        ----- Paste Buttons
        ----- Rhythm
        if reaper.ImGui_Button(ctx,'Rhythm', -1,Btn_size) then
            PasteRhythmTakes()
        end
        RhythmInter = SliderInter(RhythmInter)

        if reaper.ImGui_Button(ctx,'Measure Position', -1,Btn_size) then
            PasteGrooveTakes()
        end
        RhythmInter = SliderInter(RhythmInter)

        --- Lenght
        if reaper.ImGui_Button(ctx,'Lenght', -1,Btn_size) then
            PasteLenTakes()
        end
        LenghtInter = SliderInter(LenghtInter)

        --- Velocity
        if reaper.ImGui_Button(ctx,'Velocity', -1,Btn_size) then
            PasteVelTakes()
        end
        VelocityInter = SliderInter(VelocityInter)

        --- Pitch
        if reaper.ImGui_Button(ctx,'Pitch', -1,Btn_size) then
            PastePitchTakes()
        end
        PitchInter, PitchFill = SliderInterNotes(PitchInter, PitchFill)

        --- Interval
        if reaper.ImGui_Button(ctx,'Interval', -1,Btn_size) then
            PasteIntervalsTakes()
        end
        IntervalInter, InterFill = SliderInterNotes(IntervalInter, InterFill)

    
        reaper.ImGui_End(ctx)
    end 



    if open then
        reaper.defer(loop)
    else
        reaper.ImGui_DestroyContext(ctx)
    end
end

function SliderInter(InterValue)
    local _

    if reaper.ImGui_BeginPopupContextItem(ctx) then 
        reaper.ImGui_Text(ctx, 'Original')
        reaper.ImGui_SameLine(ctx, 185) -- Pad next text
        reaper.ImGui_Text(ctx, 'Copy')
        _, InterValue = reaper.ImGui_SliderDouble(ctx, '###InterSlider', InterValue, 0, 1, tostring(math.floor(InterValue*100))..'%%')
        reaper.ImGui_EndPopup(ctx)
    end
    return InterValue
end

function SliderInterNotes(InterValue, CheckValue)
    local _
    if reaper.ImGui_BeginPopupContextItem(ctx) then 
        reaper.ImGui_Text(ctx, 'Original')
        reaper.ImGui_SameLine(ctx, 185) -- Pad next text
        reaper.ImGui_Text(ctx, 'Copy')
        _, InterValue = reaper.ImGui_SliderDouble(ctx, '###InterSlider', InterValue, 0, 1, tostring(math.floor(InterValue*100))..'%%')
        _, CheckValue = reaper.ImGui_Checkbox(ctx, 'Fill all chord notes', CheckValue)
        reaper.ImGui_EndPopup(ctx)
    end
    return InterValue, CheckValue
end