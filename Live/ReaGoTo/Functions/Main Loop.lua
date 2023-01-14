--@noindex
function main_loop()
    ----------- Pre GUI area
    CheckProjects()
    CheckSmoothSeek()
    MIDIInput = GetMIDIInput() -- Global variable with the MIDI from current loop

    PushTheme()
    --demo.PushStyle(ctx)
    --demo.ShowDemoWindow(ctx)

    if not reaper.ImGui_IsAnyItemActive(ctx) and not TableHaveAnything(PreventKeys) then 
        PassKeys()
    end


    ------------ Window management area
    --- Flags
    local window_flags = reaper.ImGui_WindowFlags_MenuBar() 
    if GuiSettings.Pin then 
        window_flags = window_flags | reaper.ImGui_WindowFlags_TopMost()
    end 
    -- Set window configs Size Dock Font
    reaper.ImGui_SetNextWindowSize(ctx, Gui_W_init, Gui_H_init, reaper.ImGui_Cond_Once())-- Set the size of the windows at start.  Use in the 4th argument reaper.ImGui_Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2
    if SetDock then 
        reaper.ImGui_SetNextWindowDockID(ctx, SetDock)
        if SetDock== 0 then
            reaper.ImGui_SetNextWindowSize(ctx, Gui_W_init, Gui_H_init)
        end
        SetDock = nil
    end
    reaper.ImGui_PushFont(ctx, FontText) -- Says you want to start using a specific font
    local visible, open  = reaper.ImGui_Begin(ctx, ScriptName..' '..Version, true, window_flags)
    -- Updates the variables used in the script
    Gui_W, Gui_H = reaper.ImGui_GetWindowSize(ctx)
    if visible then
        AnimationValues()
        MenuBar()
        local _ --  values I will throw away
        --- GUI MAIN: 
        PlaylistSelector(ProjConfigs[FocusedProj].playlists)
        -- Trigger Buttons
        TriggerButtons(ProjConfigs[FocusedProj].playlists)
        reaper.ImGui_End(ctx)
    end 
    
    reaper.ImGui_PopFont(ctx) -- Pop Font
    PopTheme()
    --demo.PopStyle(ctx)
    GoToCheck()  -- Check if need change playpos (need to be after the user input). If ProjConfigs[proj].is_trigerred then change the playpos at last moment possible.

    if open then
        reaper.defer(main_loop)
    else
        reaper.ImGui_DestroyContext(ctx)
    end
end

