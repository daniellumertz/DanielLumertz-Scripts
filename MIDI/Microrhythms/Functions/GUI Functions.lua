-- @noindex
-- GUI
function GuiInit()
    ctx = reaper.ImGui_CreateContext('Copy Paste MIDI') -- Add VERSION TODO
    -- Define Globals GUI
    W,H= 200,250
end

--- Parts

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

        if reaper.ImGui_BeginMenu(ctx, 'About') then
            local _
            if reaper.ImGui_MenuItem(ctx, 'Theory') then
                open_url('http://general-theory-of-rhythm.org/basic-principles/')
            end
            if reaper.ImGui_MenuItem(ctx, 'Donate') then
                open_url('https://www.paypal.com/donate/?hosted_button_id=RWA58GZTYMZ3N')
            end
            reaper.ImGui_EndMenu(ctx)

        end
        local _
        _, Pin = reaper.ImGui_MenuItem(ctx, 'Pin', optional_shortcutIn, Pin)


        reaper.ImGui_EndMenuBar(ctx)
    end
end


---- Theming

function HSV(h, s, v, a)
    local r, g, b = reaper.ImGui_ColorConvertHSVtoRGB(h, s, v)
    return reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a or 1.0)
end


function PushStyle()
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(),         0x202020FF)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(),    0x548B85FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_MenuBarBg(),        0x202020FF) 

    
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(),          0x4C74758A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(),   0x6FB5B78A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(),    0x92F0DEAB)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(),           0x4C74758A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(),    0x6FB5B78A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(),     0x92F0DEAB)
       
    
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 5)    
end

function ButtonStylePush(val)
    -- make val between red(0) and green(x)
    local h = val *0.5
    local low_bg = HSV(h, 0.82, 0.35, 1) --125 211 149 255
    local med_bg = HSV(h, 0.82, 0.4, 1) --125 211 149 255
    local high_bg = HSV(h, 0.82, 0.45, 1) --125 211 149 255
    local low = HSV(h, 0.82, 0.58, 1) --125 211 149 255
    local med = HSV(h, 0.49, 0.77, 1) --125 197 201
    local high = HSV(h, 0.49, 0.90, 1) --125 93 288 

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(),          low_bg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(),   low_bg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(),    low)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(),        med)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(),       low)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(), high)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),           low)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(),    med)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),     high)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(),           low)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(),    med)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(),     high)
end

function ButtonStylePop()
    reaper.ImGui_PopStyleColor(ctx, 12)

end

function PopStyle()
    reaper.ImGui_PopStyleColor(ctx, 9)

    reaper.ImGui_PopStyleVar(ctx)
end


---------- Keys

