-- @version 1.0
-- @author Daniel Lumertz
-- @changelog
--    + Initial Release

reaper.Undo_BeginBlock2(0)

local count_items = reaper.CountSelectedMediaItems(0)
for i = 0, count_items - 1 do
    local loop_item = reaper.GetSelectedMediaItem(0, i)
    local count_takes = reaper.CountTakes(loop_item)
    local sel_take = reaper.GetTake(loop_item, math.random(0,count_takes-1))
    reaper.SetActiveTake(sel_take)
end
reaper.UpdateArrange()

reaper.Undo_EndBlock2(0, 'Script: Randomize Takes', -1)