--- Check for each project if need to trigger goto
function GoToCheck()
    local proj_t = (UserConfigs.only_focus_project and {ProjConfigs[FocusedProj]}) or ProjConfigs -- if only_focus_project will be a table with the focused project only else will do for all open projectes
    for proj, project_table in pairs(proj_t) do
        -- Get play pos/state
        local is_play = reaper.GetPlayStateEx(proj)&1 == 1 -- is playing 
        local pos = (is_play and reaper.GetPlayPositionEx( proj )) or reaper.GetCursorPositionEx(proj) -- current pos
        local time = reaper.time_precise()

        -- if stoped
        if project_table.oldisplay and not is_play then
            if project_table.stop_trigger then -- Cancel triggers
                project_table.is_triggered = false
            end
            -- Reset playlist position for each playlist
            for playlist_idx,playlist in ipairs(project_table.playlists) do
                if playlist.reset then
                    playlist.current = 1
                end
            end
        end


        if not project_table.is_triggered then goto continue end

    
        -- if playing and is_triggered then search the next Trigger point 
        if is_play and project_table.is_triggered then

            local trigger_point 
            local marker_name
            local marker_point
            local is_repeat =  reaper.GetSetRepeat( -1 ) == 1 -- query = -1 
            local next_marker_pos, loop_marker_pos, loop_start, loop_end -- position of the next #goto marker , positon of the next marker after loop region begin , loop position , loop end position  
            local marker_distance -- saves the distance to trigger using markers (to compare with grids)
            if is_repeat then
                loop_start, loop_end = reaper.GetSet_LoopTimeRange2(proj, false, true, 0, 0, false)
                is_repeat = loop_start ~= loop_end-- Does it have an area selected? does it have repeat on ? 
            end
            -------------------------- Markers
            if project_table.is_marker then
                local next_marker_name, loop_marker_name 
                -- Loop markers
                for retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber in enumMarkers2(proj, 1) do 
                    -- Get the next marker
                    if mark_pos > pos and name:match('^'..project_table.identifier) then -- Loop each marker (improve with a binary search later)
                        next_marker_pos = mark_pos  
                        next_marker_name = name
                        break -- if have the next marker then it already had the opportunity of having the loop repeat 
                    end
                    -- If loop/repeat is ON then get the closest goto marker from the loop start
                    if is_repeat and not loop_marker_pos and mark_pos >= loop_start and name:match('^'..project_table.identifier) then 
                        loop_marker_pos = mark_pos
                        loop_marker_name = name
                    end
                end 

                -- Get closest marker
                local loop_distance, next_distance
                if loop_marker_pos then 
                    loop_distance = (loop_end - pos) + (loop_marker_pos - loop_start)
                end
                if next_marker_pos then
                    next_distance = next_marker_pos - pos 
                end
                if (next_marker_pos and not loop_marker_pos) or (not next_marker_pos and loop_marker_pos) then -- only have one marker
                    marker_point = next_marker_pos  or loop_marker_pos
                    marker_distance = loop_distance or next_distance
                    marker_name = next_marker_name  or loop_marker_name 
                elseif next_marker_pos and loop_marker_pos then -- Compare markers position (closest from loop start vs next position marker)
                    marker_point =    (next_distance < loop_distance and next_marker_pos)   or loop_marker_pos
                    marker_distance = (next_distance < loop_distance and next_distance )    or loop_distance
                    marker_name =     (next_distance < loop_distance and next_marker_name ) or loop_marker_name 
                end
            end
            ------------------------ Unit
            -- check if passed by any unit and increase the counter
            local unit_point -- position to trigger 
            local unit_distance -- distance until trigger

            if project_table.grid.is_grid then
                local pos_qn = reaper.TimeMap2_timeToQN( proj, pos )
                local retval, qnMeasureStart, qnMeasureEnd = reaper.TimeMap_QNToMeasures( proj, pos_qn )
                if project_table.grid.unit == 'bar' then             
                    unit_point = reaper.TimeMap_QNToTime( qnMeasureEnd )
                else
                    local unit_in_qn = project_table.grid.unit * 4 
                    local measure_pos_qn = pos_qn - qnMeasureStart -- qn over that measure
                    local next_qn = QuantizeUpwards(measure_pos_qn, unit_in_qn) + qnMeasureStart
                    unit_point = reaper.TimeMap_QNToTime( next_qn )                    
                end
                unit_distance = unit_point - pos
            end

            ---------------------- Compare marker and unit get closest
            if marker_point and unit_point then
                trigger_point = marker_distance < unit_distance and marker_point or unit_point
            else 
                trigger_point = marker_point or unit_point
            end


            --local retval, division, swingmode, swingamt = reaper.GetSetProjectGrid( proj, false, 0, 0, 0 )

            ------- Change Player position if needed (Try to change as close to the marker as possible)
            if trigger_point then -- only if there is something to trigger to comapre to
                -- If markers get triggers overides
                local delta =  time - project_table.oldtime -- for defer instability estimation
                -- Estimate next defer cycle position, check if is after the loop end. Always estimate a little longer to compensate for defer instability. This can cause to trigger twice. Use a variable that reset each loop start to prevent that.
                local playrate = reaper.Master_GetPlayRate(proj)
                local is_trigger_before = (trigger_point < pos) -- Trigger point is at the start of a loop.
                local defer_in_proj_sec = (delta * UserConfigs.compensate) * playrate -- how much project sec each defer loop runs. avarage.

                local is_trigger -- should it trigger the GoTo function?
                if not SmoothSettings.is_smoothseek then
                    local distance = defer_in_proj_sec -- distance the trigger needs to be from the current position/loop start to trigger.

                    if not is_trigger_before then
                        is_trigger = (pos + distance >= trigger_point) -- calculate based on triggering point after current position
                    else
                        is_trigger = (loop_start + (distance - (loop_end - pos))) >= trigger_point  -- calculate based on triggering point before current position and after loop start
                    end
                else
                    local max_distance = SmoothSettings.min_time + defer_in_proj_sec -- minimum distance to trigger 
                    local min_distance = SmoothSettings.min_time  -- minimum distance to trigger (there is a bug in reaper and smooth seek, if change the position before 200-250ms before the bar/marker it wont trigger, and can even break a loop)
                    
                    if not is_trigger_before then
                        is_trigger = (pos + max_distance >= trigger_point) and (pos + min_distance < trigger_point) -- calculate based on triggering point after current position
                    else
                        --is_trigger = ((loop_start + (max_distance - (loop_end - pos))) >= trigger_point) and (((trigger_point - loop_start) + (loop_end-pos)) > min_distance)  -- because smooth seek trigger at regions ends and it needs to be 250ms triggered before it makes markers (250ms after the loop start) impossible. trying to trigger them will break the REAPER loop, another bug, best to remove this than break options. 
                    end
                end

                if is_trigger then
                    -- check for trigger overies 
                    if marker_name then
                        local goto_command = marker_name:match(project_table.identifier..'%s+(.+)')
                        if not goto_command then goto continue end
                        if ValidateCommand(goto_command) then
                            project_table.is_triggered = goto_command
                        end
                        ::continue:: 
                    end
                    ---- Goto ! 
                    GoTo(project_table.is_triggered,proj)
                    ---- Add Markers at the trigger position for debugging mostly
                    if UserConfigs.add_markers then
                        reaper.AddProjectMarker(proj, false, pos, 0, '', 0) -- debug when it is happening
                    end
                end
            end
        elseif UserConfigs.trigger_when_paused and not is_play and project_table.is_triggered then -- receive goto orders when paused
            GoTo(project_table.is_triggered,proj)
        end


        ::continue::
        -- Update values
        project_table.oldtime = time
        project_table.oldpos = pos
        project_table.oldisplay = is_play
    end

