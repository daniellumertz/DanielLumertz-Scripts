--@noindex
--@noindex

--v 0.0.0

----------------
---- Colors
----------------


---Input a RRGGBB color, from ImGui_ColorEdit3 and output a number color to be used for reaper objects, like markers.
---@param rgb_input number number from ImGui_ColorEdit3, in the format 0xRRGGBB
---@return number new_color value to be used in functions like AddProjectMarker2
function RGBA_To_ReaperRGB(rgb_input)
    return reaper.ImGui_ColorConvertNative(rgb_input) | 0x1000000
end

----------------
---- Popups
----------------

function ToolTip(is_tooltip, text)
    if is_tooltip and reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_BeginTooltip(ctx)
        --reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 20)
        reaper.ImGui_PushTextWrapPos(ctx, 200)
        reaper.ImGui_Text(ctx, text)
        reaper.ImGui_PopTextWrapPos(ctx)
        reaper.ImGui_EndTooltip(ctx)
    end
end


----------------
---- Keys
----------------


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
