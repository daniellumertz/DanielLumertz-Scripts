--@noindex
--version: 0.18
-- Crop item


------- Iterate 

-- Projects
function enumProjects()
    local i = -1
    return function ()
        i = i +1
        return reaper.EnumProjects( i )
    end
end

-- Tracks
function enumTracks(proj)
    local cnt = reaper.CountTracks(proj)
    local i = 0
    return function ()
        while i < cnt do -- (i and Get) are 0 based. cnt is 1 based.
            local track = reaper.GetTrack(proj, i) -- get current selected item
            i = i + 1 -- for next time
            return track
        end
        return nil
    end
end

function enumSelectedTracks(proj)
    local cnt = reaper.CountSelectedTracks(proj)
    local i = 0
    return function ()
        while i < cnt do -- (i and Get) are 0 based. cnt is 1 based.
            local track = reaper.GetSelectedTrack(proj, i) -- get current selected item
            i = i + 1 -- for next time
            return track
        end
        return nil
    end
end

function enumSelectedTracks2(proj,wantmaster)
    local cnt = reaper.CountSelectedTracks2( proj, wantmaster)
    local i = 0
    return function ()
        while i < cnt do -- (i and Get) are 0 based. cnt is 1 based.
            local track = reaper.GetSelectedTrack2(proj, i, wantmaster) -- get current selected item
            i = i + 1 -- for next time
            return track
        end
        return nil
    end
end

-- Items
function enumSelectedItems(proj)
    local cnt = reaper.CountSelectedMediaItems(0)
    local i = 0
    return function ()
        while i < cnt do -- (i and Get) are 0 based. cnt is 1 based.
            local item = reaper.GetSelectedMediaItem(proj, i) -- get current selected item
            i = i + 1 -- for next time
            return item
        end
        return nil
    end
end

function enumItems(proj)
    local cnt = reaper.CountMediaItems(proj)
    local i = 0
    return function ()
        while i < cnt do -- (i and Get) are 0 based. cnt is 1 based.
            local item = reaper.GetMediaItem(proj, i) -- get current selected item
            i = i + 1 -- for next time
            return item
        end
        return nil
    end
end

function enumTrackItems(track)
    local cnt =  reaper.CountTrackMediaItems( track )
    local i = 0
    return function ()
        while i < cnt do -- (i and Get) are 0 based. cnt is 1 based.
            local item =  reaper.GetTrackMediaItem( track, i )-- get current selected item
            i = i + 1 -- for next time
            return item
        end
        return nil
    end
end

-- Takes
function enumSelectedMIDITakes(proj)
    local cnt = reaper.CountSelectedMediaItems(proj)
    local i = 0
    return function ()
        while i < cnt do -- (i and Get) are 0 based. cnt is 1 based.
            local item = reaper.GetSelectedMediaItem(proj, i) -- get current selected item
            i = i + 1 -- for next time
            local take = reaper.GetActiveTake(item)
            if reaper.TakeIsMIDI(take) then -- make sure, that take is MIDI
                return take -- this break and return
            end
        end
        return nil
    end
end

function enumTakes(item)
    local cnt = reaper.CountTakes(item)
    local i = 0
    return function ()
        while i < cnt do -- (i and Get) are 0 based. cnt is 1 based.
            local take = reaper.GetTake(item, i)
            i = i + 1 -- for next time
            return take
        end
        return nil
    end
end

function enumTakeMarkers(take)
    local cnt =  reaper.GetNumTakeMarkers( take )
    local i = 0
    return function ()
        while i < cnt do -- (i and Get) are 0 based. cnt is 1 based.
            local retval, name, color = reaper.GetTakeMarker( take, i )
            i = i + 1 -- for next time
            return retval, name, color
        end
        return nil
    end
end

-- Envelopes
function enumTrackEnvelopes(track)
    local cnt = reaper.CountTrackEnvelopes(track)
    local i = 0
    return function ()
        while i < cnt do -- (i and Get) are 0 based. cnt is 1 based.
            local env = reaper.GetTrackEnvelope( track, i ) -- get current selected item
            i = i + 1 -- for next time
            return env
        end
        return nil
    end
