--@noindex
--version: 0.2.1
--correct optional arguments for slider

DL = DL or {}
DL.imgui = {}

-------------
-- Widgets
-------------

local internal_func = {}

-- functions
function internal_func.change_value(mouse_ratio, is_int, min, max)
    local new_value = (mouse_ratio*(max-min))+min
    new_value = ((new_value < min and min) or new_value)  
    new_value = ((new_value > max and max) or new_value)  
    if is_int then
        new_value = math.floor(new_value + 0.5)
    end
    return new_value
end

---Search in t table for the closest number from val.
---@param t table table to be searched
---@param val number value to be compared
---@return number? closest_key key with the closest number
---@return number? closest_value
function internal_func.GetKeyWithClosestNumber(t,val)
    local closest_number = math.huge
    local closest_key = nil
    for key, value in pairs(t) do
        if type(value) == 'number' then
            local dif = math.abs(value - val)
            if dif < closest_number then
                closest_number = dif
                closest_key = key
            end
        end
    end
    return closest_key, closest_number
end

---Imgui Custom Widget for a slider with multiple grabbers.
---@param ctx ImGui_Context imgui ctx
---@param label string unique widget label
---@param values table table of grabble values 
---@param min number slider min value 
---@param max number slider max value
---@param is_int boolean is the slider an integer slider
---@param can_create boolean? optional default true, if true the user can create new grabbers by clicking on the with ctrl
---@param can_remove boolean? optional default true, if true the user can remove grabbers by clicking on them with alt
---@param w number? optional width of the widget
---@param h number? optional height of the widget
---@param formatting string ?optional formatting string for the values at tooltip
---@return boolean is_change boolean if the value was changed
---@return table values table of grabble values
function DL.imgui.MultiSlider(ctx,label,values,min,max,is_int,can_create,can_remove,w,h,formatting)
    ----- Get current position/style/color setting 
    can_create = can_create == nil and true or can_create
    can_remove = can_remove == nil and true or can_remove
    --- w h
    w = w or ImGui.CalcItemWidth(ctx)
    h = h or ImGui.GetFrameHeight(ctx)
    --- x y start
    local x1, y1 = ImGui.GetCursorScreenPos(ctx)  -- start cursor position
    --- color
    local col_framebg = ImGui.GetColor(ctx, ImGui.Col_FrameBg)
    local col_framebg_hovered = ImGui.GetColor(ctx, ImGui.Col_FrameBgHovered)
    local col_framebg_active = ImGui.GetColor(ctx, ImGui.Col_FrameBgActive)

    local col_border = ImGui.GetColor(ctx, ImGui.Col_Border)

    local col_slidergrab = ImGui.GetColor(ctx, ImGui.Col_SliderGrab)
    local col_slidergrab_active = ImGui.GetColor(ctx, ImGui.Col_SliderGrabActive)
    --- style  
    local frame_bordersize = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FrameBorderSize) 
    local frame_rounding = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FrameRounding)

    local grab_rounding = ImGui.GetStyleVar(ctx, ImGui.StyleVar_GrabRounding)
    local grab_w = ImGui.GetStyleVar(ctx, ImGui.StyleVar_GrabMinSize) 
    local grab_pad = 2 -- I dont think there is a way to change that

    local label_pad = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemInnerSpacing)
    -- mouse
    local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
    local mouse_ratio = (mouse_x-x1)/w -- 0 to 1 ratio how much mouse is in this slider
    local mouse_click = ImGui.IsMouseClicked(ctx,0)

    -- keys
    local ctrl = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl) -- ctrl
    local alt = ImGui.IsKeyDown(ctx, ImGui.Mod_Alt) -- ctrl
    -- tooltip
    formatting = formatting or ((is_int and '%.f') or '%.3f')
    -- return
    local bol = false

    ImGui.BeginGroup(ctx)
    --------------- Background 
    ImGui.SetNextItemAllowOverlap(ctx)
    ImGui.InvisibleButton(ctx, label, w, h)
    local is_hover = ImGui.IsItemHovered(ctx)
    local is_active = ImGui.IsItemActive(ctx)
    
    -------------- Grabs 
    local is_any_grab_active = false
    local is_any_grab_hover = false
    local grabs_list = {}

    for k,val in pairs(values) do
        val = ((val < min and min) or val)
        val = ((val > max and max) or val)
        -- calculate positions
        local ratio = (val-min)/(max-min) -- 0 to 1 how much this value is in between min and max
        local pos_x = ((w-4) * (ratio)) + x1 + 2  -- position if I would insert a line with no width. w-4 to give 2 pixel border, which is imgui default
        local grab_start = pos_x - (grab_w*ratio) -- offset the value. if ratio is 0 start grabble at pos_X. if ratio is 1 start it at pos_x - grabble width
        -- Create invisible button
        ImGui.SetCursorScreenPos(ctx, grab_start, y1)
        ImGui.InvisibleButton(ctx, '##'..label..'grabble'..k, grab_w, h)
        -- get info about grabble
        local grab_is_active = ImGui.IsItemActive(ctx)
        local grab_is_hover = ImGui.IsItemHovered(ctx)
        -- get new value if any (will draw new value at next frame)
        if can_remove and grab_is_active and alt and mouse_click then -- delete grab
            table.remove(values,k)
            bol = true
            goto continue
        elseif grab_is_active and not alt then -- move grab
            local new_value = internal_func.change_value(mouse_ratio, is_int, min, max)
            values[k] = new_value -- updates directly the table 
            bol = true      
        end
        -- show info about grabble
        if grab_is_active or grab_is_hover then
            if ImGui.BeginTooltip(ctx) then
                ImGui.Text(ctx, (formatting):format(val))
                ImGui.EndTooltip(ctx)
            end
        end

        is_any_grab_active = is_any_grab_active or grab_is_active
        is_any_grab_hover = is_any_grab_hover or grab_is_hover
        grabs_list[#grabs_list+1] = {
            hover = grab_is_hover,
            active = grab_is_active,
            start = grab_start,
        }
        ::continue::
    end

    if can_create and not is_any_grab_active and ctrl and is_active and mouse_click then -- Create a new value
        local new_value = internal_func.change_value(mouse_ratio, is_int, min, max)
        table.insert(values,new_value)
        bol = true
    end

    --------------- Draw
    local draw_list = ImGui.GetWindowDrawList(ctx) -- drawlist
    -- bg
    local bgcolor = ((is_active or is_any_grab_active) and col_framebg_active) or ((is_hover or is_any_grab_hover) and col_framebg_hovered) or col_framebg -- should be (is_active and col_framebg_active) or (is_hover and col_framebg_hovered) or col_framebg.  but when clicking a grabber it wont allow two invisible items active at the same time.
    ImGui.DrawList_AddRectFilled(draw_list, x1, y1, x1+w, y1+h, bgcolor, frame_rounding) -- Background 
    if frame_bordersize > 0 then  -- frame border
        ImGui.DrawList_AddRect(draw_list, x1, y1, x1+w, y1+h, col_border,frame_rounding,nil,frame_bordersize) -- Frame
    end
    -- grabs
    for k, grab in ipairs(grabs_list) do
        -- draw grabble
        local grabcol = (( grab.active or grab.hover ) and col_slidergrab_active) or col_slidergrab
        ImGui.DrawList_AddRectFilled(draw_list, grab.start, y1+grab_pad, grab.start+grab_w, y1+h-grab_pad, grabcol, grab_rounding) -- Background            
    end

    ---------------- Label Text
    local text_label = label:match('(.-)'..'##') or label
    if text_label:len() > 1 then 
        local text_w, text_h = ImGui.CalcTextSize(ctx, text_label, nil, nil, true)
        ImGui.SetCursorScreenPos(ctx, x1+w+label_pad, (y1+(h/2))-(text_h/2)) --return the position after the background
        ImGui.Text(ctx, text_label)
    end

    ImGui.EndGroup(ctx)

    return bol, values -- dont need to return tho, as it updates directly
