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