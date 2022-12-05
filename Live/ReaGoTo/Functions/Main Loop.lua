--@noindex
function main_loop()
    PushTheme()
    --demo.PushStyle(ctx)
    --demo.ShowDemoWindow(ctx)
    ----------- Pre GUI area
    if not reaper.ImGui_IsAnyItemActive(ctx)  then -- maybe overcome TableHaveAnything
        PassKeys()
    end

    --CheckProjects()
    --GetMIDIInputs()


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
    --[[     CTRL = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl())
        SHIFT = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift())
        ALT = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) ]]

    if visible then
        MenuBar()
        local _ --  values I will throw away
        --- GUI MAIN: 
        GroupSelector(ProjConfigs[FocusedProj].groups)

        reaper.ImGui_End(ctx)
    end 
    
    -- OpenPopups() 
    reaper.ImGui_PopFont(ctx) -- Pop Font
    PopTheme()
    --emo.PopStyle(ctx)

    GoToLoop()  -- Check if need change playpos (need to be after the user input). If ProjConfigs[proj].is_trigerred then change the playpos at last moment possible.

    if open then
        reaper.defer(main_loop)
    else
        reaper.ImGui_DestroyContext(ctx)
    end
end

--- Check for each project if need to trigger goto
function GoToLoop()
    local proj_t = (UserConfigs.only_focus_project and {ProjConfigs[FocusedProj]}) or ProjConfigs -- if only_focus_project will be a table with the focused project only else will do for all open projectes
    for proj, project_table in pairs(proj_t) do
        if not project_table.is_trigerred then goto continue end
        -- Get play pos/state
        local is_play = reaper.GetPlayStateEx(proj)&1 == 1 -- is playing 
        local pos = (is_play and reaper.GetPlayPositionEx( proj )) or reaper.GetCursorPositionEx(proj) -- current pos
        local time = reaper.time_precise()

        -- if stoped
        if project_table.stop_trigger and project_table.oldisplay and not is_play then
            project_table.is_triggered = false
        end

        -- if playing and triggered look after next Trigger point 
        if is_play and project_table.is_triggered then

            local trigger_point 
            ------- Get the next triggering point (currently only for makers maybe do for QN values as well)
            -- Loop each marker (improve with a binary search later)
            local retval, num_markers, num_regions = reaper.CountProjectMarkers(proj)
            for i = 0, num_markers-1 do
                local retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers( i )
                if mark_pos > pos and name:match('^'..project_table.identifier)  then
                    trigger_point = mark_pos
                    break -- just need the next #goto marker
                end
            end
            -- TODO Opitonal config project_table.is_region_end_trigger, if is true this config use then current region end as a #goto if it is next than the next #goto marker
            ------- Change Player position if needed (Try to change as close to the marker as possible)
            if trigger_point then -- only if there is something to trigger to comapre to
                -- If markers get triggers overides
                local delta =  time - project_table.oldtime -- for defer instability estimation
                -- Estimate next defer cycle position, check if is after the loop end. Always estimate a little longer to compensate for defer instability. This can cause to trigger twice. Use a variable that reset each loop start to prevent that.
                local playrate = reaper.Master_GetPlayRate(proj)
                if is_play and pos + (delta * UserConfigs.compensate) * playrate >= trigger_point then -- will it need project_table.oldpos < trigger_point  ?
                    ---- Calculate the new position
                    GoTo(project_table.is_triggered,proj)
                    ---- Add Markers at the trigger position for debugging mostly
                    if UserConfigs.add_markers then
                        reaper.AddProjectMarker(proj, false, pos, 0, '', 0) -- debug when it is happening
                    end
                end
            end
        elseif not is_play and project_table.is_triggered then -- change to the start of the region/marker
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

    --- Check if all takes are available 
    for check_proj in enumProjects() do
        for group_idx, group in ipairs(ProjConfigs[check_proj].groups) do -- for every group
            for take_idx, take_table in ipairs_reverse(group) do -- for every take
                local take = take_table.take
                if not reaper.ValidatePtr2(check_proj, take, 'MediaItem_Take*') then -- Remove missing takes@
                    table.remove(group,take_idx)
                end
            end
        end

    end
    FocusedProj = reaper.EnumProjects( -1 )
end