----
function PassKeys() -- Might be a little tough on resource
    --Get keys pressed
    local active_keys = {}
    for key_val = 0,255 do
        if reaper.ImGui_IsKeyPressed(ctx, key_val, true) then -- true so holding will perform many times
            active_keys[#active_keys+1] = key_val
        end
    end

    --Send Message
    if LastWindowFocus then 
        if #active_keys > 0  then
            for k, key_val in pairs(active_keys) do
                PostKey(LastWindowFocus, key_val)
            end
        end
    end

    -- Get focus window (if not == Script Title)
    local win_focus = reaper.JS_Window_GetFocus()
    local win_name = reaper.JS_Window_GetTitle( win_focus )

    -- Need to retain the last window focused that isn't this script! 
    if LastWindowFocus ~= win_focus and (win_name == 'trackview' or win_name == 'midiview')  then -- focused win title is different? INSERT HERE
        LastWindowFocus = win_focus
    end    
end

function PostKey(hwnd, vk_code)
    reaper.JS_WindowMessage_Post(hwnd, "WM_KEYDOWN", vk_code, 0,0,0)
    reaper.JS_WindowMessage_Post(hwnd, "WM_KEYUP", vk_code, 0,0,0)
end


-------- Loop


function loop()

    if not TableHaveAnything(PreventPassKeys) then
        PassKeys()
    end

    PushStyle()
    ButtonStylePush(SliderInter)
    reaper.ImGui_SetNextWindowSize(ctx, W, H, reaper.ImGui_Cond_Once())-- Set the size of the windows.  Use in the 4th argument reaper.ImGui_Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2
    -- Change Ui Size if need
    if ChangeSize then 
        reaper.ImGui_SetNextWindowSize(ctx, W, H)
        ChangeSize = nil
    end
    local window_flags = reaper.ImGui_WindowFlags_NoResize() | reaper.ImGui_WindowFlags_MenuBar() 
    if Pin then 
        window_flags = window_flags | reaper.ImGui_WindowFlags_TopMost()
    end
    local visible, open  = reaper.ImGui_Begin(ctx, ScriptName..' '..Version, true, window_flags)

    local _ -- values I will throw away
    if visible then
        MenuBar()

        reaper.ImGui_Separator(ctx)

        --- Text
        reaper.ImGui_Text(ctx, 'Ratio')
        reaper.ImGui_SameLine(ctx, 145)
        reaper.ImGui_Text(ctx, 'Len(QN)')


        local _, change_user_input, chage_user_len
        -- Ratio Input
        reaper.ImGui_SetNextItemWidth(ctx, -55)
        change_user_input, UserInputRatio = reaper.ImGui_InputText(ctx, '###UserInput', UserInputRatio)
        if reaper.ImGui_IsItemFocused(ctx) then
            PreventPassKeys.UserInput = true
        else
            PreventPassKeys.UserInput = nil
        end
        
        -- Length Input
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_SetNextItemWidth(ctx, -1)
        chage_user_len, UserInputLength = reaper.ImGui_InputText(ctx, '###UserInputLength', UserInputLength, reaper.ImGui_InputTextFlags_CharsDecimal())
        if reaper.ImGui_IsItemFocused(ctx) then
            PreventPassKeys.UserInputLength = true
        else
            PreventPassKeys.UserInputLength = nil
        end
        
        -- If the user change something remake the rhythm table
        if change_user_input or chage_user_len then
            RhythmTable,SteadyValue = MakeRhythmTable(UserInputRatio,UserInputLength)
        end
        
        -- Slider
        --Slider text
        reaper.ImGui_Text(ctx, 'Equal')
        reaper.ImGui_SameLine(ctx) -- Pad next text
        local w_text, _ = reaper.ImGui_CalcTextSize(ctx, 'Ratio')
        reaper.ImGui_SetCursorPosX(ctx, W-w_text-10)
        reaper.ImGui_Text(ctx, 'Ratio')
        --Slider
        local change,change_auto
        reaper.ImGui_SetNextItemWidth(ctx, -1)
        change, SliderInter = reaper.ImGui_SliderDouble(ctx, '###InterSlider', SliderInter, 0, 1, tostring(math.floor(SliderInter*100))..'%%')

        -- Checkbox
        change_auto, IsAuto = reaper.ImGui_Checkbox(ctx, 'Do With Slider Change', IsAuto)
        -- Change Ui Size
        if change_auto then
            if IsAuto then 
                H = H - 90 
                ChangeSize = true
            else
                H = H + 90
                ChangeSize = true
            end
        end

        -- Do it
        if not IsAuto then
            if reaper.ImGui_Button(ctx, 'Do it!', -1,-1) then
                SetMicrorhythm(IsGap,Gap,RhythmTable,SteadyValue,SliderInter) 
            end
        elseif IsAuto and (change or chage_user_len or change_user_input) then
            SetMicrorhythm(IsGap,Gap,RhythmTable,SteadyValue,SliderInter) 
        end
        -- Save current selected notes when click AutoPaste button

    
        reaper.ImGui_End(ctx)
    end 
    ButtonStylePop()
    PopStyle()

    if open then
        reaper.defer(loop)
    else
        reaper.ImGui_DestroyContext(ctx)
    end
end
