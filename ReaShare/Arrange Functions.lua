-- @noindex

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

function enumSelectedTracks()
    local cnt = reaper.CountSelectedTracks(0)
    local i = -1 
    return function ()
        i = i + 1
        if i >= cnt then return nil end
        return reaper.GetSelectedTrack(0, i)
    end
end

function enumSelectedItems()
    local cnt = reaper.CountSelectedMediaItems(0)
    local i = -1 
    return function ()
        i = i + 1
        if i >= cnt then return nil end
        return reaper.GetSelectedMediaItem(0, i)
    end
end