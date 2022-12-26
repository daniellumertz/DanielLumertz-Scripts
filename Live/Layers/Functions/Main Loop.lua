--@noindex
function main_loop()
    PushTheme()
    demo.PushStyle(ctx)
    demo.ShowDemoWindow(ctx)
    ----------- Pre GUI area
    if not reaper.ImGui_IsAnyItemActive(ctx) and not TableHaveAnything(PreventKeys) then 
        PassKeys()
    end

    CheckProjects()
    MIDIInput = GetMIDIInput() -- Global variable with the MIDI from current loop

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
        local retval = ce_draw(ctx, points, "curve", 0, 100,{0.5})
        local retval = ce_draw(ctx, points2, "curves", 0, 100)


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

    -- Check if some project closed
    for proj, proj_table in pairs(ProjConfigs) do
        if not TableHaveValue(projects_opened,proj) then
            ProjConfigs[proj] = nil-- if closed remove from ProjConfigs. configs should be saved as user uses
            ProjPaths[proj] = nil
        end
    end

    --- TODO Check if all tracks are available 
    -- Check if all tracks have the FX, make sure it is at the end of the fx list
    -- Safe check if some take couldnt load (like if it was deleted). Remove if cant find
    
    FocusedProj = reaper.EnumProjects( -1 )
end

