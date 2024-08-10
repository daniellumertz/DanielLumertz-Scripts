-- @noindex

local main_window = reaper.GetMainHwnd()
local arrange_window = reaper.JS_Window_FindChildByID(main_window, 0x3E8)
function get_grid(pos)
  local nxt = reaper.BR_GetNextGridDivision(pos)
  local prv = reaper.BR_GetPrevGridDivision(pos)
  return {next = nxt, prev = prv}
end

function get_mouse_position_arrange()
  local window, segment, details = reaper.BR_GetMouseCursorContext()
  local pos = reaper.BR_GetMouseCursorContext_Position()
  return pos
end

function get_envelope_under_mouse()
  local x, y = reaper.GetMousePosition()
  local track, info = reaper.GetThingFromPoint(x, y)
  local window, segment, details = reaper.BR_GetMouseCursorContext()
  local envelope, takeEnvelope = reaper.BR_GetMouseCursorContext_Envelope()
  if envelope then
    local env_name = ({reaper.GetEnvelopeName( envelope )})[2]
    return track, envelope, env_name
  end
  return track
end

function get_razor_edits(track, env)
  local razor_edits = {}
  local retval, re = reaper.GetSetMediaTrackInfo_String( track, 'P_RAZOREDITS', '', false)
  local re_buf = str_split(re, ' ')
  local i = 1
  while i < #re_buf do
    local razor_start = tonumber(re_buf[i])
    local razor_end = tonumber(re_buf[i+1])
    local _, _, razor_guid = string.find(re_buf[i + 2], '%"(.+)%"')
    local r, env_guid = reaper.GetSetEnvelopeInfo_String(env, 'GUID', '', false)
    if env_guid == razor_guid then
      table.insert(razor_edits, {s = razor_start, e = razor_end})
    end
    i = i + 3
  end
  return razor_edits
end