end


---Knob widget. Made by cfillion
---@param ctx ImGui_Context imgui ctx
---@param label string knob label and identification
---@param p_value number knob value
---@param v_min number knob min value
---@param v_max number knob max value
---@param size number? knob radious size
---@return boolean value_changed boolean value to check if the knob value was changed
---@return number p_value number knob value
function DL.imgui.Knob(ctx, label, p_value, v_min, v_max, size)
    local radius_outer = size or ImGui.GetFrameHeight(ctx)
    local pos = {ImGui.GetCursorScreenPos(ctx)}
    local center = {pos[1] + radius_outer, pos[2] + radius_outer}
    local line_height = ImGui.GetTextLineHeight(ctx)
    local draw_list = ImGui.GetWindowDrawList(ctx)
    local item_inner_spacing = {ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemInnerSpacing)}
    local mouse_delta = {ImGui.GetMouseDelta(ctx)}

    local ANGLE_MIN = 3.141592 * 0.75
    local ANGLE_MAX = 3.141592 * 2.25

    ImGui.BeginGroup(ctx)
    ImGui.InvisibleButton(ctx, label, radius_outer*2, radius_outer*2 + line_height + item_inner_spacing[2])
    local value_changed = false
    local is_active = ImGui.IsItemActive(ctx)
    local is_hovered = ImGui.IsItemHovered(ctx)
    if is_active and mouse_delta[1] ~= 0.0 then
        local step = (v_max - v_min) / 200.0
        p_value = p_value + (mouse_delta[1] * step)
        if p_value < v_min then p_value = v_min end
        if p_value > v_max then p_value = v_max end
            value_changed = true
    end

    local t = (p_value - v_min) / (v_max - v_min)
    local angle = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * t
    local angle_cos, angle_sin = math.cos(angle), math.sin(angle)
    local radius_inner = radius_outer*0.40
    ImGui.DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_outer, ImGui.GetColor(ctx, ImGui.Col_FrameBg), 16)
    ImGui.DrawList_AddLine(draw_list, center[1] + angle_cos*radius_inner, center[2] + angle_sin*radius_inner, center[1] + angle_cos*(radius_outer-2), center[2] + angle_sin*(radius_outer-2), ImGui.GetColor(ctx, is_active and ImGui.Col_SliderGrabActive or ImGui.Col_SliderGrab), 2.0)
    ImGui.DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_inner, ImGui.GetColor(ctx, is_active and ImGui.Col_FrameBgActive or is_hovered and ImGui.Col_FrameBgHovered or ImGui.Col_FrameBg), 16)
    --ImGui.Text(ctx, label)
    local text = label:gsub('##.*', '')
    local w, h = ImGui.CalcTextSize(ctx, text)
    ImGui.DrawList_AddText(draw_list, pos[1]+radius_outer-(w/2), pos[2] + radius_outer * 2 + item_inner_spacing[2], ImGui.GetColor(ctx, ImGui.Col_Text), text)

    if is_active or is_hovered then
        local window_padding = {ImGui.GetStyleVar(ctx, ImGui.StyleVar_WindowPadding)}
        ImGui.SetNextWindowPos(ctx, pos[1]+radius_outer-(w/2) - window_padding[1], pos[2] - line_height - item_inner_spacing[2] - window_padding[2])
        if ImGui.BeginTooltip(ctx) then
            ImGui.Text(ctx, ('%.3f'):format(p_value))
            ImGui.EndTooltip(ctx)
        end
    end

    ImGui.EndGroup(ctx)

    return value_changed, p_value