end

function enumTakeEnvelopes(take)
    local cnt = reaper.CountTakeEnvelopes(take)
    local i = 0
    return function ()
        while i < cnt do -- (i and Get) are 0 based. cnt is 1 based.
            local env = reaper.GetTakeEnvelope( take, i ) -- get current selected item
            i = i + 1 -- for next time
            return env
        end
        return nil
    end
end

-- Envelope Points

---Get the points on a track envelope. 
---@param env envelope
---@param autoitem_idx integer From REAPER docs: autoitem_idx=-1 for the underlying envelope, 0 for the first automation item on the envelope, etc. For automation items, pass autoitem_idx|0x10000000 to base ptidx on the number of points in one full loop iteration, even if the automation item is trimmed so that not all points are visible.
---@return function iterate retval, time, value, shape, tension, selected, idx
function enumTrackEnvelopesPointsEx(env, autoitem_idx)
    local cnt = reaper.CountEnvelopePointsEx( env, autoitem_idx )
    local i = 0
    return function ()
        while i < cnt do
            local retval, time, value, shape, tension, selected = reaper.GetEnvelopePointEx( env, autoitem_idx, i )
            i = i + 1
            return retval, time, value, shape, tension, selected, i-1
        end
        return nil
    end
end

-- Markers

---Iterate fuction returns retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber using EnumProjectMarkers2
---@param proj ReaperProject project 
---@param only_marker number 0 = both, 1 = only marker, 2 = only region. 1 is the default
---@return function iterate retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber
function enumMarkers2(proj, only_marker)
    if not only_marker then only_marker = 1 end
    local i = -1
    local retval, num_markers, num_regions = reaper.CountProjectMarkers(proj)
    local cnt = num_markers + num_regions
    return function ()
        while i < cnt do -- (i and Get) are 0 based. cnt is 1 based.
            i = i + 1
            local retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers2( proj, i )
            if retval == 0 then break end
            if (only_marker == 0) or (only_marker == 1 and not isrgn) or (only_marker == 2  and isrgn) then -- filter
                return retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber, i
            end
        end
        return nil
    end
end

---Iterate fuction returns retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber using EnumProjectMarkers2
---@param proj ReaperProject 
---@param only_marker number 0 = both, 1 = only marker, 2 = only region. 1 is the default
---@return function iterate retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber
function enumMarkers3(proj, only_marker)
    if not only_marker then only_marker = 1 end
    local i = -1
    local retval, num_markers, num_regions = reaper.CountProjectMarkers(proj)
    local cnt = num_markers + num_regions
    return function ()
        while i < cnt do -- (i and Get) are 0 based. cnt is 1 based.
            i = i + 1
            local retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3( proj, i )
            if retval == 0 then break end
            if (only_marker == 0) or (only_marker == 1 and not isrgn) or (only_marker == 2  and isrgn) then -- filter
                return retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber, color, i
            end
        end
        return nil
    end
end

--------
----- Tracks
--------

------ Actions
---Select A list of tracks or one item. Validate them first
---@param tracklist table List of tracks to select. {track1, track2, track3} as userdata. Or just a track
---@param unselect boolean optional, unselect before selecting? 
function SelectTrackList(tracklist, unselect, proj)
    if unselect == nil then unselect = true end -- make it optional
    proj = proj or 0
    if unselect then -- Deselect all (I suppose this is the fastest. I bench with looping all selected tracks and unselect them and this is a little bit faster )
        local master = reaper.GetMasterTrack(proj)
        reaper.SetOnlyTrackSelected(master)
        reaper.SetTrackSelected(master, false)
    end
    if type(tracklist) == 'userdata' then tracklist = {tracklist} end
    for i, track in ipairs(tracklist) do
        if reaper.ValidatePtr2(0, track, 'MediaTrack*') then
            reaper.SetTrackSelected(track, true)
        end
    end
