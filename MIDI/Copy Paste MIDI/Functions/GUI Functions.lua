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

function loop()
    PassKeys()
    PushStyle()
    reaper.ImGui_SetNextWindowSize(ctx, W, H, reaper.ImGui_Cond_Once())-- Set the size of the windows.  Use in the 4th argument reaper.ImGui_Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2
    local window_flags = reaper.ImGui_WindowFlags_NoResize() | reaper.ImGui_WindowFlags_MenuBar()
    local visible, open  = reaper.ImGui_Begin(ctx, ScriptName..' '..Version, true, window_flags)

    local _ -- values I will throw away
    if visible then
        MenuBar()


        ButtonStylePush(1)
        ------------------Copy
        if reaper.ImGui_Button(ctx,'Copy', -1,Btn_size) then
            CopyList = CopyMIDIParameters(take)
            Stevie('C')
        end
        ButtonStylePop()
        ------------------Paste
        reaper.ImGui_Separator(ctx)
        ------
        local text_w, _ = reaper.ImGui_CalcTextSize(ctx, 'Paste')
        reaper.ImGui_SetCursorPosX(ctx, (W/2) - (text_w/2)) 
        reaper.ImGui_Text(ctx, 'Paste')
    
        ----- Paste Buttons
        ----- Rhythm
        ButtonStylePush(RhythmInter)
        if reaper.ImGui_Button(ctx,'Rhythm', -1,Btn_size) then
            PasteRhythmTakes()
            Stevie('R')
        end
        RhythmInter = SliderInter(RhythmInter)
        ButtonStylePop()

        ButtonStylePush(MeasureInter)
        if reaper.ImGui_Button(ctx,'Measure Position', -1,Btn_size) then
            PasteGrooveTakes()
            Stevie('M')
        end
        MeasureInter = SliderInter(MeasureInter)
        ButtonStylePop()

        --- Lenght
        ButtonStylePush(LenghtInter)
        if reaper.ImGui_Button(ctx,'Length', -1,Btn_size) then
            PasteLenTakes()
            Stevie('L')
        end
        LenghtInter = SliderInter(LenghtInter)
        ButtonStylePop()

        --- Velocity
        ButtonStylePush(VelocityInter)
        if reaper.ImGui_Button(ctx,'Velocity', -1,Btn_size) then
            PasteVelTakes()
            Stevie('V')
        end
        VelocityInter = SliderInter(VelocityInter)
        ButtonStylePop()

        --- Pitch
        ButtonStylePush(PitchInter)
        if reaper.ImGui_Button(ctx,'Pitch', -1,Btn_size) then
            PastePitchTakes()
            Stevie('P')
        end
        PitchInter, PitchFill = SliderInterNotes(PitchInter, PitchFill)
        ButtonStylePop()

        --- Interval
        ButtonStylePush(IntervalInter)
        if reaper.ImGui_Button(ctx,'Interval', -1,Btn_size) then
            PasteIntervalsTakes()
        end
        IntervalInter, InterFill = SliderInterNotes(IntervalInter, InterFill)
        ButtonStylePop()

    
        reaper.ImGui_End(ctx)
    end 
    PopStyle()

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
-------------

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

------
-- Sir Stevie
------

function Stevie(string)
    table.insert(StevieTable,1,string)
    if #StevieTable > 6 then
        table.remove(StevieTable)
    end
    if string == 'C' then
        CheckStevie()
    end

end

function CheckStevie()
    if #StevieTable == 6 then
        if table.concat(StevieTable) == 'CMVPLR' then
            PrintStevie()
        end
    end
end

