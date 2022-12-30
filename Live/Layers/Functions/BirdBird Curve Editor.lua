--@noindex
--[[ MINIMAL EXAMPLE
---------------
local points = {ce_point(0.25, 0.85), ce_point(0.4, 0.5), ce_point(0.75, 0.5)}
local ctx = reaper.ImGui_CreateContext('Curve Editor Demo')
function loop()
  local visible, open = reaper.ImGui_Begin(ctx, 'Curve Editor', true)
  if visible then
    ce_draw(ctx, points, "curve", 0, 0, {0.1, 0.5, 0.8})
    reaper.ImGui_End(ctx)
  end
  if open then
    reaper.defer(loop)
  end
end
reaper.defer(loop)


GESTURES
Double Click               -----> Insert point
Right Click on Point       -----> Remove point
Alt (Option) + Left Drag   -----> Adjust segment tension
Alt (Option) + Right Click -----> Reset segment tension
Shift                      -----> Fine adjustment


DOCUMENTATION
There are a few functions that curve editor uses to draw the editor.

ce_point(number x, number y, optional number tension) 
  - Creates a point object at coordinates x, y and returns it, use this to build a table that you pass into "ce_draw()".
  - The x and y coordinates have to be in the [0, 1] range.

boolean ce_draw(ctx, table points, number w, number h, optional table values)
  - Draws an editor for the given ordered table of points, with the size w, h.
  - You can pass in 0 for width or height to use all available area.
  - Optionally pass in a table of double values as the 5th parameter to display values along the curve.
  - Returns true if the curve has been modified.
  
number ce_evaluate_curve(table points, number t)
  - Gets a value along the entire curve, given the distance "t". 
  - The argument "t" has to be in the [0, 1] range, if not, it will be clamped.
  
ce_sort_points(table points)
  - Sorts a given table of points by position, use this after you insert points manually.
  - This is not necessary to use if you are not inserting points programmatically.
  
ce_print_usage()
  - Prints this guide to the REAPER console.

ce_set_point_size(number value)
  - Sets curve point size
  
ce_set_display_point_size(number value)
  - Sets displayed point size ]]


local point_size           = 5
local hit_expand           = 6
local horizontal_detection = false
local display_handles      = false
local display_point_size   = 3
function ce_set_point_size(v) point_size = v end
function ce_set_display_point_size(v) display_point_size = v end

local function clamp(v, min, max)
  return math.min(math.max(v, min),max)
end
local function l(a, b, t)
  return a + (b - a)*t
end
local function fract(v)
  return v - math.floor(v)
end

local noodle = 0.3
local function get_handles(p1, p2, x_in)
  local tension  = p2.tension
  local p2y, p3y = l(0, x_in, tension), l(0, 1 - x_in, tension)
  if tension > 1 then
    p2y, p3y = l(x_in, 1, tension - 1), l(1 - x_in, 1, tension - 1)
  end
  return l(p1.y, p2.y, p2y), l(p1.y, p2.y, p3y), p2y, p3y
end
function ce_evaluate_curve(points, time)
  local t, p1, p2 = clamp(time, 0, 1)
  for i = 1, #points do
    if t < points[i].x then
      p1, p2 = points[i - 1], points[i]
      break
    elseif t == points[i].x then
      return points[i].y
    end
  end
  local nt = (t - p1.x)/(p2.x - p1.x)
  local p1y, p2y = p1.y, p2.y
  local h1y, h2y = get_handles(p1, p2, noodle)
  local s1, s2, s3 = l(p1y, h1y, nt), l(h1y, h2y, nt), l(h2y, p2y, nt)
  local s4, s5 = l(s1, s2, nt), l(s2, s3, nt)
  return l(s4, s5, nt)
end

function ce_point(x, y, tension) return {x = clamp(x, 0, 1), y = clamp(y, 0, 1), tension = tension and tension or 1, drag_x = x, drag_y = y} end
function ce_sort_points(points)
  table.sort(points, function(a, b) return a.x < b.x end)
end

function ce_invert_points(points,is_x,is_y)
  for point_idx, point in ipairs(points) do
    if is_x then 
      point.x = 1-point.x
    end

    if is_y then
      point.y = 1-point.y
    end
  end
  ce_sort_points(points)
end

