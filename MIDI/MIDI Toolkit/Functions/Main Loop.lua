--@noindex
function MainLoop()
    PushStyle()
    --demo.PushStyle(ctx)
    --demo.ShowDemoWindow(ctx)

    if not reaper.ImGui_IsAnyItemActive(ctx)  then -- maybe overcome TableHaveAnything
        PassKeys()
    end
    ctrl = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_ModCtrl())
    shift = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_ModShift())
    alt = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_ModAlt())

    local window_flags = reaper.ImGui_WindowFlags_MenuBar()|reaper.ImGui_WindowFlags_NoScrollbar()

    if GUISettings.pin then 
        window_flags = window_flags | reaper.ImGui_WindowFlags_TopMost()
    end 
    --reaper.ImGui_SetNextWindowSize(ctx, Gui_W, Gui_H, reaper.ImGui_Cond_Once())-- Set the size of the windows.  Use in the 4th argument reaper.ImGui_Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2
    reaper.ImGui_SetNextWindowSizeConstraints( ctx, Gui_W, Gui_H, Gui_W, Gui_H*5)
    reaper.ImGui_PushFont(ctx, FontText) -- Says you want to start using a specific font

    local visible, open  = reaper.ImGui_Begin(ctx, ScriptName..' '..Version, true, window_flags)

    CurrentW,CurrentH = reaper.ImGui_GetWindowSize(ctx)

    local change, _ --  values I will throw away
    if visible then        
        
        MenuBar()

        --- GUI MAIN:
        CopyPaste()
        PermutateGUI()
        
        -- Mapper   
        local mapper_y = reaper.ImGui_GetCursorPosY(ctx)
        Mapper()
        -- Reorder
        local reorder_y = reaper.ImGui_GetCursorPosY(ctx)
        local drag_y_reorder = Reorder()
        -- Drag Reorder = Set Mapper Height
        if (drag_y_reorder and math.abs(drag_y_reorder)>0) or MapperIsDrag then
            MapperIsDrag = true
            GUISettings.mapper_size = drag_y_reorder + GUISettings.mapper_size
            local max_size = (CurrentH - mapper_y)-150
            GUISettings.mapper_size = LimitNumber(GUISettings.mapper_size, GUISettings.mapper_min, max_size)
        end

        -- Run Stuck Function LOL
        if StuckFunction then
            StuckFunction.func(StuckFunction.arg1,StuckFunction.arg2, Gap, IsGap)
        end

        reaper.ImGui_End(ctx)
    end 

    reaper.ImGui_PopFont(ctx) -- Pop Font
    PopStyle()
    --demo.PopStyle(ctx)

    if open then
        reaper.defer(MainLoop)
    else
        reaper.ImGui_DestroyContext(ctx)
    end
end