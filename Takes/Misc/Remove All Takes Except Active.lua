-- @version 1.0
-- @author Daniel Lumertz
-- @changelog
--    + Initial Release

reaper.Undo_BeginBlock2(proj)
reaper.PreventUIRefresh(1)

local proj = 0 

local n_items = reaper.CountSelectedMediaItems(proj)
for i_idx = 0, n_items - 1 do 
  local item = reaper.GetSelectedMediaItem(proj, i_idx)
  local n_takes = reaper.CountTakes(item)
  local active_take = reaper.GetActiveTake(item)
  for t_idx = n_takes -1, 0, -1 do
    local take = reaper.GetTake(item,t_idx)
    if take ~= active_take then
      local bol = reaper.NF_DeleteTakeFromItem( item, t_idx )
    end
  end
end

reaper.Undo_EndBlock2(proj, "Remove All Takes Except Active", 1)
reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)
