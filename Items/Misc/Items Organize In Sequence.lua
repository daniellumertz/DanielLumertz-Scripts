-- @version 1.0
-- @author Daniel Lumertz
-- @provides
-- @changelog
--    + First Release


------------ Options 
CheckItemsCnt = true

GapItems = 0
GapGroups = 1
------------ Functions

------------ General
function print(...) 
    local t = {}
    for i, v in ipairs( { ... } ) do
      t[i] = tostring( v )
    end
    reaper.ShowConsoleMsg( table.concat( t, "\n" ) .. "\n" )
end

function PrintDeltaTime(start)
    print(reaper.time_precise()  - start)
end
  

----------- Script

--- Preparate create tracks and count items, put in a table

local max_cnt = 0
-- Count track items see if there is a difference, use the track with more items
local last_cnt
local track_cnt = reaper.CountSelectedTracks(0)
local sel_tracks = {} -- save each selected track, and the item cnt 
local prompt -- to ask user only once
for i_track = 0, track_cnt-1 do
    local track = reaper.GetSelectedTrack(0, i_track)
    local cnt = reaper.CountTrackMediaItems(track)
    if CheckItemsCnt and last_cnt and last_cnt ~= cnt and not prompt then -- check different track items sizes
        local answer = reaper.ShowMessageBox('Some tracks have different nº of items!!\nDo you want to continue?' , 'Organize Items In Sequence', 4)
        if answer == 7 then
            return
        end
        prompt = true 
    end
    max_cnt = math.max(cnt,max_cnt)
    sel_tracks[#sel_tracks+1] = {
        track = track,
        cnt = cnt
    }
    last_cnt = cnt
end



--- Undo and set ptoject
reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

-----Get new_pos
local items_table_pos = {}
local last_fim
for i_items = 0, max_cnt-1 do
    local is_gap_groups = true
    for sel_track_idx, track_table in ipairs(sel_tracks) do
        if track_table.cnt-1 >= i_items then-- check if this track have this item cnt
            
            local item = reaper.GetTrackMediaItem(track_table.track, i_items)
            local start = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
            local len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
            -- reposition item
            local new_pos = start 
            if last_fim then
                local gap = is_gap_groups and GapGroups or GapItems
                new_pos = last_fim + gap
                items_table_pos[#items_table_pos+1] = {
                    new_pos = new_pos,
                    item = item
                } 
            end
            -- Insert in the item table list
            last_fim = new_pos + len
            is_gap_groups = false
        end
    end
end

-- Change Item Positions 

for item, item_table in ipairs(items_table_pos) do
    reaper.SetMediaItemInfo_Value( item_table.item, 'D_POSITION', item_table.new_pos )
end


--- End Undo, project set
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock2(0, 'Organize Items in Sequence', -1)