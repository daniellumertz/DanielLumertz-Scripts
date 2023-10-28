function GuiInitAI(ScriptName)
    ctx = reaper.ImGui_CreateContext(ScriptName) -- Add VERSION TODO
    -- Define Globals GUI
    Gui_W,Gui_H= 275,300
    FLT_MIN, FLT_MAX = reaper.ImGui_NumericLimits_Float()
    
    --- Text Font
    FontText = reaper.ImGui_CreateFont('sans-serif', 14) -- Create the fonts you need
    reaper.ImGui_Attach(ctx, FontText)-- Attach the fonts you need
end

function main_loop_ai()
    --- Script management
    proj = select(1, reaper.EnumProjects( -1 ))
    if not PhasingOptions[proj] then 
        PhasingOptions[proj] = CreateProjectSettings()
    end
    ---
    PushTheme()
    --demo.PushStyle(ctx)
    --demo.ShowDemoWindow(ctx)

    if not reaper.ImGui_IsAnyItemActive(ctx)  then -- maybe overcome TableHaveAnything
        PassKeys()
    end

    --- Window management
    local window_flags = reaper.ImGui_WindowFlags_AlwaysAutoResize() --reaper.ImGui_WindowFlags_MenuBar() -- | reaper.ImGui_WindowFlags_NoResize() | 
    if Pin then 
        window_flags = window_flags | reaper.ImGui_WindowFlags_TopMost()
    end 
    reaper.ImGui_SetNextWindowSize(ctx, Gui_W, Gui_H, reaper.ImGui_Cond_Once())-- Set the size of the windows.  Use in the 4th argument reaper.ImGui_Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2
    reaper.ImGui_PushFont(ctx, FontText) -- Says you want to start using a specific font

    local visible, open  = reaper.ImGui_Begin(ctx, ScriptName..' '..Version, true, window_flags)

    local _ --  values I will throw away
    if visible then
        --- GUI MAIN: 
        gui_all()
        reaper.ImGui_End(ctx)
    end 
    
    -- OpenPopups() 
    reaper.ImGui_PopFont(ctx) -- Pop Font
    PopTheme()
    if open then
        --demo.PopStyle(ctx)
        reaper.defer(main_loop_ai)
    else
        reaper.ImGui_DestroyContext(ctx)
    end
end

-- Gui containing the ItsGonnaPhase tab and the AutomationItems envelope
function gui_all()
    if reaper.ImGui_BeginTabBar(ctx, 'SectionsTab') then

        if reaper.ImGui_BeginTabItem(ctx, 'Phase') then
            PhasingGUI()
            reaper.ImGui_EndTabItem(ctx)
        end

        if reaper.ImGui_BeginTabItem(ctx, 'Sequencing') then
            reaper.ImGui_Text(ctx, 'aeae')
            reaper.ImGui_EndTabItem(ctx)
        end

        
        reaper.ImGui_EndTabBar(ctx)
    end
end

function PhasingGUI()
    ------------------------- Item Section
    TextCenter('Item Section:')
    reaper.ImGui_NewLine(ctx)

    local _
    if reaper.CountSelectedMediaItems(proj) ~= 0 then
        local bol = IsLoopItemSelected()
        if  bol then
            reaper.ImGui_Text(ctx, '---- ## Item! ----')
        else
            reaper.ImGui_Text(ctx, '---- Others Items ----')
        end
    else
        TextCenter('---- Select Some Items ----')
    end
    ------------------------- Apply Section
    reaper.ImGui_Separator(ctx) 
    TextCenter('Apply Section:')
    reaper.ImGui_NewLine(ctx)


    _, PhasingOptions[proj].IsPhaseItems= reaper.ImGui_Checkbox(ctx, 'Items', PhasingOptions[proj].IsPhaseItems)
    reaper.ImGui_SameLine(ctx)
    _, PhasingOptions[proj].IsPhaseAutomation= reaper.ImGui_Checkbox(ctx, 'Automation', PhasingOptions[proj].IsPhaseAutomation)
    if reaper.ImGui_Button(ctx, 'Apply Phasing', -FLT_MIN) then
        
    end
end