--@noindex
---Create/Cancel Goto triggers for project
-------------
--- FX 
-------------

---Check track if it haves the Volume fx. 
---@param track MediaTrack
---@param add boolean if not find then add it to the end of the fx chain.
---@return number fx_idx return the fx_idx. -1 if not found. 0 Based
function CheckLayerFX(track, add)
    local bol = false
    local add_fx = add and 1 or 0 -- 1 will add if not found, 0 will only query. 
    local fx_idx = reaper.TrackFX_AddByName( track, FXNAME, false, add_fx) 
    return fx_idx
end

function CheckFxPos(track, target)
    local fx_idx = CheckLayerFX(track, true) -- If there is not an FX then add it at the end
    if target.is_force_fx then
        local fx_cnt =  reaper.TrackFX_GetCount( track )

        -- Check if Fx already is at requested position
        local is_at_position, dest_idx
        if target.force_fx_pos <= 0 then
            is_at_position = target.force_fx_pos == fx_idx - (fx_cnt-1)
            dest_idx =  (fx_cnt-1) + target.force_fx_pos
        elseif target.is_force_fx > 0 then
            is_at_position = target.force_fx_pos == fx_idx+1
            dest_idx = target.force_fx_pos - 1
        end

        if not is_at_position then
            print('change pos')
            reaper.TrackFX_CopyToTrack( track, fx_idx, track, dest_idx, true )
        end
    end
end



-------------
--- Table 
-------------

-- Actions : 

function AddSelectedTracksToTargets(proj, targets)
    for track in enumSelectedTracks(proj) do
        local target_table = CheckTargetsForTrack(proj,track)
        targets[track] = target_table or CreateTargetTable(track)
        -- FX
        CheckLayerFX(track, true)
    end
end

-- check if track was already added in another parameter if it was bring the table to this parameter and remove from the other
function CheckTargetsForTrack(proj,track)
    for parameter_index, parameter in ipairs(ProjConfigs[proj].parameters) do
        for target_track, target in pairs(parameter.targets) do
            if target_track == track then
                parameter.targets[target_track] = nil
                return target
            end
        end
    end
    return false
end

function RemoveTarget(parameter, track)
    local fx_idx = CheckLayerFX(track, false)
    if fx_idx ~= -1 then
        reaper.TrackFX_Delete(track, fx_idx)
    end
    parameter.targets[track] = nil
end

-- Create Tables: 

function CreatePointTable()
    return {ce_point(0,0), ce_point(1,1)}
end

function CreateTargetTable(track)
    local t = {
        curve = CreatePointTable(), ---- TODO start with a linear value
        bypass = false,
        track = track,
        value = 1,
        slopeup = 0,
        slopedown = 0,
        force_fx_pos = 0,
        is_force_fx = true
    }
    return t
end

function CreateParameterTable(name)
    local t = {
        targets = {},
        envelope = false,
        slopeup = 0, -- values from 0 to 1. 0 It wont move.
        slopedown = 0, -- values from 0 to 1. 0 It wont move.
        name = name,
        midi = CreateCleanMIDITable(),
        bypass = false,
        value = 1,
        true_value = 1 -- after the slope
    }
    return t
end

function CreateProjectConfigTable()
    local t = {
        parameters = {CreateParameterTable('P1')},
        bypass = false,
        remove_fx_atexit = true
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

function AddGotoMarker()
    local is_play = reaper.GetPlayStateEx(FocusedProj)&1 == 1 -- is playing 
    local pos = (is_play and reaper.GetPlayPositionEx( FocusedProj )) or reaper.GetCursorPositionEx(FocusedProj) -- current pos
    reaper.AddProjectMarker2(FocusedProj, false, pos, 0, ProjConfigs[FocusedProj].identifier, -1, 0)
end

function DeleteGotoMarkersAtTimeSelection()
    local start, fim = reaper.GetSet_LoopTimeRange2( FocusedProj, false, false, 0, 0, false )
    local retval, num_markers, num_regions = reaper.CountProjectMarkers(FocusedProj)
    local cnt = num_markers + num_regions
    for i = cnt-1 , 0, -1 do
        local retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers2( FocusedProj, i )
        if not isrgn and mark_pos >= start and mark_pos <= fim and name == ProjConfigs[FocusedProj].identifier then -- filter
            reaper.DeleteProjectMarker( FocusedProj, markrgnindexnumber, false )
        end
    end
end