end

---Draws a rectangle with multi-color fill.
---@param draw_list ImGui_DrawList ImGui draw list to use for rendering.
---@param p_min_x number minimum X coordinate of the rectangle.
---@param p_min_y number minimum Y coordinate of the rectangle.
---@param p_max_x number maximum X coordinate of the rectangle.
---@param p_max_y number maximum Y coordinate of the rectangle.
---@param stroke number? stroke width of the rectangle.
---@param col_upr_left number color of the upper-left corner of the rectangle.
---@param col_upr_right number color of the upper-right corner of the rectangle.
---@param col_bot_right number color of the bottom-right corner of the rectangle.
---@param col_bot_left number color of the bottom-left corner of the rectangle.
function DL.imgui.DrawList_AddRectMultiColor(draw_list, p_min_x, p_min_y, p_max_x, p_max_y, stroke, col_upr_left, col_upr_right, col_bot_right, col_bot_left)
    stroke = stroke or 1
    ImGui.DrawList_AddRectFilledMultiColor(draw_list, p_min_x, p_min_y, p_max_x, p_min_y+stroke, col_upr_left, col_upr_right, col_upr_right, col_upr_left) 
    ImGui.DrawList_AddRectFilledMultiColor(draw_list, p_max_x-stroke, p_min_y, p_max_x, p_max_y, col_upr_right, col_upr_right, col_bot_right, col_bot_right) 
    ImGui.DrawList_AddRectFilledMultiColor(draw_list, p_min_x, p_max_y-stroke, p_max_x, p_max_y, col_bot_left, col_bot_right, col_bot_right, col_bot_left) 
    ImGui.DrawList_AddRectFilledMultiColor(draw_list, p_min_x, p_min_y, p_min_x+stroke, p_max_y, col_upr_left, col_upr_left, col_bot_left, col_bot_left) 
