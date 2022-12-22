--@noindex
function GoTo(reason,proj)
    --[[ is_triggered options:
        ‘next’	
        ‘prev’	
        ‘random’
        ‘pos’..float
        ‘qn’..float
        ‘bar’..Float
        ‘marker’ ..ID
        ‘region’..ID
        '{next,next,prev,bar4.2}'
    ]] -- no spaces. always lower case. 
    local proj_table = ProjConfigs[proj]
    local playlists = proj_table.playlists
    local playlist = playlists[playlists.current]
        
    -- if is a table decide one of them
    if reason:match('{.+}') then -- Todo idea reason with random pick position : {next, next, prev}. User actually just types:  next, next, prev ; then add in the code the {} and fix the syntax 
        local possible_reasons = {}
        local str = reason:sub(2,-2)..',' -- remove the brackets
        for reason in str:gmatch('(.-),') do
            table.insert(possible_reasons, reason)
        end
        reason = possible_reasons[math.random(#possible_reasons)]
    end
    -- TODO calculate for each possible

    local function next_prev(is_next)  -- Next and Prev logic
        if not playlist or #playlist == 0 then return false end -- Check if any marker/region/playlist
        if not TableCheckValues(playlist, 'current') then playlist.current = 0 end -- safe check if playlists have current value

        -- updates the value at the ProjConfigs table
        local change = ((is_next and 0) or -2) -- if goes prev then -1 if goes next then 0
        playlist.current = ((playlist.current+change) % #playlist) + 1
        if playlist.shuffle and ((is_next and playlist.current == 1) or (not is_next and playlist.current == #playlist)) then --shuffle the table every time it loops around
            RandomizeTable(playlist)
            --todo randomize values
        end
        
        local region = playlist[playlist.current]
        local guid = region.guid -- region guid
        local retval, marker_id = reaper.GetSetProjectInfo_String( proj, 'MARKER_INDEX_FROM_GUID:'..guid, '', false )
        if marker_id == '' then goto continue end -- better safe than sorry
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers2( proj, marker_id ) 
        local new_pos = pos
        
        -- set loop 
        if region.loop then
            local start, fim = reaper.GetSet_LoopTimeRange2(proj, true, true, new_pos, rgnend, false) -- proj, isSet, isLoop, start, end, allowautoseek
        elseif region.type == 'region' then -- not looping a region will remove loop regions (maybe only if the loop region is in the region position/range)
            local start, fim = reaper.GetSet_LoopTimeRange2(proj, true, true, 0, 0, false) -- proj, isSet, isLoop, start, end, allowautoseek
        end
        -- set play cursor 
        reaper.SetEditCurPos2(proj, new_pos, proj_table.moveview, true)
        ::continue::
    end

    local function go_to_playlist_val(playlist_val)
        if not playlist or #playlist == 0 then return false end -- Check if any marker/region/playlist

        playlist.current = playlist_val
        
        local region = playlist[playlist.current]
        local guid = region.guid -- region guid
        local retval, marker_id = reaper.GetSetProjectInfo_String( proj, 'MARKER_INDEX_FROM_GUID:'..guid, '', false )
        if marker_id == '' then goto continue end -- better safe than sorry
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers2( proj, marker_id ) 
        local new_pos = pos
        
        -- set loop 
        if region.loop then
            local start, fim = reaper.GetSet_LoopTimeRange2(proj, true, true, new_pos, rgnend, false) -- proj, isSet, isLoop, start, end, allowautoseek
        elseif region.type == 'region' then -- not looping a region will remove loop regions (maybe only if the loop region is in the region position/range)
            local start, fim = reaper.GetSet_LoopTimeRange2(proj, true, true, 0, 0, false) -- proj, isSet, isLoop, start, end, allowautoseek
        end
        -- set play cursor 
        reaper.SetEditCurPos2(proj, new_pos, proj_table.moveview, true)
        ::continue::
    end

    if reason == 'next' then 
        next_prev(true)          
    elseif reason == 'prev' then
        next_prev(false)
    elseif reason == 'random' then
    -- TODO other possible reasons 
    elseif reason:match('^goto') then
        local playlist_val = tonumber(reason:match('^goto'..'(.+)'))
        go_to_playlist_val(playlist_val)
    end
    proj_table.is_triggered = false
end

---Create/Cancel Goto triggers for project
function SetGoTo(project, val)
    ProjConfigs[project].is_triggered = val
end

-------------
--- Playlists Table 
-------------

function CreateNewPlaylist(name)
    local default_table = {name = name,
                           shuffle = false, -- saves used idxes (for shuffle mode)
                           reset = true, -- at stop reset playlist current position to 0
                           current = 0, -- 0 means not in any region of this playlist, reset to 0 each stop?
                        } 
    return default_table
end

function CreateNewRegion(id, proj)
    local retval, guid = reaper.GetSetProjectInfo_String( proj, 'MARKER_GUID:'..id, '', false )
    if guid == '' then return false end
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers2( proj, id )
    local region_table = {
            guid = guid,
            loop = isrgn,
            type = isrgn and 'region' or 'marker',
            chance = 1,
            current = 0           
    }
    return region_table    
end

function CreateProjectConfigTable(proj)
    local is_play = reaper.GetPlayStateEx(proj)&1 == 1
    local t = {
        playlists = {CreateNewPlaylist('P1'),
                     current = 1},
        identifier = '#goto', -- markers identifier to trigger GoTo actions
        oldpos = (is_play and reaper.GetPlayPositionEx( proj )) or reaper.GetCursorPositionEx(proj), 
        oldtime = reaper.time_precise(),
        oldisplay = is_play,
        is_triggered = false, -- if triggered to goto a position or next prev markers reg
        stop_trigger = true, --at stop cancel triggers
        moveview = true, -- moveview at GoTo 
        grid = {
            is_grid = false, -- use grid to trigger
            unit = 'bar', -- unit to trigger, can be 'bar' or a number like 1 for whole note 1/4 for quarter note etc... 
            unit_str = 'bar', -- to show at the GUI.
        },
        is_marker = true -- use markers to trigger
    }   
    return t
    
end
