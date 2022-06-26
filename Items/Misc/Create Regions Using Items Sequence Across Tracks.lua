-- @version 1.0
-- @author Daniel Lumertz
-- @changelog
--    + First Release

--[[
    This script will create regions across items in selected tracks.
    THIS SCRIPT DELETE ALL REGIONS BEFORE BEGGINING! 
    First region will start at the first item (in a selected track) that have the lowest start. The first region will end at the end of the first item (in a selected track) that ends later
    etc...
]]


------------ Options 
CheckItemsCnt = true
------------ General Functions
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

---pad a number eg: num = 12 ; cnt_numbers = 5 == 00012
---@param num number number to be padded
---@param cnt_numbers number  number of houses of numbers
function PadNumberWithZeros(num,cnt_numbers)
    local num_string = tostring(num)
    local num_zeros = cnt_numbers - num_string:len()
    local zero = '0'
    local zeroes = zero:rep(num_zeros)
    return zeroes..num_string    
end
------ Script

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
        local answer = reaper.ShowMessageBox('Some tracks have different nº of items!!\nDo you want to continue?' , 'Create Regions Using Item Sequence Across Tracks', 4)
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

--- Delete all regions
local retval, num_markers, num_regions = reaper.CountProjectMarkers(0)
for i = num_regions-1, 0, -1  do
    reaper.DeleteProjectMarker( 0, i, true )
end

---
local proj_name = reaper.GetProjectName(0) -- get proj name

-----Get new_pos
for i_items = 0, max_cnt-1 do
    local min_start = math.huge
    local max_end = 0
    local IsFirstItem -- to get the color
    local rgn_color
    for sel_track_idx, track_table in ipairs(sel_tracks) do -- Check each item n i_items from each track and get lowest and highest start/end values
        if track_table.cnt-1 >= i_items then-- check if this track have this item cnt
            local item = reaper.GetTrackMediaItem(track_table.track, i_items)
            local start = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
            local len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
            local fim = start + len

            min_start = math.min(start, min_start)
            max_end = math.max(fim, max_end)

            if not IsFirstItem then
                rgn_color = reaper.GetDisplayedMediaItemColor( item )
                IsFirstItem = true
            end
        end        
    end
    local decimal_houses = tostring(max_cnt):len() -- how many decimal houses
    if decimal_houses < 4 then decimal_houses = 4 end -- 4 is the minimum
    local pad_number_item = PadNumberWithZeros(i_items+1,decimal_houses)
    local rgn_name = proj_name:sub(1,4)..'_'..pad_number_item..'_1'
    reaper.AddProjectMarker2( 0, true, min_start, max_end, rgn_name, -1, rgn_color )
end

--- End Undo, project set
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock2(0, 'Script: Create Regions Using Item Sequence Across Tracks', -1)