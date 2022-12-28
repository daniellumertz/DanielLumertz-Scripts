--@noindex
---Imgui Custom Widget for a slider with multiple grabbers.
---@param ctx ctx imgui ctx
---@param label string unique widget label
---@param values table table of grabble values 
---@param min number slider min value 
---@param max number slider max value
---@param is_int boolean is the slider an integer slider
---@param can_create boolean optional default true, if true the user can create new grabbers by clicking on the with ctrl
---@param can_remove boolean optional default true, if true the user can remove grabbers by clicking on them with alt
---@param w number optional width of the widget
---@param h number optional height of the widget
---@param formatting string optional formatting string for the values at tooltip
---@return boolean is_change boolean if the value was changed
---@return table values table of grabble values
function ImGui_MultiSlider(ctx,label,values,min,max,is_int,can_create,can_remove,w,h,formatting)
    -- functions
    local function get_key_closest_val(t,val)
        local closest_number = math.huge
        local closest_number_key = nil
        for key, value in pairs(t) do
            if type(value) == 'number' then
                local dif = math.abs(value - val)
                if dif < closest_number then
                    closest_number = dif
                    closest_number_key = key
                end
            end
        end
        return closest_number_key
    end

    local function limitnumber(number,min,max)
        if min and number < min then return min end
        if max and number > max then return max end
        return number
    end

    local function new_value(mouse_ratio, is_int)
        local new_value = (mouse_ratio*(max-min))+min
        local new_value = limitnumber(new_value,min,max)
        if is_int then
            new_value = math.floor(new_value + 0.5)
        end
        return new_value
    end
    ----- Get current position/style/color setting 
    can_create = can_create or true
    can_remove = can_remove or true
    --- w h
    w = w or reaper.ImGui_CalcItemWidth(ctx)
    h = h or reaper.ImGui_GetFrameHeight(ctx)
    --- x y start
    local x1, y1 = reaper.ImGui_GetCursorScreenPos(ctx)  -- start cursor position
    --- color
    local col_framebg = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_FrameBg())
    --local col_framebg_hovered = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_FrameBgHovered())
    --local col_framebg_active = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_FrameBgActive())

    local col_border = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_Border())

    local col_slidergrab = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_SliderGrab())
    local col_slidergrab_active = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_SliderGrabActive())
    --- style  
    local frame_bordersize = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize()) 
    local frame_rounding = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding())

    local grab_rounding = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_GrabRounding())
    local grab_w = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_GrabMinSize()) 
    local grab_pad = 2 -- I dont think there is a way to change that

    local label_pad = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemInnerSpacing())
    -- mouse
    local mouse_x, mouse_y = reaper.ImGui_GetMousePos(ctx)
    local mouse_ratio = (mouse_x-x1)/w -- 0 to 1 ratio how much mouse is in this slider
    local mouse_click = reaper.ImGui_IsMouseClicked(ctx,0)
    -- keys
    local ctrl = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_ModCtrl()) -- ctrl
    local alt = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_ModAlt()) -- ctrl
    -- tooltip
    formatting = formatting or ((is_int and '%.f') or '%.3f')
    -- return
    local bol = false


    ---------------- Draw
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx) -- drawlist

    --------------- Background 
    reaper.ImGui_InvisibleButton(ctx, label, w, h)
    local is_hover = reaper.ImGui_IsItemHovered(ctx)
    local is_active = reaper.ImGui_IsItemActive(ctx)
    local bgcolor = col_framebg -- should be (is_active and col_framebg_active) or (is_hover and col_framebg_hovered) or col_framebg.  but when clicking a grabber it wont allow two invisible items active at the same time.
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x1+w, y1+h, bgcolor, frame_rounding) -- Background 
    if frame_bordersize > 0 then  -- frame border
        reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x1+w, y1+h, col_border,frame_rounding,nil,frame_bordersize) -- Frame
    end

    reaper.ImGui_SetItemAllowOverlap(ctx)
    -------------- Grabs 
    local is_any_grab_active

    for k,val in pairs(values) do
        val = limitnumber(val,min,max)
        if val >= min and val <= max then
            -- calculate positions
            local ratio = (val-min)/(max-min) -- 0 to 1 how much this value is in between min and max
            local pos_x = (w * (ratio)) + x1  -- position if I would insert a line with no width 
            local grab_start = pos_x - (grab_w*ratio) -- offset the value. if ratio is 0 start grabble at pos_X. if ratio is 1 start it at pos_x - grabble width
            -- Create invisible button
            reaper.ImGui_SetCursorScreenPos(ctx, grab_start, y1)
            reaper.ImGui_InvisibleButton(ctx, '##'..label..'grabble'..k, grab_w, h)
            -- get info about grabble
            local grab_is_active = reaper.ImGui_IsItemActive(ctx)
            local grab_is_hover = reaper.ImGui_IsItemHovered(ctx)
            -- show info about grabble
            if grab_is_active or grab_is_hover then
                reaper.ImGui_BeginTooltip(ctx)
                reaper.ImGui_Text(ctx, (formatting):format(val))
                reaper.ImGui_EndTooltip(ctx)
            end
            -- draw grabble
            local grabcol = (( grab_is_active or grab_is_hover ) and col_slidergrab_active) or col_slidergrab
            reaper.ImGui_DrawList_AddRectFilled(draw_list, grab_start, y1+grab_pad, grab_start+grab_w, y1+h-grab_pad, grabcol, grab_rounding) -- Background            
            -- get new value if any (will draw new value at next frame)
            if can_remove and grab_is_active and alt and mouse_click then -- delete grab
                table.remove(values,k)
                bol = true
            elseif grab_is_active and not alt  then -- move grab
                local new_value = new_value(mouse_ratio, is_int)
                values[k] = new_value -- updates directly the table 
                bol = true      
            end

            is_any_grab_active = is_any_grab_active or grab_is_active
        end
    end

    if can_create and not is_any_grab_active and ctrl and is_active and mouse_click then -- Create a new value
        local new_value = new_value(mouse_ratio, is_int)
        table.insert(values,new_value)
        bol = true
    elseif is_active and mouse_click and not alt and not ctrl then -- move closest value to mouse
        local new_value = new_value(mouse_ratio, is_int)
        local k = get_key_closest_val(values, new_value)
        if k then
            values[k] = new_value
        end
        bol = true
    end
    
    ---------------- Label Text

    local text_label = label:match('(.-)'..'##') or label
    if text_label:len() > 1 then 
        local text_w, text_h = reaper.ImGui_CalcTextSize(ctx, text_label, w, h, true)
        reaper.ImGui_SetCursorScreenPos(ctx, x1+w+label_pad, (y1+(h/2))-(text_h/2)) --return the position after the background
        reaper.ImGui_Text(ctx, text_label)
    end

    return bol, values -- dont need to return tho, as it updates directly
