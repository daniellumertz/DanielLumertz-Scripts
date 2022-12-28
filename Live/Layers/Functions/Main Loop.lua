--@noindex
function main_loop()
    PushTheme()
    demo.PushStyle(ctx)
    demo.ShowDemoWindow(ctx)
    ----------- Pre GUI area
    if not reaper.ImGui_IsAnyItemActive(ctx) and not TableHaveAnything(PreventKeys) then 
        PassKeys()
    end

    ----------- Checks / Get Input / Update with Inputs 
    CheckProjects()
    MIDIInput = GetMIDIInput() -- Global variable with the MIDI from current loop

    UpdateValues()

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
        MenuBar()
        local _ --  values I will throw away
        --- GUI MAIN: 
        ParametersTabs()

        -- Trigger Buttons
        reaper.ImGui_End(ctx)
    end 

    -- UpdateLayerFX -- Calculate the true value, if changed: Update the FX.
    
    reaper.ImGui_PopFont(ctx) -- Pop Font
    PopTheme()
    demo.PopStyle(ctx)

    if open then
        reaper.defer(main_loop)
    else
        reaper.ImGui_DestroyContext(ctx)
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

    -- Check if some project closed / all tracks are available / All envelopes are available / All Tracks have the Volume FX at the end
    for proj, proj_table in pairs(ProjConfigs) do
        if not TableHaveValue(projects_opened,proj) then
            ProjConfigs[proj] = nil-- if closed remove from ProjConfigs. configs should be saved as user uses.
            ProjPaths[proj] = nil
            goto continue
        end

        for parameter_idx, parameter in ipairs(proj_table.parameters) do
            for track, target in pairs(parameter.targets) do
                if (type(track) == "string") or (not reaper.ValidatePtr2(proj, track, 'MediaTrack*')) then -- string means it couldnt be loaded when opening the script, from the save. Remove this target
                    parameter.targets[track] = nil
                end
            end

            if (type(parameter.envelope) == "string") or (not reaper.ValidatePtr2(proj, parameter.envelope, 'TrackEnvelope*')) then -- string means it couldnt be loaded when opening the script, from the save. Remove this target
                parameter.envelope = nil
            end 
        end
        ::continue::
    end

    
    
    FocusedProj = reaper.EnumProjects( -1 )
end

function UpdateValues()
    local proj_t = (UserConfigs.only_focus_project and {ProjConfigs[FocusedProj]}) or ProjConfigs -- if only_focus_project will be a table with the focused project only else will do for all open projectes
    for proj, project_table in pairs(proj_t) do
        -- Playing info (for envelopes)
        local is_play = reaper.GetPlayStateEx(proj)&1 == 1 -- is playing 
        local pos = (is_play and reaper.GetPlayPositionEx( proj )) or reaper.GetCursorPositionEx(proj) -- current pos
        local s_rate =  reaper.GetSetProjectInfo( proj, 'PROJECT_SRATE ', 0, false )

        for parameter_idx, parameter in ipairs(project_table.parameters) do
            ----- Update with Envelopes 
            if parameter.envelope and GetEnvelopeBypass(parameter.envelope) then -- If envelope and not bypassed 
                -- Get min and max
                local br_env = reaper.BR_EnvAlloc( parameter.envelope, false )
                local active, visible, armed, inLane, laneHeight, defaultShape, minValue, maxValue, centerValue, type, faderScaling, automationItemsOptions = reaper.BR_EnvGetProperties( br_env )
                reaper.BR_EnvFree( br_env, false )
                -- Get the current Value
                local retval, value, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate( parameter.envelope, pos, 0, 0)
                -- Normalize between 0 and 1
                local scale_mode = reaper.GetEnvelopeScalingMode(parameter.envelope) -- Never 1 ? 
                value = reaper.ScaleFromEnvelopeMode(scale_mode, value)
                local value = MapRange(value,minValue, maxValue,0,1)
                parameter.value = value
            end

            ----- Update with MIDI 
            local midi_val = CheckMIDIInput(parameter.midi)
            if midi_val then
                parameter.value = midi_val/127
            end

        end
    end
end