-- @noindex

local main_window = reaper.GetMainHwnd()
local arrange_window = reaper.JS_Window_FindChildByID(main_window, 0x3E8)
function set_grid_pos(state, tr, env, p_grid, n_grid, y)
  local _, y = reaper.JS_Window_ScreenToClient(arrange_window, 0, math.floor(y + 0.5))
  local ret, left, top, right, bottom = reaper.JS_Window_GetRect(arrange_window)
  _, top = reaper.JS_Window_ScreenToClient(arrange_window, 0, math.floor(top + 0.5))
  local ty = reaper.GetMediaTrackInfo_Value(tr, 'I_TCPY')
  local ey = reaper.GetEnvelopeInfo_Value(env, 'I_TCPY')
  local eh = reaper.GetEnvelopeInfo_Value(env, 'I_TCPH_USED')
  local take = reaper.GetEnvelopeInfo_Value(env, 'P_TAKE')
  if type(take) == 'userdata' then
    local rate = reaper.GetMediaItemTakeInfo_Value(take, 'D_PLAYRATE')
    local item = reaper.GetMediaItemTake_Item(take)
    local i_pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    p_grid =  (p_grid - i_pos) * rate
    n_grid =  (n_grid - i_pos) * rate
  end
  local mo_y = y - (ty + ey) - top
  local n_val = 1 - (mo_y/eh)

  local br_env = reaper.BR_EnvAlloc(env, true)
  local _, _, _, _, _, _,
  min, max, _, _, fader_scaling, _ = reaper.BR_EnvGetProperties(br_env)
  reaper.BR_EnvFree(br_env, false)
  local r_val = min + ((max - min)*n_val)
  if fader_scaling then
    r_val = reaper.ScaleToEnvelopeMode(1, r_val)
  end
  if state.ctrl then 
    state.baseline = math.min(state.baseline + state.mdy/eh, 1)
    state.baseline = math.max(0, state.baseline)
  end
  local baseline_val = min + (max - min)*state.baseline

  local pp_grid = reaper.BR_GetPrevGridDivision(p_grid)
  local o = 0.00001
  local r, sv = reaper.Envelope_Evaluate(env, p_grid - o, 0, 0)
  local r, ev = reaper.Envelope_Evaluate(env, n_grid + o, 0, 0)
  
  --Edge points
  reaper.DeleteEnvelopePointRange(env, p_grid - 4*o, n_grid + 4*o)
  reaper.InsertEnvelopePoint(env, p_grid - o, sv, 0, 0, false, true)
  reaper.InsertEnvelopePoint(env, n_grid + o, ev, 0, 0, false, true)
  
  local sb, eb = p_grid + o, n_grid - o
  local shape = state.shape
  local t, inc = 0, 1/(#shape.values - 1)
  local rand = math.random() * r_val
  for i = 1, #shape.values do 
    local v = shape.values[i]
    local pos = sb + (eb - sb)*t
    if v == "r" then
      reaper.InsertEnvelopePoint(env, pos, math.random(), 0, 0, false, true)
    elseif v == "m" then
      reaper.InsertEnvelopePoint(env, pos, r_val, 0, 0, false, true)
    elseif v == "rs" then
      reaper.InsertEnvelopePoint(env, pos, rand, 0, 0, false, true)
    elseif tonumber(v) then
      if v == 0 then
        v = baseline_val
      end
      reaper.InsertEnvelopePoint(env, pos, v, 0, 0, false, true)
    elseif v == "rb" then
      local val = r_val + math.random() * (1 - r_val)
      reaper.InsertEnvelopePoint(env, pos, val, 0, 0, false, true)
    elseif v == "rm" then
      reaper.InsertEnvelopePoint(env, pos, math.random() * r_val, 0, 0, false, true)
    end
    t = t + inc
  end
  reaper.Envelope_SortPoints(env)
end

function get_all_divisions_between(sp, ep, lmp, mp, invert)
  if sp == 0 then return end
  local pos_buf = {sp}
  local s, e = math.min(sp, ep), math.max(sp, ep)
  while s < e do
    s = reaper.BR_GetNextGridDivision(s)
    table.insert(pos_buf, s)
  end

  local pair = {}
  for i = 1, #pos_buf - 1 do
    local ps = pos_buf[i]
    local pe = pos_buf[i + 1]
    table.insert(pair, {s = ps, e = pe})
  end

  for i = 1, #pair do
    local ind = i
    local pa = pair[ind]
    local t = (i - 1)/#pair
    if invert then t = 1 - t end
    pa.my = lmp + t*(mp - lmp)
  end
  return pair
end

function bound_to_razor_edits(edits, sp, ep)
  local sp, ep = sp, ep
  if #edits == 0 then return true, sp, ep end
  for i = 1, #edits do
    local e = edits[i]
    if sp >= e.s and ep <= e.e then
      return true, sp, ep
    elseif sp >= e.s and sp < e.e and ep > e.e then
      return true, sp, e.e
    elseif sp < e.s and ep > e.s and ep <= e.e then
      return true, e.s, ep
    end    
  end
  return false
end

function draw(state)
  local tr, env = state.track, state.env
  local pos = get_mouse_position_arrange()
  local p_grid = reaper.BR_GetPrevGridDivision(pos)
  local n_grid = reaper.BR_GetNextGridDivision(pos)
  local x, y = reaper.GetMousePosition()
  local trigger = state.last_grid ~= p_grid or state.shape.is_continuous or state.init
  if env and trigger then
    state.init = false
    local rs, es, invert = state.last_grid, n_grid, false
    if state.last_grid > p_grid then
      rs = p_grid
      es = reaper.BR_GetNextGridDivision(state.last_grid)
      invert = true
    end
    local a_pos = get_all_divisions_between(rs, es, state.lmp, y, invert)
    if a_pos then
      if not invert and #a_pos == 2 then table.remove(a_pos, 1) end
      reaper.PreventUIRefresh(1)
      --reaper.Undo_BeginBlock()
      for i = 1, #a_pos do
        local sp, ep, r = a_pos[i].s, a_pos[i].e, nil
        r, sp, ep = bound_to_razor_edits(state.razor_edits, sp, ep)
        if r then
          set_grid_pos(state, tr, env, sp, ep, a_pos[i].my)
        end
      end
      --reaper.Undo_EndBlock('Insert envelope palette', -1)
      reaper.PreventUIRefresh(-1)
    end
  end
  state.last_grid = p_grid
  state.lmp = y
end