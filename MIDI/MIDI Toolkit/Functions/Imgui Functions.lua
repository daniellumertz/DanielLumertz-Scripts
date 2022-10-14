--@noindex
-- Text
function TextCenter(text,Gui_W)
    local text_w, text_h = reaper.ImGui_CalcTextSize(ctx, text)
    reaper.ImGui_SetCursorPosX(ctx, Gui_W/2 - text_w/2)
    reaper.ImGui_Text(ctx, text)
end
-- Draw
function WriteAtLastObjectasShortkey(text, r,g,b,a)
    local minx, miny = reaper.ImGui_GetItemRectMin(ctx)
    local maxx, maxy = reaper.ImGui_GetItemRectMax(ctx)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    local color =  rgba2num(r,  g,  b,  a)
    local text_w, text_h = reaper.ImGui_CalcTextSize(ctx, text, 1, 1)
    local pad = 5
    reaper.ImGui_DrawList_AddText(draw_list, maxx-text_w-pad, miny, color, text)    
end

-- Misc/objects

function DrawRectLastItem(r,g,b,a)
    local minx, miny = reaper.ImGui_GetItemRectMin(ctx)
    local maxx, maxy = reaper.ImGui_GetItemRectMax(ctx)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    --local color =  reaper.ImGui_ColorConvertRGBtoHSV( r,  g,  b,  a )
    local color =  rgba2num(r,  g,  b,  a)
    
    reaper.ImGui_DrawList_AddRectFilled(draw_list, minx-50, miny, maxx, maxy, color)
end

function ToolTip(is_tooltip, text)
    if is_tooltip and reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_PushFont(ctx, FontText)
        reaper.ImGui_BeginTooltip(ctx)
        --reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 20)
        reaper.ImGui_PushTextWrapPos(ctx, 200)
        reaper.ImGui_Text(ctx, text)
        reaper.ImGui_PopTextWrapPos(ctx)
        reaper.ImGui_EndTooltip(ctx)
        reaper.ImGui_PopFont(ctx)
    end
end

--- Get Items Info 
function GetLastItemWidth()
    local minx, miny = reaper.ImGui_GetItemRectMin(ctx)
    local maxx, maxy = reaper.ImGui_GetItemRectMax(ctx)
    return maxx - minx
end

---Return Last Item Min X,Y, Max X,Y
---@return number minx min x
---@return number miny min y
---@return number maxx max x
---@return number maxy max y
function GetLastItemEdges()
    local minx, miny = reaper.ImGui_GetItemRectMin(ctx)
    local maxx, maxy = reaper.ImGui_GetItemRectMax(ctx)
    return minx, miny, maxx, maxy
end

--- Keys Functions:
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

--- Colors
function rgba2num(red, green, blue, alpha)

	local blue = blue * 256
	local green = green * 256 * 256
	local red = red * 256 * 256 * 256
	
	return red + green + blue + alpha
end

function HSV(h, s, v, a)
    local r, g, b = reaper.ImGui_ColorConvertHSVtoRGB(h, s, v)
    return reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a or 1.0)
end