end


---Knob widget. Made by cfillion
---@param ctx ctx imgui ctx
---@param label string knob label and identification
---@param p_value number knob value
---@param v_min number knob min value
---@param v_max number knob max value
---@param size number knob radious size
---@return boolean value_changed boolean value to check if the knob value was changed
---@return number p_value number knob value
function Imgui_CustomKnob(ctx, label, p_value, v_min, v_max, size)
    local radius_outer = size or reaper.ImGui_CalcItemWidth(ctx)/2
    local pos = {reaper.ImGui_GetCursorScreenPos(ctx)}
    local center = {pos[1] + radius_outer, pos[2] + radius_outer}
    local line_height = reaper.ImGui_GetTextLineHeight(ctx)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    local item_inner_spacing = {reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemInnerSpacing())}
    local mouse_delta = {reaper.ImGui_GetMouseDelta(ctx)}

    local ANGLE_MIN = 3.141592 * 0.75
    local ANGLE_MAX = 3.141592 * 2.25

    reaper.ImGui_InvisibleButton(ctx, label, radius_outer*2, radius_outer*2 + line_height + item_inner_spacing[2])
    local value_changed = false
    local is_active = reaper.ImGui_IsItemActive(ctx)
    local is_hovered = reaper.ImGui_IsItemHovered(ctx)
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
    reaper.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_outer, reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_FrameBg()), 16)
    reaper.ImGui_DrawList_AddLine(draw_list, center[1] + angle_cos*radius_inner, center[2] + angle_sin*radius_inner, center[1] + angle_cos*(radius_outer-2), center[2] + angle_sin*(radius_outer-2), reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_SliderGrabActive()), 2.0)
    reaper.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_inner, reaper.ImGui_GetColor(ctx, is_active and reaper.ImGui_Col_FrameBgActive() or is_hovered and reaper.ImGui_Col_FrameBgHovered() or reaper.ImGui_Col_FrameBg()), 16)
    reaper.ImGui_DrawList_AddText(draw_list, pos[1], pos[2] + radius_outer * 2 + item_inner_spacing[2], reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_Text()), label)

    if is_active or is_hovered then
        local window_padding = {reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding())}
        reaper.ImGui_SetNextWindowPos(ctx, pos[1] - window_padding[1], pos[2] - line_height - item_inner_spacing[2] - window_padding[2])
        reaper.ImGui_BeginTooltip(ctx)
        reaper.ImGui_Text(ctx, ('%.3f'):format(p_value))
        reaper.ImGui_EndTooltip(ctx)
    end

    return value_changed, p_value
end

--- Similar to imgui Slider but with a mark overlay
function ImGui_SliderWithMark(ctx, label, v, v_mark, is_mark,v_min, v_max, mark_color, optional_formatIn, optional_flagsIn)
    local retval, v = reaper.ImGui_SliderDouble(ctx, label, v, v_min, v_max, optional_formatIn, optional_flagsIn)
    if is_mark then
        local minx, miny = reaper.ImGui_GetItemRectMin(ctx)
        local maxx, maxy = reaper.ImGui_GetItemRectMax(ctx)
    
        local x = MapRange(v_mark,v_min,v_max,minx,maxx)
    
        local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
        local color = mark_color or reaper.ImGui_GetStyleColor(ctx, reaper.ImGui_Col_PlotLinesHovered())
        reaper.ImGui_DrawList_AddLine(draw_list, x, miny+1, x, maxy-1, color, 2)
    end
    return retval, v
end


