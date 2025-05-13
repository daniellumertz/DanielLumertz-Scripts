--@noindex
--version: 0.0

DL = DL or {}
DL.play = {}

---@param proj ReaProject|0|nil
---@return number
function DL.play.GetCurrentPlayPosition(proj)
    local is_play = reaper.GetPlayStateEx(proj)&1 == 1 -- is playing 
    local pos = (is_play and reaper.GetPlayPositionEx( proj )) or reaper.GetCursorPositionEx(proj) -- current pos
    return pos
end