end

----------------
---- Keys
----------------
---Stores key-related configuration for ImGui interactions, including keys to bypass from standard processing.
DL.imgui.keys = {
    --table with all keys to bypass from SWSPassKeys. Store the key code as indexes at this table, like this: DL.imgui.keys.bypass[	0x56] = true. https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
    bypass = {
        
    }
} 

local held_keys = {}
if reaper.JS_VKeys_GetState then -- add held notes at script start to the table
    local keys = reaper.JS_VKeys_GetState(0)
    for k = 1, #keys do
        if  keys:byte(k) ~= 0 then
            held_keys[k] = true
        end
    end
end
---Pass some key  to reaper
---@param ctx any
---@param is_midieditor any
function DL.imgui.SWSPassKeys(ctx, is_midieditor)
    if not reaper.CF_SendActionShortcut or not reaper.JS_VKeys_GetState then return end
    if (not ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_AnyWindow)) or ImGui.IsAnyItemActive(ctx) then return end -- Only when Script haves the focus

    local sel_window, section 
    if is_midieditor then
        local midi = reaper.MIDIEditor_GetActive()
        if midi then 
            sel_window = midi 
            section = 32060
        end
    end

    if not sel_window then -- Send to Main Window or Midi Editor closed
        sel_window = reaper.GetMainHwnd()
        section = 0
    end

    local keys = reaper.JS_VKeys_GetState(0)
    for k = 1, #keys do
        local is_key = keys:byte(k) ~= 0
        if k ~= 0xD and is_key and not held_keys[k] then
            if not DL.imgui.keys.bypass[k] then
                reaper.CF_SendActionShortcut(sel_window, section, k)
            end
            held_keys[k] = true
        elseif not is_key and held_keys[k] then
            held_keys[k] = nil
        end
    end

    if ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
        reaper.CF_SendActionShortcut(sel_window, section, 0xD)
    end
    if ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter) then
        reaper.CF_SendActionShortcut(sel_window, section, 0x800D)
    end  
end

----------------
---- Colors
----------------

---@param color number Color from some reaper function like reaper.GetTrackColor(track).
---@return integer color color in the 0xRRGGBB format. To convert 0xRRGGBB to R,G,B,A use ImGui.ColorConvertU32ToDouble4(rgba). 0xRRGGBB to 0xRRGGBBAA use  DL.imgui.RGBToRGBA 
function DL.imgui.ReaperToRGB(color)
    return ImGui.ColorConvertNative(color)       
end

