reaper.reaper.Undo_BeginBlock2(0)
tolerance = 0.1

local item = reaper.GetSelectedMediaItem(0, 0)
local track = reaper.GetMediaItem_Track( item )

local start = reaper.GetMediaItemInfo_Value(item, 'D_POSITION' )
local len  = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH' )
local fim = start + len

local n = reaper.GetMediaItemInfo_Value(item, 'IP_ITEMNUMBER' )

last_fim = fim
keep = true
i = n + 1
while(keep == true)
do
  item_loop = reaper.GetTrackMediaItem( track, i )
  if not item_loop then break end
  local n_takes = reaper.CountTakes( item_loop )
  if n_takes <= 1 then break end 
  local loop_start = reaper.GetMediaItemInfo_Value(item_loop, 'D_POSITION' )

  if loop_start > last_fim+tolerance then break end

  local loop_len  = reaper.GetMediaItemInfo_Value(item_loop, 'D_LENGTH' )
  local loop_fim = loop_start + loop_len

  last_fim = loop_fim
  last_item = item_loop
  i = i + 1
  reaper.SetMediaItemSelected( last_item, true )
end

last_item = reaper.GetTrackMediaItem( track, i-1 )
reaper.SetMediaItemSelected( last_item, true )

last_start = start
keep = true
i = n -1
while(keep == true)
do
  item_loop = reaper.GetTrackMediaItem( track, i )
  if not item_loop then break end
  local n_takes = reaper.CountTakes( item_loop )
  if n_takes <= 1 then break end 
  local loop_start = reaper.GetMediaItemInfo_Value(item_loop, 'D_POSITION' )
  local loop_len  = reaper.GetMediaItemInfo_Value(item_loop, 'D_LENGTH' )
  local loop_fim = loop_start + loop_len

  if loop_fim < last_start-tolerance then break Msg('c')end

  last_start = loop_start
  last_item = item_loop
  i = i - 1
  reaper.SetMediaItemSelected( last_item, true )
end

last_item = reaper.GetTrackMediaItem( track, i+1 )
reaper.SetMediaItemSelected( last_item, true )

reaper.UpdateArrange()
reaper.Undo_EndBlock2(0, 'Select Somethings', -1)


 

