--@noindex
--version: 0.5
-- ADD enum takes and projects


------- Iterate 

function enumSelectedMIDITakes()
    local cnt = reaper.CountSelectedMediaItems(0)
    local i = 0
    return function ()
        while i < cnt do -- (i and Get) are 0 based. cnt is 1 based.
            local item = reaper.GetSelectedMediaItem(0, i) -- get current selected item
            i = i + 1 -- for next time
            local take = reaper.GetActiveTake(item)
            if reaper.TakeIsMIDI(take) then -- make sure, that take is MIDI
                return take -- this break and return
            end
        end
        return nil
    end
end

function enumSelectedItems()
    local cnt = reaper.CountSelectedMediaItems(0)
    local i = 0
    return function ()
        while i < cnt do -- (i and Get) are 0 based. cnt is 1 based.
            local item = reaper.GetSelectedMediaItem(0, i) -- get current selected item
            i = i + 1 -- for next time
            return item
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

function enumProjects()
    local i = -1
    return function ()
        i = i +1
        return reaper.EnumProjects( i )
    end
end


---Iterate fuction returns retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber using EnumProjectMarkers2
---@param proj ReaperProject 
---@return function iterate retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber
function enumMarkers2(proj)
    local i = 0
    local retval, num_markers, num_regions = reaper.CountProjectMarkers(proj)
    local cnt = num_markers + num_regions
    return function ()
        while i < cnt do -- (i and Get) are 0 based. cnt is 1 based.
            local retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers2( proj, i )
            i = i + 1
            if not isrgn then
                return retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber
            end
        end
        return nil
    end
end

----- Tracks
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


------- Items
------ Actions
---Select A list of items or one item. Validate them first
---@param itemlist table List of items to select. {item1, item2, item3} as userdata. Or just the item
function SelectItemList(itemlist)
    reaper.SelectAllMediaItems( 0, false ) -- Deselect all selected items
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

--------- Time / QN

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

