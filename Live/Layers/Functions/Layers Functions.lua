--@noindex
---Create/Cancel Goto triggers for project
-------------
--- FX 
-------------

---Check track if it haves the Volume fx. Also use to ADD the FX.
---@param track MediaTrack
---@param add boolean if not find then add it to the end of the fx chain.
---@return number fx_idx return the fx_idx. -1 if not found. 0 Based
function CheckLayerFX(track, add)
    local bol = false
    local add_fx = add and 1 or 0 -- 1 will add if not found, 0 will only query. 
    local fx_idx = reaper.TrackFX_AddByName( track, FXNAME, false, add_fx) 
    return fx_idx
end

function CheckFxPos(track, target, proj)
    local fx_idx = CheckLayerFX(track, true) -- If there is not an FX then add it at the end
    -- Check if anymore Layer fx added after this
    do
        local fx_cnt = reaper.TrackFX_GetCount( track )
        for fx = fx_cnt-1, fx_idx+1, - 1 do
            local retval, buf = reaper.TrackFX_GetFXName( track, fx )
            local prefix = 'JS: '
            if buf == prefix..FXNAME then
                reaper.TrackFX_Delete( track, fx )
            end
        end
    end
    -- Position
    if target.is_force_fx then
        local fx_cnt =  reaper.TrackFX_GetCount( track )

        -- Check if Fx already is at requested position
        local is_at_position, dest_idx
        if target.force_fx_pos <= 0 then
            is_at_position = target.force_fx_pos == fx_idx - (fx_cnt-1)
            dest_idx =  (fx_cnt-1) + target.force_fx_pos
        elseif target.force_fx_pos > 0 then
            is_at_position = target.force_fx_pos == fx_idx+1
            dest_idx = target.force_fx_pos - 1
        end

        if not is_at_position then
            reaper.TrackFX_CopyToTrack( track, fx_idx, track, dest_idx, true )
        end
    end

    if target.is_force_fx_settings then
        local fx_idx = CheckLayerFX(track, false)
        -- MIDI Chase
        local param = 1
        local forced_val = target.is_fx_midi_chase and 1 or 0 
        local midi_chase, minval, maxval = reaper.TrackFX_GetParam(track, fx_idx, param)
        if midi_chase ~= forced_val then
            reaper.TrackFX_SetParamNormalized(track, fx_idx, param, forced_val)
        end
        -- MIDI Chase Once
        local param = 2
        local forced_val = target.is_fx_chase_only_once and 1 or 0 
        local midi_chase, minval, maxval = reaper.TrackFX_GetParam(track, fx_idx, param)
        if midi_chase ~= forced_val then
            reaper.TrackFX_SetParamNormalized(track, fx_idx, param, forced_val)
        end
        -- MIDI Scale
        local param = 3
        local forced_val = target.is_fx_midi_scale and 1 or 0 
        local midi_chase, minval, maxval = reaper.TrackFX_GetParam(track, fx_idx, param)
        if midi_chase ~= forced_val then
            reaper.TrackFX_SetParamNormalized(track, fx_idx, param, forced_val)
        end   
    end
    -- Bypass
    Bypass(track, fx_idx, target, proj)
end

function RemoveLayerFXFromTrack(track)
    local fx_idx = CheckLayerFX(track, false)
    if fx_idx ~= -1 then
        reaper.TrackFX_Delete(track, fx_idx)
    end    
end

function Bypass(track, fx_idx, target, proj)
    local is_bypassed_current = not reaper.TrackFX_GetEnabled( track, fx_idx ) -- current value
    local is_bypass =  target.bypass or ProjConfigs[proj].bypass -- expected value

    if is_bypassed_current ~= is_bypass  then
        reaper.TrackFX_SetEnabled( track, fx_idx, not is_bypass)
    end
end

function UpdateLayerFXValue(target, track)
    local fx_idx = CheckLayerFX(track, false)
    local fx_value = ce_evaluate_curve(target.curve,target.value)
    reaper.TrackFX_SetParamNormalized(track, fx_idx, 0, fx_value)
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
    RemoveLayerFXFromTrack(track)
    parameter.targets[track] = nil
end

function RemoveGroup(proj, parameter_key)
    local parameter_table = ProjConfigs[proj].parameters[parameter_key]
    for track, target_table in pairs(parameter_table.targets) do
        RemoveTarget(parameter_table, track)
    end
    table.remove(ProjConfigs[proj].parameters,parameter_key)
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
        is_force_fx = true,
        is_force_fx_settings = true,
        is_fx_midi_chase = true,
        is_fx_chase_only_once = false,
        is_fx_midi_scale = false,
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
        remove_fx_atexit = false
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

function AtExit()
    for proj, proj_table in pairs(ProjConfigs) do
        if proj_table.remove_fx_atexit then
            for parameter_idx, parameter in ipairs(proj_table.parameters) do
                for track, target in pairs(parameter.targets) do
                    RemoveLayerFXFromTrack(track)
                end  
            end
        end
    end
    Save() --Remember, when atexit function is triggered reaper already closed the projects. So this wont save in the extstates, the script saves as user change things!
end