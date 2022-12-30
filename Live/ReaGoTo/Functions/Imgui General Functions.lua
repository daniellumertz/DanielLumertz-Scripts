--@noindex
--v 0.1
-- Add colors
----------------
---- Colors
----------------


---Input a RRGGBB color, from ImGui_ColorEdit3 and output a number color to be used for reaper objects, like markers.
---@param rgb_input number number from ImGui_ColorEdit3, in the format 0xRRGGBB
---@return number new_color value to be used in functions like AddProjectMarker2
function RGBA_To_ReaperRGB(rgb_input)
    return reaper.ImGui_ColorConvertNative(rgb_input) | 0x1000000
end

---Input a HSVA color, output is a number to insert in ImGUI widgets (from imgui demo)
---@param h number hue from 0 - 1
---@param s number saturation 0 - 1
---@param v number value 0 - 1
---@param a number alpha 0 - 1
---@return number color color for imgui RRGGBBAA
function HSVtoImGUI(h, s, v, a)
    local r, g, b = reaper.ImGui_ColorConvertHSVtoRGB(h, s, v)
    return reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a or 1.0)
end
----------------
---- Popups
----------------

function ToolTip(is_tooltip, text, wrap)
    if is_tooltip and reaper.ImGui_IsItemHovered(ctx) then
        ToolTipSimple(text, wrap)
    end
end

function ToolTipSimple(text, wrap)
    wrap = wrap or 200    
    reaper.ImGui_BeginTooltip(ctx)
    --reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 20)
    reaper.ImGui_PushTextWrapPos(ctx, wrap)
    reaper.ImGui_Text(ctx, text)
    reaper.ImGui_PopTextWrapPos(ctx)
    reaper.ImGui_EndTooltip(ctx)    
end

----------------
---- Keys
----------------


-- PassKeys to the last focused window. Only working in windows currently
function PassKeys() 
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

-- PassKeys to main or midieditor(if is_midieditor and there is any midi editor active). 
---@param is_midieditor boolean if true then it will always pass the key presses to the midi editor. If there isnt a midi editor it will pass to the main window. If false pass to the main window
function PassKeys2(is_midieditor) 
    --Get keys pressed
    local active_keys = {}
    for key_val = 0,255 do
        if reaper.ImGui_IsKeyPressed(ctx, key_val, true) then -- true so holding will perform many times
            active_keys[#active_keys+1] = key_val
        end
    end
    -- Get Window
    local sel_window 
    if is_midieditor then
        local midi = reaper.MIDIEditor_GetActive()
        if midi then 
            sel_window = midi 
        end
    end

    if not sel_window then
        sel_window = reaper.GetMainHwnd()
    end

    --Send Message
    if sel_window then 
        if #active_keys > 0  then
            for k, key_val in pairs(active_keys) do
                PostKey(sel_window, key_val)
            end
        end
    end
end

function PostKey(hwnd, vk_code)
    reaper.JS_WindowMessage_Post(hwnd, "WM_KEYDOWN", vk_code, 0,0,0)
    reaper.JS_WindowMessage_Post(hwnd, "WM_KEYUP", vk_code, 0,0,0)
end

----------------
---- Text
----------------

---Print on imgui screen
function ImPrint(...)
    local t = {}
    for i, v in ipairs( { ... } ) do
        t[i] = tostring( v )
    end
    reaper.ImGui_Text(ctx, table.concat( t, " " ))
end

----------------
---- Draw
----------------


function DrawRectLastItem(h,s,v,a)
    local minx, miny = reaper.ImGui_GetItemRectMin(ctx)
    local maxx, maxy = reaper.ImGui_GetItemRectMax(ctx)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)

    local color =  HSVtoImGUI(h, s, v, a)
    
    reaper.ImGui_DrawList_AddRectFilled(draw_list, minx-50, miny, maxx, maxy, color)
end