end

function CheckProjects()
    local projects_opened = {} -- to check if some project closed
    -- Check if some project opened
    for check_proj in enumProjects() do
        local check = false
        for proj, project_table in pairs(ProjConfigs) do
            if proj == check_proj then -- project already have a configs 
                check = true
                break
            end             
        end 
        local project_path = GetFullProjectPath(check_proj)
        if not check or ProjPaths[check_proj] ~= project_path then -- new project detected // project without cofigs (new tab or user opened a project)
            LoadProjectSettings(check_proj)
            ProjPaths[check_proj] = project_path
        end
        table.insert(projects_opened, check_proj)
    end

    -- Check if some project closed
    for proj, proj_table in pairs(ProjConfigs) do
        if not TableHaveValue(projects_opened,proj) then
            ProjConfigs[proj] = nil-- if closed remove from ProjConfigs. configs should be saved as user uses
            ProjPaths[proj] = nil
        end
    end



    for check_proj in enumProjects() do
        --- Check if all regions are available 
        for playlist_key, playlist in ipairs(ProjConfigs[check_proj].playlists) do
            for rgn_k, region_table in ipairs_reverse(playlist) do   
                local retval, marker_id = reaper.GetSetProjectInfo_String( check_proj, 'MARKER_INDEX_FROM_GUID:'..region_table.guid, '', false )
                if marker_id == '' then 
                    table.remove(playlist,rgn_k)
                end
            end
        end
        -- if smooth seek then force reagoto proj_settings to match smooth seek (to be on the grid/marker)
        if SmoothSettings.is_smoothseek then
            if SmoothSettings.is_bar then
                if not ProjConfigs[check_proj].grid.is_grid then
                    ProjConfigs[check_proj].grid.is_grid = true
                end

                if ProjConfigs[check_proj].grid.unit ~= 'bar' then
                    ProjConfigs[check_proj].grid.unit = 'bar'
                end

                if ProjConfigs[check_proj].is_marker then
                    ProjConfigs[check_proj].is_marker = false
                end
            else
                if not ProjConfigs[check_proj].is_marker then
                    ProjConfigs[check_proj].is_marker = true
                end

                if ProjConfigs[check_proj].grid.is_grid then
                    ProjConfigs[check_proj].grid.is_grid = false
                end
            end
        end
    end
    FocusedProj = reaper.EnumProjects( -1 )
end

function CheckSmoothSeek()
    local smoothseek = reaper.SNM_GetIntConfigVar('smoothseek', 0)
    SmoothSettings.is_smoothseek = GetNbit(smoothseek,0)
    SmoothSettings.is_bar = not GetNbit(smoothseek,1)
end