end

---Create a table with the selected Tracks
---comment
---@param proj proj proj or nil(sane as 0)
---@param wantmaster boolean want master track?
---@return table table with tracks
function CreateSelectedTrackTable(proj, wantmaster)
    local t = {}
    for track in enumSelectedTracks2(proj, wantmaster) do
        t[#t+1] = track
    end
    return t
end


----- Get

---Get MediaTrack by name if it exists. Return false if it dont find.
---@param proj number Project number or project.
---@param name string Track name to find.
function GetTrackByName(proj,name)
    local track_cnt = reaper.CountTracks(proj)
    for i = 0, track_cnt-1 do
        local loop_track = reaper.GetTrack(proj, i)
        local bol, loop_name = reaper.GetTrackName(loop_track)
        if loop_name == name then
            return loop_track
        end
    end
    return false
end

---Create a table with the selected tracks
---@return table selected_tracks
function CreateSelectedTracksTable(proj)
    local t = {}
    for track in enumSelectedTracks2(proj,true) do
        t[#t+1] = track
    end
    return t
end


----------
------- Items
----------

------ Actions
---Select A list of items or one item. Validate them first
---@param itemlist table List of items to select. {item1, item2, item3} as userdata. Or just the item
---@param unselect boolean optional, unselect before selecting? 
function SelectItemList(itemlist, unselect, proj)
    if unselect == nil then unselect = true end -- make it optional
    proj = proj or 0
    if unselect then  -- Deselect all selected items
        reaper.SelectAllMediaItems( proj, false )
    end
    if type(itemlist) == 'userdata' then itemlist = {itemlist} end
    for i, item in ipairs(itemlist) do
        if reaper.ValidatePtr2(0, item, 'MediaItem*') then
            reaper.SetMediaItemSelected(item, true)
        end
    end
end

-- Copy an item to a track and position
function CopyMediaItemToTrack( item, track, position ) -- Thanks Amagalma s2
    local _, chunk = reaper.GetItemStateChunk( item, "", false )
    chunk = chunk:gsub("{.-}", "") -- Reaper auto-generates all GUIDs
    local new_item = reaper.AddMediaItemToTrack( track )
    reaper.SetItemStateChunk( new_item, chunk, false )
    reaper.SetMediaItemInfo_Value( new_item, "D_POSITION" , position )
    return new_item
end

---Create a table with the selected items
---@return table selected_items
function CreateSelectedItemsTable(proj)
    local t = {}
    for item in enumSelectedItems(proj) do
        t[#t+1] = item
    end
    return t
end

---Crop Item position keeping elements on the same place
---@param item item
---@param new_start_pos number optional new start position in seconds
---@param new_end_pos number optional new end position in seconds
---@param start number optional original start position in seconds, if not provided function will get it, provide if you already have and save resources 
---@param length number optional original length position in seconds, if not provided function will get it, provide if you already have and save resources 
function CropItem(item, new_start_pos, new_end_pos, start, length)
    start = start or reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    length = length or reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    local fim = start + length
    if new_end_pos then
        local dif = new_end_pos - start
        reaper.SetMediaItemLength( item, dif, false )
        length = dif
    end
    if new_start_pos then
        local dif = new_start_pos - start
        reaper.SetMediaItemPosition(item, new_start_pos, false)
        reaper.SetMediaItemLength( item, length - dif, false )

        for take in enumTakes(item) do
            local offset = reaper.GetMediaItemTakeInfo_Value(take, 'D_STARTOFFS')            
            local rate = reaper.GetMediaItemTakeInfo_Value(take, 'D_PLAYRATE')            
            reaper.SetMediaItemTakeInfo_Value( take, 'D_STARTOFFS' , offset + (dif*rate) )
        end
    end    
end

---Return a list with all items in a project
---@param proj project 
function CreateItemsTable(proj)
    local t = {}
    for item in enumItems(proj) do
        t[#t+1] = item
    end
    return t
end


---Select an item, or list of items. Option to moveview to the first item at the center of the screen using current zoom 
---@param proj project
---@param item item
---@param moveview boolean move view to the first item?
function SetItemSelected(proj, item, moveview)
    SelectItemList(item, true, proj)
    if not moveview then
        return
    end
    if type(item) == 'table' then item = item[1] end -- just the first item
    local start_time, end_time = reaper.GetSet_ArrangeView2( proj, false, 0, 0, 0, 0 )
    local pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    if pos < start_time or pos > end_time then -- Item out of view, center the view at the item start
        local dif = end_time - start_time
        start_time, end_time = reaper.GetSet_ArrangeView2( proj, true, 0, 0, pos-(dif*1/3), pos+(dif*2/3))
    end
end

---Write an ext state at an item
---@param item MediaItem
---@param extname string name of the ext state section
---@param key string name of the key inside the extname section
---@param value string value to store 
---@return boolean
function SetItemExtState(item, extname, key, value)
    local  retval, extstate = reaper.GetSetMediaItemInfo_String( item, 'P_EXT:'..extname..': '..key, value, true )
    return retval
end

---Return the item ext state value
---@param item MediaItem
---@param extname string name of the ext state section
---@param key string name of the key inside the extname section
---@return boolean retval
---@return string value
function GetItemExtState(item, extname, key)
    local retval, extstate = reaper.GetSetMediaItemInfo_String( item, 'P_EXT:'..extname..': '..key, '', false )
    return retval, extstate
end

---Return a list with all items in a time range
---@param proj project
---@param start_range number beginning of the range (start point are includded in the range)
---@param fim_range number end of the range (end points are not includded in the range)
---@param only_start_in_range boolean only get items that start inside the range (if start at start_range it is includded)
---@param only_end_in_range boolean only get items that end inside the range (if end at the fim_range it is includded)
function GetItemsInRange(proj,start_range,fim_range,only_start_in_range,only_end_in_range)
    local item_list = {}
    for track in enumTracks(proj) do
        for item in enumTrackItems(track) do 
            local pos = reaper.GetMediaItemInfo_Value( item, 'D_POSITION')

            if only_start_in_range and pos < start_range then goto continue end -- filter if only_start_in_range 
            if pos >= fim_range then break end -- start after range. break

            local len = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH')
            local final_pos = len + pos
            if only_end_in_range and final_pos > fim_range then goto continue end -- filter if only_end_in_range

            if final_pos > start_range then
                item_list[#item_list+1] = item
            end

            ::continue::
        end
    end
    return item_list
end

-----------
--------- Take
-----------

---Write an ext state at an item
---@param item MediaItem
---@param extname string name of the ext state section
---@param key string name of the key inside the extname section
---@param value string value to store 
---@return boolean
function SetTakeExtState(item, extname, key, value)
    local  retval, extstate = reaper.GetSetMediaItemTakeInfo_String( item, 'P_EXT:'..extname..': '..key, value, true )
    return retval
end

---Return the item ext state value
---@param item MediaItem
---@param extname string name of the ext state section
---@param key string name of the key inside the extname section
---@return boolean retval
---@return string value
function GetTakeExtState(item, extname, key)
    local retval, extstate = reaper.GetSetMediaItemTakeInfo_String( item, 'P_EXT:'..extname..': '..key, '', false )
    return retval, extstate
end

---Return the index of a take in a item. 0 based
function GetTakeIndex(item, take)
    local idx = 0
    for loop_take in enumTakes(item) do
        if take == loop_take then
            return idx
        end
        idx = idx + 1
    end
end

-----------
--------- Time / QN
-----------

function CreateTimeQNTable() -- From JS Multitool THANKS THANKS THANKS!
    -- After creating use like print(tQNFromTime[proj][960]) if it dont already have the value it will create and return. 
    local tQNFromTime = {} 
    local tTimeFromQN = {}
    setmetatable(tTimeFromQN, {__index = function(t, proj) t[proj] = setmetatable({}, {__index = function(tt, qn) 
                                                                                                    local time = reaper.TimeMap2_QNToTime(proj, qn)
                                                                                                    tt[qn] = time
                                                                                                    tTimeFromQN[proj][time] = qn
                                                                                                    return time 
                                                                                                end
                                                                                        }) return t[proj] end})
                                                                                        
    setmetatable(tQNFromTime, {__index = function(t, proj) t[proj] = setmetatable({}, {__index = function(tt, time) 

                                                                                                    local qn = reaper.TimeMap2_timeToQN(proj, time)
                                                                                                    tt[time] = qn
                                                                                                    tQNFromTime[proj][qn] = time
                                                                                                    return qn 
                                                                                                end
                                                                                        }) return t[proj] end})

    return tQNFromTime, tTimeFromQN -- Return related to project time
end

---Get Arrange Position from screen cordinates x and y, it checks if the x+y is at the arrange part, ruler dont count. Return false if out of x bounds.
---@param proj project reaper project or 0
---@param x number
---@param y number
---@param main_hwnd hwnd optional main_hwnd or nil (get inside the function)
function GetArrangePosition(proj,x,y,main_hwnd) -- thanks birdbird
    local main_hwnd = main_hwnd or reaper.GetMainHwnd()
    local start_time, end_time = reaper.GetSet_ArrangeView2( proj, false, 0, 0, 0, 0 )
    local arrange_window_id = 0x3E8 -- optionally could use reaper.JS_Window_FindChild( main_hwnd, 'trackview', true ), but it just work on windows
    local arrange_window = reaper.JS_Window_FindChildByID(main_hwnd, arrange_window_id)
    local retval, left, top, right, bottom = reaper.JS_Window_GetRect( arrange_window )

    if x < left and x > right then return false end -- out of bounds

    local cx, _ = reaper.JS_Window_ScreenToClient(arrange_window, x, 0) -- Converts the screen coordinates of a specified point on the screen to client-area coordinates.
    local t = cx / (right - left) --distance along the arrange, in the range 0, 1
    return  start_time + (end_time - start_time)*t
end

---------
----- Marker / Region
---------

---Get the first mark that matches the name and is region
---@param proj ReaperProject 
---@param name string string to check
---@param only_marker number 0 = both, 1 = only marker, 2 = only region. 1 is the default
function GetMarkByName(proj,name,only_marker)
    for retval, isrgn, mark_pos, rgnend, mark_name, markrgnindexnumber, color, idx in enumMarkers3(proj, only_marker) do 
        if name == mark_name then 
            return retval, isrgn, mark_pos, rgnend, mark_name, markrgnindexnumber, color, idx
        end
    end
end

---Get the first mark that matches the user ID.
---@param proj ReaperProject 
---@param id number marker USER id. it is the ID the user see and set at Edit Marker/region.
---@param only_marker number 0 = both, 1 = only marker, 2 = only region. 1 is the default
---@return boolean retval, boolean isrgn, number mark_pos, number rgnend, string mark_name, number markrgnindexnumber, number color, number idx idx is the mark/region index that are passed to actions like reaper.EnumProjectMarkers3( proj, idx ). markrgnindexnumber is the index the user sets to a marker 
function GetMarkByID(proj,id,only_marker)
    for retval, isrgn, mark_pos, rgnend, mark_name, markrgnindexnumber, color, idx in enumMarkers3(proj, only_marker) do 
        if id == markrgnindexnumber then 
            return retval, isrgn, mark_pos, rgnend, mark_name, markrgnindexnumber, color, idx
        end
    end
    return false
end

---comment
---@param proj project
---@param pos number
---@param only_marker number  0 = both, 1 = only marker, 2 = only region. 1 is the default
function GetClosestMarker(proj, pos, only_marker)
    local previous = false
    local previous_table = false
    for retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber, color, i in enumMarkers3(proj, only_marker) do
        if mark_pos > pos then 
            if previous then -- compare marker before with next return closest.
                if (pos-previous) <= (mark_pos-pos) then
                    retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber, color, i = table.unpack(previous_table)
                end
            end
            return retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber, color, i
        elseif mark_pos == pos then
            return retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber, color, i
        elseif mark_pos < pos  then
            previous = mark_pos
            previous_table = {retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber, color, i}
        end
    end

    if previous_table then -- in case there wasnt any markers after the marker before position
        return table.unpack(previous_table)
    else 
        return false
    end
end

-----------
------ Envelopes
-----------

---Get The Envelope by the GUID. Search at tracks and/or items
---@param guid string GUID to search, with {}.
---@param is_track number 0 = just items, 1 just tracks, 2 both
function GetEnvelopeByGUID(proj, guid, is_track)
    if is_track == 1 or is_track == 2 then
        for track in enumTracks(proj) do
            local env = reaper.GetTrackEnvelopeByChunkName( track, guid )
            if env then
                return env
            end
        end
    end

    if is_track == 0 or is_track == 2 then
        for item in enumItems(proj) do
            for take in enumTakes(item) do
                for env in  enumTakeEnvelopes(take) do
                    if guid == GetEnvelopeGUID(env) then
                        return env
                    end
                end
            end
        end
    end
end

---Return the GUID of a envelope.
---@param env Envelope Envelope 
---@return string guid Guid
function GetEnvelopeGUID(env)
    local retval, chunk = reaper.GetEnvelopeStateChunk(env, '', false)
    return GetChunkVal(chunk,'EGUID')
end

---Return if the envelope bypass. 
---@param env Envelope Envelope
---@return boolean is_passing false = bypass, true = not bypass
function GetEnvelopeBypass(env)
    local retval, chunk = reaper.GetEnvelopeStateChunk(env, '', false)
    return GetChunkVal(chunk,'ACT'):match('^%d+') == '1'
end

---Get an envelope and return min, max, center. By Cfillion
---@param env Envelope
---@return number min
---@return number max
---@return number center
function GetEnvelopeRange(env)
  local ranges = {
    ['PARMENV'] = function(chunk)
      local min, max = chunk:match('^[^%s]+ [^%s]+ ([^%s]+) ([^%s]+)')
      local min, max = tonumber(min), tonumber(max)
      return min, max, (max - min)/2
    end,
    ['VOLENV']   = function()
      local range = reaper.SNM_GetIntConfigVar('volenvrange', 0)
      local maxs = {
        [3]=1,  [1]=1,
        [2]=2,  [0]=2,
        [6]=4,  [4]=4,
        [7]=16, [5]=16,
      }
      return 0, maxs[range] or 2, 1
    end,
    ['PANENV']   = { -1, 1, 0 },
    ['WIDTHENV'] = { -1, 1, 0 },
    ['MUTEENV']  = { 0, 1, 0.5 },
    ['SPEEDENV'] = { 0.1, 4, 1 },
    ['PITCHENV'] = function()
      local range = reaper.SNM_GetIntConfigVar('pitchenvrange', 0) & 0x0F
      return -range, range, 0
    end,
    ['TEMPOENV'] = function()
      local min = reaper.SNM_GetIntConfigVar('tempoenvmin', 0)
      local max = reaper.SNM_GetIntConfigVar('tempoenvmax', 0)
      return min,max, (max + min)/2
    end,
  }
  
  local ok, chunk = reaper.GetEnvelopeStateChunk(env, '', false)
  assert(ok, 'failed to read envelope state chunk')

  local envType = chunk:match('<([^%s]+)')
  for matchType, range in pairs(ranges) do
    if envType:find(matchType) then
      if type(range) == 'function' then
        return range(chunk)
      end
      return table.unpack(range)
    end
  end
  
  error('unknown envelope type')
end

---Higher level function over reaper.Envelope_Evaluate. Return same values but if is an item adjust position for reaper.Envelope_Evaluate. If is at an item and position is out of bounds, return false.
---@param envelope any
---@param position any
function EvaluateEnvelope(envelope, pos, samplerate, samplesRequested)
    local item = reaper.GetEnvelopeInfo_Value( envelope, 'P_ITEM' )
    local is_at_item = item ~= 0 and true or false
    if is_at_item then -- Trim the envelope input to the item length
        local item_pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
        local item_len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
        if pos < item_pos or pos > item_pos+item_len then return false end
        pos = pos - item_pos
    end
    local retval, value, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate(envelope, pos, samplerate, samplesRequested)
    return retval, value, dVdS, ddVdS, dddVdS
end

-----------
--------- Automation Items
-----------
function UnselectAllAutomationItems() -- maybe doing by chunks is easier!
    for track in enumTracks(proj) do
        for env in enumTrackEnvelopes(track) do
            local cnt =  reaper.CountAutomationItems( env )
            for i = 0, cnt-1 do
                reaper.GetSetAutomationItemInfo( env, i, 'D_UISEL', 0, true )
            end
        end
    end
end

---Adds/removes from selection Automation items
---@param env envelope envelope to look into
---@param start_range number beginning of the range (start point are includded in the range)
---@param fim_range number end of the range (end points are not includded in the range)
---@param only_start_in_range boolean only get items that start inside the range (if start at start_range it is includded)
---@param only_end_in_range boolean only get items that end inside the range (if end at the fim_range it is includded)
---@return table ai_items table with the ai idx
function GetAutomationItemsInRange(env, start_range,fim_range,only_start_in_range,only_end_in_range)
    local ai_items = {}
    local cnt = reaper.CountAutomationItems(env)
    for i = 0, cnt-1 do
        local pos = reaper.GetSetAutomationItemInfo(env, i, 'D_POSITION', 0, false)

        if only_start_in_range and pos < start_range then goto continue end -- filter if only_start_in_range 
        if pos >= fim_range then break end -- start after range. break

        local len = reaper.GetSetAutomationItemInfo(env, i, 'D_LENGTH', 0, false)
        local final_pos = len + pos
        if only_end_in_range and final_pos > fim_range then goto continue end -- filter if only_end_in_range

        if final_pos > start_range then
            ai_items[#ai_items+1] = i
        end

        ::continue::
    end
    return ai_items
end

---Adds/removes from selection Automation items
---@param proj project
---@param start_range number beginning of the range (start point are includded in the range)
---@param fim_range number end of the range (end points are not includded in the range)
---@param only_start_in_range boolean only get items that start inside the range (if start at start_range it is includded)
---@param only_end_in_range boolean only get items that end inside the range (if end at the fim_range it is includded)
---@param is_select boolean if true will select if false will unselect
---@param env_list envelope optional if nil will select AI from all tracks. can be a table with envelopes or the envelope itself
function SelectAutomationItemsInRange(proj,start_range,fim_range,only_start_in_range,only_end_in_range, is_select, env_list)
    is_select = (is_select == nil and 1) or (is_select == true and 1) or 0
    if not env_list then 
        env_list = {}
        for track in enumTracks(proj) do
            for envelope_loop in enumTrackEnvelopes(track) do
                table.insert(env_list,envelope_loop)
            end
        end
    end
    if type(env_list) == 'userdata' then 
        env_list = {env_list}
    end

    for k, env_loop in ipairs(env_list) do
        local ai_list = GetAutomationItemsInRange(env_loop, start_range,fim_range,only_start_in_range,only_end_in_range)
        for k, idx in ipairs(ai_list) do
            reaper.GetSetAutomationItemInfo(env_loop, idx, 'D_UISEL', is_select, true)
        end
    end
end

---Adds/removes from selection Automation items
---@param proj project project
---@param start_range number beginning of the range (start point are includded in the range)
---@param fim_range number end of the range (end points are not includded in the range)
---@param only_start_in_range boolean only get items that start inside the range (if start at start_range it is includded)
---@param only_end_in_range boolean only get items that end inside the range (if end at the fim_range it is includded)
---@param env_list envelope optional if nil will delete from all tracks. can be a table with envelopes or the envelope itself
function DeleteAutomationItemsInRange(proj,start_range,fim_range,only_start_in_range,only_end_in_range,env_list)
    if not env_list then 
        env_list = {}
        for track in enumTracks(proj) do
            for envelope_loop in enumTrackEnvelopes(track) do
                table.insert(env_list,envelope_loop)
            end
        end
    end
    if type(env_list) == 'userdata' then 
        env_list = {env_list}
    end
    for k, env_loop in ipairs(env_list) do
        local delete_list = GetAutomationItemsInRange(env_loop, start_range,fim_range,only_start_in_range,only_end_in_range)
        DeleteAutomationItem(env_loop,delete_list)
    end        
end


---Crop Automation Item position keeping elements on the same place
---@param item item
---@param new_start_pos number optional new start position in seconds
---@param new_end_pos number optional new end position in seconds
---@param start number optional original start position in seconds, if not provided function will get it, provide if you already have and save resources 
---@param length number optional original length position in seconds, if not provided function will get it, provide if you already have and save resources 
function CropAutomationItem(env, ai_id, new_start_pos, new_end_pos, start, length)
    start = start or reaper.GetSetAutomationItemInfo(env, ai_id, 'D_POSITION', 0, false)
    length = length or reaper.GetSetAutomationItemInfo(env, ai_id, 'D_LENGTH', 0, false)
    local fim = start + length
    if new_end_pos then
        local dif = new_end_pos - start
        reaper.GetSetAutomationItemInfo(env, ai_id, 'D_LENGTH', length - dif, true)
        length = dif
    end
    if new_start_pos then
        local dif = new_start_pos - start
        local off_set = reaper.GetSetAutomationItemInfo(env, ai_id, 'D_STARTOFFS', 0, false) 
        local playrate = reaper.GetSetAutomationItemInfo(env, ai_id, 'D_PLAYRATE', 0, false)

        reaper.GetSetAutomationItemInfo(env, ai_id, 'D_POSITION', new_start_pos, true)
        reaper.GetSetAutomationItemInfo(env, ai_id, 'D_STARTOFFS', (dif*playrate)+off_set, true)
        reaper.GetSetAutomationItemInfo(env, ai_id, 'D_LENGTH', length-dif, true)
    end    
end

---Copy information values between ai from origem to destino, all info are strings in table string 
---@param env_origem envelope envelope origin
---@param env_destino envelope envelope destin
---@param ai_origem_idx number origem idx autometion item
---@param ai_destino_idx number destiny idx automation item
---@param table_strings table table with the strings value names. ex {'D_PLAYRATE', 'D_BASELINE', 'D_AMPLITUDE', 'D_LOOPSRC'}
function CopyAutomationItemsInfo_Value(env_origem, env_destino, ai_origem_idx,ai_destino_idx,table_strings)
    for index, info_string in ipairs(table_strings) do
        local ai_origem_value =  reaper.GetSetAutomationItemInfo(env_origem, ai_origem_idx, info_string, 0, false )
        reaper.GetSetAutomationItemInfo(env_destino, ai_destino_idx, info_string, ai_origem_value, true )
    end
end

---Delete Autometion item from envelope using ai_idx
---@param env envelope
---@param ai_id number automation item index, or table with indexes
function DeleteAutomationItem(env,ai_idx)
    if type(ai_idx) == 'number' then ai_idx = {ai_idx} end
    local ai_chunk_pattern = 'POOLEDENVINST' 
    local retval, chunk = reaper.GetEnvelopeStateChunk( env, '', false )
    local idx = 0

    for line in chunk:gmatch(ai_chunk_pattern..'.-\n') do
        if TableHaveValue(ai_idx, idx, false) then
            chunk = chunk:gsub(line, '')
        end
        idx = idx + 1
    end
    reaper.SetEnvelopeStateChunk(env, chunk, false)
end

-----------
------ Position
-----------

function GetCurrentPlayPosition(proj)
    local is_play = reaper.GetPlayStateEx(proj)&1 == 1 -- is playing 
    local pos = (is_play and reaper.GetPlayPositionEx( proj )) or reaper.GetCursorPositionEx(proj) -- current pos
    return pos
end