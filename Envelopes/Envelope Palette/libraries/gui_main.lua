-- @noindex

local shapes = {
  {name = "Step",                 values = {"m", "m"},                        type = "generic", is_continuous = true},
  {name = "Random Step",          values = {"rs", "rs"},                      type = "generic", is_continuous = false},
  {name = "Ramp",                 values = {"m", 0},                          type = "generic", is_continuous = true},
  {name = "Reverse Ramp",         values = {0, "m"},                          type = "generic", is_continuous = true},
  {name = "Random Ramp",          values = {"rm", 0},                         type = "generic", is_continuous = false},
  {name = "Reverse Random Ramp",  values = {0, "rm"},                         type = "generic", is_continuous = false},
  {name = "Triangle",             values = {0, "m", 0},                       type = "generic", is_continuous = true},
  {name = "Random Triangle",      values = {0, "rm", 0},                      type = "generic", is_continuous = false},
  {name = "Noise",                values = {"rm", "rm", "rm", "rm", "rm"},    type = "generic", is_continuous = false},
  {name = "Line / Step",          values = {"u", "m"},                        type = "generic", is_continuous = true},
  {name = "Random Line",          values = {"rm", "rm"},                      type = "generic", is_continuous = false},
}
local selected_shape = nil

local state = nil
function get_state(track, env, shape, running)
  local _, lmp = reaper.GetMousePosition()
  return {
    track = track, 
    env = env, 
    shape = deepcopy(shape), 
    running = running,
    last_grid = reaper.BR_GetPrevGridDivision(get_mouse_position_arrange()),
    lmp = lmp,
    init = true,
    razor_edits = get_razor_edits(track, env),
    baseline = 0,
    mdx = 0,
    mdy = 0
  }
end

local last_tr, last_env = nil, nil
local last_lmb = nil
local lx, ly, mdx, mdy = reaper.GetMousePosition(), 0, 0
function frame()
  --Shape selection
  local x, y = reaper.GetMousePosition()
  local w, h = reaper.ImGui_GetWindowSize(ctx)
  local cx, cy = reaper.ImGui_GetCursorPos(ctx)
  if reaper.ImGui_BeginListBox(ctx, '##Shapes', flt_min, h - cy - 8) then
    for i = 1, #shapes do
      local shape = shapes[i]
      local selected = selected_shape and selected_shape.name == shape.name
      local r, s = reaper.ImGui_Selectable(ctx, shape.name, selected)
      if r then 
        if selected_shape == shape then
          selected_shape = nil
        else
          selected_shape = shape 
        end
      end
    end
    reaper.ImGui_EndListBox(ctx)
  end
  
  --Intercepts
  local track, env, env_name = get_envelope_under_mouse()
  if selected_shape and env and not (state and state.running) then
    tooltip_at_mouse(env_name)
    set_draw_cursor()
  end
  if not last_env and env and selected_shape then
    intercept_mouse()
  elseif last_env and not env and selected_shape then
    release_mouse()
  end
  last_tr, last_env = track, env

  --Mouse button
  local lmb = reaper.JS_Mouse_GetState(95)&1 == 1
  if not last_lmb and lmb then
    if selected_shape and env then
      state = get_state(track, env, selected_shape, true)
    end
  elseif last_lmb and not lmb then
    --Maybe cleanup state here
    if state and state.running then 
      state = nil 
    end
    if env then
      set_draw_cursor()
    end
  end

  -- X-Raym fix for undo points
  if not lmb and last_lmb then
    reaper.Undo_OnStateChange("Insert envelope palette")
  end
  last_lmb = lmb

  --State
  mdx, mdy = lx - x, ly - y
  lx, ly = x, y
  if state and state.running then
    set_draw_cursor()
    state.ctrl = get_ctrl()
    state.mdx, state.mdy = mdx, mdy
    draw(state)
  end
end