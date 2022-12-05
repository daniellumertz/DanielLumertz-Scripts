--@noindex
function GoTo(reason,proj)
    print('GoTo')
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
        local playlists = proj_table.playlists
        local playlist = playlists[playlists.current]
        -- updates the value at the ProjConfigs table
        local change = ((not is_next and -1) or 0) -- if goes prev then -1 if goes next then 0
        playlist.current = ((playlist.current+change) % #playlist) + 1
        if playlist.shuffle and (is_next and playlist.current == 1) or (not is_next and playlist.current == #playlist) then --shuffle the table every time it loops around
            --todo randomize values
        end
        
        local region = playlist[playlist.current]
        local guid = region.guid -- region guid
        local retval, marker_id = reaper.GetSetProjectInfo_String( proj, 'MARKER_INDEX_FROM_GUID:'..guid, '', false )
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers2( proj, marker_id )
        local new_pos = pos
        
        -- set loop 
        if region.loop then
            local start, fim = reaper.GetSet_LoopTimeRange2(proj, true, true, new_pos, rgnend, false) -- proj, isSet, isLoop, start, end, allowautoseek
        end
        -- set play cursor 
        reaper.SetEditCurPos2(proj, new_pos, proj_table.moveview, true)
    end

    if reason == 'next' then 
        next_prev(true)          
    elseif reason == 'prev' then
        next_prev(false)
    elseif reason == 'random' then
    -- TODO other possible reasons 
    end
    proj_table.is_triggered = false
end