---Input a RRGGBB hex color, from ImGui_ColorEdit3, and output a number color to be used for reaper objects, like markers. 
---@param rgb_input number number from ImGui_ColorEdit3, in the format 0xRRGGBB. To convert R,G,B,A to 0xRRGGBBAA use ImGui.ColorConvertDouble4ToU32(r, g, b, a)
---@return number new_color value to be used in functions like AddProjectMarker2
function DL.imgui.RGBToReaper(rgb_input)
    return ImGui.ColorConvertNative(rgb_input) | 0x1000000 -- | 0x1000000 is actually just to be safe.
end

function DL.imgui.RGBToRGBA(color)
    return (color<<8)|0xFF            
end

function DL.imgui.RGBAToRGB(color)
    return (color>>8)            
end

---Input a HSVA color, output is a number to insert in ImGUI widgets (from imgui demo)
---@param h number hue from 0 - 1
---@param s number saturation 0 - 1
---@param v number value 0 - 1
---@param a number? alpha 0 - 1
---@return number color color for imgui RRGGBBAA
function DL.imgui.HSVAtoRGBA(h, s, v, a)
    local r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
    return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1.0)
end

----------------
---- Misc
----------------

-- Insert a text at the center of the avail space
function DL.imgui.CenterText(ctx,text)
    local text_w, text_h = ImGui.CalcTextSize(ctx, text)
    local avail_w = ImGui.GetContentRegionAvail(ctx)
    ImGui.SetCursorPosX(ctx, avail_w/2 - text_w/2)
    ImGui.Text(ctx, text)
end

---Print on imgui screen
function DL.imgui.print(ctx,...)
    local t = {}
    for i, v in ipairs( { ... } ) do
        t[i] = tostring( v )
    end
    ImGui.Text(ctx, table.concat( t, " " ))
end


-----------------
----- Examples
-----------------

---Basic MIDI GUI for Popups. used at script : layers and Goto
---@param midi_table table midi table that store the midi learn information (which device, channel....) with the values to check if match {device = idx, type = midi_type, val1 = note/cc, ch}. device, ch, val1 are optional.
---@param midi_input table table with the midi input from DL.midi_io.GetInput
function DL.imgui.MIDILearn(ctx, midi_table, midi_input)
    ImGui.Text(ctx, 'MIDI:')
    local learn_text = midi_table.is_learn and 'Cancel' or 'Learn'
    if ImGui.Button(ctx, learn_text, -0.01) then
        midi_table.is_learn = not midi_table.is_learn
    end

    if midi_table.is_learn then
        if midi_input[1] then
            local msg_type,msg_ch,val1 = DL.midi.UnpackMIDIMessage(midi_input[1].msg)
            if msg_type == 9 or msg_type == 11 or msg_type == 8 then 
                midi_table.type = ((msg_type == 9 or msg_type == 8) and 9) or 11
                midi_table.ch = msg_ch
                midi_table.val1 = val1
                midi_table.device = midi_input[1].device
                midi_table.is_learn = false
            end
        end
    end
    
    local w = ImGui.GetContentRegionAvail(ctx)
    local x_pos = w - 10 -- position of X buttons
    if midi_table.type then 
        local name_type = midi_table.type == 9 and 'Note' or 'CC'
        DL.imgui.print(ctx, name_type..' : ',midi_table.val1)
        ImGui.SameLine(ctx,x_pos)
        if ImGui.Button(ctx, 'X##all') then
            midi_table.type = nil
            midi_table.ch = nil
            midi_table.val1 = nil
            midi_table.device = nil
            midi_table.is_learn = false
        end
    end

    if midi_table.ch then 
        DL.imgui.print(ctx, 'Channel : ',midi_table.ch)
        ImGui.SameLine(ctx,x_pos)
        if ImGui.Button(ctx, 'X##ch') then
            midi_table.ch = nil
        end
    end  

    if midi_table.device then 
        local retval, device_name = reaper.GetMIDIInputName(midi_table.device, '')
        DL.imgui.print(ctx, 'Device : ',device_name)
        ImGui.SameLine(ctx,x_pos)
        if ImGui.Button(ctx, 'X##dev') then
            midi_table.device = nil
        end
    end
    -- Optionally add a midi curve editor here
end