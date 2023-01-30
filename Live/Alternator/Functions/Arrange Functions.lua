--@noindex
--version: 0.13.1
-- update enum markers bugfix
-- fix arrange position


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
    reaper.SelectAllMediaItems( proj, false ) -- Deselect all selected items
    if type(itemlist) == 'userdata' then itemlist = {itemlist} end
    for i, item in ipairs(itemlist) do
        if reaper.ValidatePtr2(0, item, 'MediaItem*') then
            reaper.SetMediaItemSelected(item, true)
        end
    end
end

---Create a table with the selected items
---@return table selected_items
function CreateSelectedItemsTable()
    local t = {}
    for item in enumSelectedItems() do
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
    local  retval, item_pos = reaper.GetSetMediaItemInfo_String( item, 'P_EXT:'..extname..': '..key, value, true )
    return retval
end

---Return the item ext state value
---@param item MediaItem
---@param extname string name of the ext state section
---@param key string name of the key inside the extname section
---@return boolean retval
---@return string value
function GetItemExtState(item, extname, key)
    local retval, saved_original_pos = reaper.GetSetMediaItemInfo_String( item, 'P_EXT:'..extname..': '..key, '', false )
    return retval, saved_original_pos
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
------ Position
-----------

function GetCurrentPlayPosition(proj)
    local is_play = reaper.GetPlayStateEx(proj)&1 == 1 -- is playing 
    local pos = (is_play and reaper.GetPlayPositionEx( proj )) or reaper.GetCursorPositionEx(proj) -- current pos
    return pos
end