local function validate_points(points)
  if #points == 0 then
    table.insert(points, ce_point(0, 0)) 
    table.insert(points, ce_point(1, 1))
  elseif points[1].x ~= 0 then
    table.insert(points, 1, ce_point(0, 0))
  end
  if points[#points].x ~= 1 then
    table.insert(points, ce_point(1, 0))
  end
end

function ce_draw(ctx, points, id, w, h, values)
  -------------- Set Colors

  -- Function
  ---@param old_color number color RRGGBBAA U32, from reaper.ImGui_GetColor
  ---@param alpha number from 0 to 1 new alpha
  ---@return number new_color color with the new alpha in RRGGBBAA U32
  local function get_color_with_new_alpha(old_color,alpha)
    local r, g, b, a = reaper.ImGui_ColorConvertU32ToDouble4(old_color)
      return reaper.ImGui_ColorConvertDouble4ToU32( r,  g,  b, alpha) -- hard coded alpha to 0.2
  end

  -- Get button colors to use at points and segments and section
  local color_default = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_Button()) 
  local color_hover = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_ButtonHovered()) 
  local color_active = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_ButtonActive())

 -- local color_values = 0xFFFFFFFF - color_default    --  complementary color from the buttons! 
 local color_values = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_PlotHistogram())
  local color_values_line = get_color_with_new_alpha(color_values,0.5)    --  faded

  local color_border = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_Border())

  -- Set a new alpha (dont make much sense transparent points.. )
  color_default = get_color_with_new_alpha(color_default,1)
  color_hover = get_color_with_new_alpha(color_hover,1)
  color_active = get_color_with_new_alpha(color_active,1)
  color_values = get_color_with_new_alpha(color_values,1)

  local color_background_section = get_color_with_new_alpha(color_default,0.1)
  local color_background_lines = get_color_with_new_alpha(color_default,0.2)
  


  --------------

  validate_points(points)
  local dl, rv = reaper.ImGui_GetWindowDrawList(ctx), false
  if reaper.ImGui_BeginChild(ctx, id, w, h, false,  reaper.ImGui_WindowFlags_NoScrollbar()) then
    local wx, wy = reaper.ImGui_GetWindowPos(ctx)
    local ww, wh = reaper.ImGui_GetWindowSize(ctx)
    local function get_from_norm(x, y)
      return wx + ww*x, wy + wh*(1-y)
    end
    local mx, my = reaper.ImGui_GetMousePos(ctx)
    local alt =  reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_Mod_Alt() > 0
    local shift = reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_Mod_Shift() > 0
    local ctrl = reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_Mod_Ctrl() > 0
    local l_po, points_display, remove = points[1], {}, {}
    local any_hovered = false
    for i = 1, #points do
      local po, end_p = points[i], false
      local x, y = get_from_norm(po.x, po.y)
      local lx, ly = get_from_norm(l_po.x, l_po.y)
      
      --SEGMENT
      local is_last_point = i == #points 
      local mouse_over_point, point_active, point_over_segment = false, false, false
      if alt and i > 1 then
        reaper.ImGui_SetCursorPos(ctx, lx - wx, 0)      
        if x - lx <= 0 then goto skip_segment end
        reaper.ImGui_InvisibleButton(ctx, tostring(i) .. "b", x - lx, wh - 10)
        if reaper.ImGui_IsItemActive(ctx) then
          local mdx, mdy = reaper.ImGui_GetMouseDelta(ctx)
          mdy = (mdy/wh) * (ly > y and 1 or -1);
          po.tension = clamp(po.tension - mdy*3*(shift and 0.1 or 1), 0, 2); 
          point_over_segment, rv = true, true
          reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeNS())
        end    
        if reaper.ImGui_IsItemHovered(ctx) and not reaper.ImGui_IsAnyItemActive(ctx) then
          point_over_segment = true      
          reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeNS())
          if reaper.ImGui_IsMouseClicked(ctx, 1) then po.tension = 1; rv = true end
        end
      end
      ::skip_segment::
  
      --POINT
      local m = (i == 1 or i == #points) and 1.5 or 1
      local point_size, hit_expand = point_size*m, hit_expand*m
      local bx = x - point_size - hit_expand - wx
      local by = y - point_size - hit_expand - wy
      local br = (point_size + hit_expand) * 2
      if not alt then
        reaper.ImGui_SetItemAllowOverlap(ctx)
        if horizontal_detection then
          reaper.ImGui_SetCursorPos(ctx, bx, 0)
          reaper.ImGui_InvisibleButton(ctx, tostring(i), br, wh)
        else
          reaper.ImGui_SetCursorPos(ctx, bx, by)
          reaper.ImGui_PushClipRect(ctx, wx, wy, wx + ww, wy + wh, true)
          reaper.ImGui_InvisibleButton(ctx, tostring(i), br, br)
          if display_handles then reaper.ImGui_DrawList_AddRect(dl, bx + wx, by + wy, bx + wx + br, by + wy + br, 0xE72D33FF) end
        end
        if reaper.ImGui_IsItemClicked(ctx, 0) then
          po.drag_x, po.drag_y = po.x, po.y
        end
        if reaper.ImGui_IsItemActive(ctx) then
          local mdx, mdy = reaper.ImGui_GetMouseDelta(ctx)
          mdx = mdx/ww; mdy = mdy/wh;
          if i > 1 and not is_last_point then
            po.drag_x = po.drag_x + mdx*(shift and 0.2 or 1)
            po.x = clamp(po.drag_x, l_po.x, points[i+1].x); 
          end
          po.drag_y = po.drag_y - mdy*(shift and 0.2 or 1)
          po.y = clamp(po.drag_y, 0, 1);
          point_active, rv = true, true
        end
        if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then
          po.drag_x, po.drag_y = po.x, po.y
        end
        if reaper.ImGui_IsItemHovered(ctx) and not reaper.ImGui_IsAnyItemActive(ctx) and not any_hovered then
          if reaper.ImGui_IsMouseClicked(ctx, 1) and not (is_last_point or i == 1) 
          and not reaper.ImGui_IsAnyItemActive(ctx) then
            table.insert(remove, i); rv = true
          end
          mouse_over_point = true
          any_hovered = true
        end
      end
      
      --DRAW
      local color = point_over_segment and color_active or color_default
      local p2y, p3y = get_handles(l_po, po, noodle)
      p2y = l(wy, wy + wh, 1 - p2y)
      p3y = l(wy, wy + wh, 1 - p3y)
      if i > 1 then
        reaper.ImGui_DrawList_AddBezierCubic(dl, lx, ly, 
          l(lx, x, noodle), p2y, 
          l(x, lx, noodle), p3y, 
          x, y, color, 2, 100)
      end
      if display_handles then
        reaper.ImGui_DrawList_AddCircle(dl, l(lx, x, noodle), p2y, point_size/m, color_values, 0)
        reaper.ImGui_DrawList_AddCircle(dl, l(x, lx, noodle), p3y, point_size/m, color_values, 0)
      end
      if point_over_segment then
        reaper.ImGui_DrawList_AddLine(dl, lx, wy, lx, wy + wh, color_default, 0.25)
        reaper.ImGui_DrawList_AddLine(dl, x, wy, x, wy + wh, color_default, 0.25)
        reaper.ImGui_DrawList_AddRectFilled(dl, lx, wy, x, wy + wh, color_background_section)
      end
      local color = (point_active and color_active) or (mouse_over_point and color_hover) or color_default
      local color_fill = (mouse_over_point or point_active) and 0xB6DCFFAF or 0x378BF2AF -- Not used?
      if mouse_over_point or point_active then
        reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
        reaper.ImGui_DrawList_AddLine(dl, x, wy, x, wy + wh, color_background_lines, 0.25)
      end
      table.insert(points_display, {dl, x, y, point_size, color, 0})
      
      l_po = po
    end
    reaper.ImGui_DrawList_AddRect(dl, wx+1, wy, wx + ww, wy + wh, color_border, 0, 0, 3) 
    for i = 1, #points_display do
      reaper.ImGui_DrawList_AddCircleFilled(table.unpack(points_display[i]))
    end
    
    if values then
      for i = 1, #values do
        local yp     = ce_evaluate_curve(points, values[i])
        local xc, yc = get_from_norm(values[i], yp)
        reaper.ImGui_DrawList_AddCircleFilled(dl, xc, yc, display_point_size, color_values)
        reaper.ImGui_DrawList_AddLine(dl, xc, yc, xc, wy + wh, color_values_line, 0.25)
      end
    end
    
    if #remove >= 1 then table.remove(points, remove[#remove]) end
    if reaper.ImGui_IsMouseDoubleClicked(ctx, 0) and reaper.ImGui_IsWindowHovered(ctx) then
      local nx = (mx - wx)/ww
      local ny = 1 - (my - wy)/wh
      for i = 1, #points do 
        if points[i].x > nx then
          table.insert(points, i, ce_point(nx, ny))
          rv = true
          break
        end
      end
    end
    reaper.ImGui_EndChild(ctx)
  end
  return rv
end