function PrintStevie()
    reaper.ClearConsole()
    local stevie =
    [[
    &&&&&&&&&%%%##((//*****,,,,,............   ...,,,,,,,,,,,,,,,,,..........     ..
    &&&&&%%%#((///****,,,,........              .....,,,,,,,,,,......    ......   ..
    &&&%##(//**,,,,,,,,,.......                  .........,,,,.......       ........
    &&%#(/*,,,,,,,,,..........                    ...................        ...,...
    &&%#/**,,,,,,,.............                        ..............         .,,,..
    &&%#/**,,,,,,,,............                           .......             .,,,,,
    &&%#(**,,,,,,,,............                                                .,,,,
    &&%#(/***,,,,,,............                                                ..,,,
    &&&%#(/**,,,,,,,........                                                   ...,,
    &&&&%(/**,,,,,,,.........                                ......,,,********,,,.,,
    @&&%#/**,,,,,,,,,,,,,,,,,,................................,,*//(#%%##(//*,,...,*
    @&%#/**,,,,**///((((///////((((((((((((//**,,,,.......,,**/(#####((/****,,.  .,*
    &&#/**,,,,**/((((((//////***////(((((##(((//**,,,...,,**//((##%%%%#/*///**,.  .,
    &%(/*,,,,***//********//((########(((///////**,,......,**//*//((((/,,...      .,
    &%(/*,,,,,**,,,,,**//((###%%%%#(***////**,,**,,,..   ..,,,,,,,,,,,,,...       .,
    %#(/*,,,,,,,,,,,,,*******,,,,,,,,,,***,,,.,,,,,,...    ..,,,....,,,,....       .
    %%(/*,,,,,,,,......,,,,,,,,,,,,,,,,,,,,...,,,,,,...      ..............         
    %%#/**,,,,,,..........,,,,,,,,,,,,..................       .......              
    (##(/**,,,,,..........................................      .........   ..      
    */((/***,,,,...................................,,.....      ..,,,..........     
    ,*////***,,,,,.............     .....,,,,,,,,,,,,....        ..,***,,,,.....    
    ,,*////**,,,,,,,,,................,,*****,,..,,,,....          .,*****,,,,...   
    ***/((/***,,,,,,,,,,,,,,,,....,,,*********,,,,,,,,,,.........,,,*****//***,,....
    **//((/****,,,,,,,,,,,,,,,,,,***///******///(((((((///***///////****///(//*,....
    ***/(#(/*****,,,,,,**********//((//***///(((##########(((((/////****//(((/*,.  .
    ***/(((//*****************//(((((////////((((((((((((/(((((//*****/////(/*,.....
    ***///((//***************//(####(((((///////////////*****//****////*///**,...*#&
    ****///(///****,,,,*****//(###((((###((/********,,,,,,......,,*//***/((*,.*#&@@@
    ***////(((//****,,,*****///(##(/****////*,,......        .,****,,,**/##((%&@@@@@
    ****////(((//*****,,**//////(##(/*,,*****/*******,,,*********,..,,**(##&&@@@@@@@
    *****////((((///***,**/((((#####(/*,,,,,*********************,,.,,*(#%&@@@@@@@@@
    ******////((##((//////(##%%%%&&&%#(/*,,,,,,**************,,,,,,,,*/(#&@@@@@@@@@@
    *******////((#%%%%%%%%%%%%%%%&&&&%%#((/***,,,******/////*********/(#%@@@@@@@@@@@
    *********////(#%%&&&&&&&%&&&&&@@@&&&%%##(/**,****/////////*****///(%&@@@@@@@@@@@
    *********/////(((#%&&&&&&&&&&&@@@@&&&&%%%#(//******************//((%&@@@@@@@@@@@
    *********///((#(//((#%&&&&&&&&&@@@&&&&&&%%#((////********//////((((%&@@@@@@@@&#%
    *********//(##/***///((#%%&&@@@@@@@@@&&&%%%####(((//(((/((((((((((#%&@@@@@@@@&(*
    ****///(##%%#/*******///((#%%&&&@@@@@&&&&&&&&%%%%##########%###(#%%#%@@@@@@@@@&(
    **/(#%&&@@@&#/,,********//(((##%%&&&&@@@@@&@@&&&&&%%%%%%%%%%%%%%%%#((%@@@@@@@@@&
    #%&&@@@@@@@&%(*,,,,,,******///(((###%&&&@@@@@@@@@&&&&&&&&&&&&&&%#/***(&&@@@@@@@@
    &@@@@@@@@@@@&%/,,,,,,,,,,,,***////((((##%%%&&&&&&&@&&&&&&&&%##(/**,,*(%&@@@@@@@@
    @@@@@@@@@@@@@&%(*,,,,,,,,,,,,******////(((###%%%%%%%%####(((//***,,,*(%&@@@@@@@@]]
    reaper.ShowConsoleMsg(stevie)
  end

