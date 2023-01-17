--@noindex
function GoTo(reason,proj)
    --[[ is_triggered options:
        ‘next’	
        ‘prev’	
        ‘random’
        'random_with_rep'
        'goto'..playlist region idx
        ‘pos’..float
        ‘qn’..float
        ‘bar’..Float
        ‘mark’ ..ID
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
        for reason in str:gmatch('%s*(.-)%s-,%s*') do
            if ValidateCommand(reason) then
                table.insert(possible_reasons, reason)
            end
        end
        reason = possible_reasons[math.random(#possible_reasons)]
    end

    local function change_play_to_current()
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

    ---@param same boolean can trigger the current again?
    local function goto_random(same)
        if not playlist or #playlist == 0 then return false end -- Check if any marker/region/playlist
        if not TableCheckValues(playlist, 'current') then playlist.current = 0 end -- safe check if playlists have current value,

        local chance_sum = 0
        for idx, region_table in ipairs(playlist) do
            if not same and idx == playlist.current then goto continue end -- dont add if is the same region
            chance_sum = chance_sum + region_table.chance  
            ::continue::          
        end
        
        if chance_sum > 0 then
            local rnd_val = math.random(chance_sum)

            local count = 0
            for idx, region_table in ipairs(playlist) do
                if not same and idx == playlist.current then goto continue end -- dont add if is the same region
                count = count + region_table.chance
                if count >= rnd_val then
                    playlist.current = idx
                    break
                end
                ::continue::          
            end
        else
            playlist.current = 1
        end

        change_play_to_current()
    end

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
        change_play_to_current()
    end

    local function go_to_playlist_val(playlist_val)
        if not playlist or #playlist == 0 then return false end -- Check if any marker/region/playlist

        playlist.current = playlist_val
        change_play_to_current()
    end

    local function goto_mark_or_region(user_id, is_region)
        if user_id then
            local mode = (is_region and 2) or 1
            local retval, isrgn, mark_pos, rgnend, mark_name, markrgnindexnumber, color, idx = GetMarkByID(proj,user_id,mode)
            if retval then
                reaper.SetEditCurPos2(proj, mark_pos, proj_table.moveview, true)
            end
        end
    end

    if reason == 'next' then  -- next on the playlist
        next_prev(true)          
    elseif reason == 'prev' then -- prev on the playlist
        next_prev(false)
    elseif reason == 'random' then -- random on the playlist (cant be the current region again)
        goto_random(false)
    elseif reason == 'random_with_rep' then -- random on the playlist
        goto_random(true)
    elseif reason:match('^goto') then
        local playlist_val = tonumber(reason:match('^goto'..'(.+)'))
        playlist_val = LimitNumber(playlist_val, (#playlist == 0 and 0 or 1) ,#playlist)
        go_to_playlist_val(playlist_val)
    elseif reason:match('^pos') then
        local new_pos = tonumber(reason:match('pos%s-(%d+%.?%d*)'))
        if new_pos then
            reaper.SetEditCurPos2(proj, new_pos, proj_table.moveview, true)
        end
    elseif reason:match('^qn') then
        local new_pos_qn = tonumber(reason:match('qn%s-(%d+%.?%d*)'))
        if new_pos_qn then
            local new_pos = reaper.TimeMap2_QNToTime(proj, new_pos_qn)
            reaper.SetEditCurPos2(proj, new_pos, proj_table.moveview, true)
        end
    elseif reason:match('^bar') then
        local measure = tonumber(reason:match('bar%s-(%d+%.?%d*)'))
        if measure then
            local retval, qn_start, qn_end, timesig_num, timesig_denom, tempo = reaper.TimeMap_GetMeasureInfo(proj, measure)
            local new_pos = reaper.TimeMap2_QNToTime(proj, qn_start)
            reaper.SetEditCurPos2(proj, new_pos, proj_table.moveview, true)
        end
    elseif reason:match('^mark') then
        local user_id = tonumber(reason:match('mark%s-(%d+%.?%d*)'))
        goto_mark_or_region(user_id, false)

    elseif reason:match('^region') then
        local user_id = tonumber(reason:match('region%s-(%d+%.?%d*)'))
        goto_mark_or_region(user_id, true)
    end
    proj_table.is_triggered = false
end

function GetCommand(identifier,marker_name )
    local goto_command = marker_name:match(identifier..'%s+(.+)')
    if not goto_command then return false end
    if ValidateCommand(goto_command) then
        return goto_command
    end
end

function ValidateCommand(goto_command)
    local possible_commands = { 'next',
                                'prev',	
                                'random',
                                'random_with_rep',
                                'goto',
                                'pos',
                                'qn',
                                'bar',
                                'mark',
                                'region'}
    -- check if command makes sense
    for k,possibility in ipairs(possible_commands) do
        if goto_command:match('^{?%s*'..possibility) then -- does it have any of possible names (optionally it start with a table { with as many spaces as needed)
            return true
        end
    end
    return false
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
                           reset = false, -- at stop reset playlist current position to reset_n
                           reset_n = 1, -- reset playlist number
                           reset_playhead = false, -- move the playhead when reseting
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
            current = 0,
            midi = CreateCleanMIDITable() -- to trigger the region via MIDI          
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
        is_marker = true, -- use markers to trigger
        buttons = {
            next = {
                midi = CreateCleanMIDITable()
            },
            prev = {
                midi = CreateCleanMIDITable()
            },
            random = {
                midi = CreateCleanMIDITable()
            },
            cancel = {
                midi = CreateCleanMIDITable()
            }
        },
        is_force_goto = false, -- when true it will look for markers with the force indentifier and them will trigger goto commands
        force_identifier = '#force', -- force identifier
    }   
    return t
end

function CreateCleanMIDITable()
    return {
        is_learn = false
    }
end


-------------
--- Utility Marks 
-------------

function AddGotoMarker(is_force)
    local action_name = is_force and 'Add Force Goto Marker' or 'Add Goto Marker'
    reaper.Undo_BeginBlock2(FocusedProj)

    local is_play = reaper.GetPlayStateEx(FocusedProj)&1 == 1 -- is playing 
    local pos = (is_play and reaper.GetPlayPositionEx( FocusedProj )) or reaper.GetCursorPositionEx(FocusedProj) -- current pos
    local marker_name = is_force and ProjConfigs[FocusedProj].force_identifier or ProjConfigs[FocusedProj].identifier
    reaper.AddProjectMarker2(FocusedProj, false, pos, 0, marker_name, -1, 0)

    reaper.Undo_EndBlock2(FocusedProj, action_name, -1)
end

function DeleteGotoMarkersAtTimeSelection(delete_force)
    local action_name = delete_force and 'Delete Force Goto Marker at Time Selection' or 'Delete Goto Marker at Time Selection'
    reaper.Undo_BeginBlock2(FocusedProj)

    local start, fim = reaper.GetSet_LoopTimeRange2( FocusedProj, false, false, 0, 0, false )
    local retval, num_markers, num_regions = reaper.CountProjectMarkers(FocusedProj)
    local cnt = num_markers + num_regions
    for i = cnt-1 , 0, -1 do
        local retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers2( FocusedProj, i )
        if not isrgn and mark_pos >= start and mark_pos <= fim and (name:match('^'..ProjConfigs[FocusedProj].identifier) or (delete_force and name:match('^'..ProjConfigs[FocusedProj].force_identifier))) then -- filter
            reaper.DeleteProjectMarker( FocusedProj, markrgnindexnumber, false )
        end
    end

    reaper.Undo_EndBlock2(FocusedProj, action_name, -1)
end

function RenameMarkers(proj, old_marker_id,new_marker_id)
    reaper.Undo_BeginBlock2(FocusedProj)

    for retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber, i in enumMarkers2(proj, 1) do
        if name:match('^'..old_marker_id) then
            name = name:gsub('^'..(old_marker_id)..'.?', new_marker_id)
            print(name)
            reaper.SetProjectMarker(markrgnindexnumber, isrgn, mark_pos, rgnend, name)
        end
    end

    reaper.Undo_EndBlock2(FocusedProj, 'Rename Markers', -1)
end