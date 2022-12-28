--@noindex
---Create/Cancel Goto triggers for project
function SetGoTo(project, val)
    ProjConfigs[project].is_triggered = val
end

-------------
--- Table 
-------------
function AddSelectedTracksToTargets(proj, targets)
    for track in enumSelectedTracks(proj) do
        targets[track] = CreateTargetTable(track)
    end
end

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
        slopedown = 0
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
        bypass = false
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