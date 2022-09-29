--@noindex
function loop()
    PushGeneralStyle()
    --demo.PushStyle(ctx)
    --demo.ShowDemoWindow(ctx)

    if not reaper.ImGui_IsAnyItemActive(ctx)  then -- maybe overcome TableHaveAnything
        PassKeys()
    end

    local window_flags = reaper.ImGui_WindowFlags_NoResize() | reaper.ImGui_WindowFlags_MenuBar() 
    if Pin then 
        window_flags = window_flags | reaper.ImGui_WindowFlags_TopMost()
    end 
    reaper.ImGui_SetNextWindowSize(ctx, Gui_W, Gui_H, reaper.ImGui_Cond_Once())-- Set the size of the windows.  Use in the 4th argument reaper.ImGui_Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2
    reaper.ImGui_PushFont(ctx, FontText) -- Says you want to start using a specific font

    local visible, open  = reaper.ImGui_Begin(ctx, ScriptName..' '..Version, true, window_flags)

    local change, _ --  values I will throw away
    if visible then
        --- GUI MAIN: 
        MenuBar()
        --- Title
        TitleTextCenter('Markov Chains')
        -----
        reaper.ImGui_Separator(ctx)
        ------------------------------------------------
        ------------------------------------- Get  Part
        ------------------------------------------------
        TitleTextCenter('Source')


        --------- Source Combo Selector 
        local source_buttom_ratio = 1.333
        SetNextItemWidthRatio(source_buttom_ratio,Gui_W)
        SourceCombo()

        -------- Source Get Button
        local source_width  = SetNextItemWidthRatio(source_buttom_ratio,Gui_W)
        if reaper.ImGui_Button(ctx, 'Get Selected Notes',source_width) then
            AddNoteSelectionToSourceTable(SelectedSourceTable,Gap,IsGap,CombineTakes)
        end
        ToolTip(GUISettings.tips, 'Save selected notes from MIDI editor as a new source in the selected source table. Each source table can get as much sources as needed, each time you click this button it will add a source with the selected notes in the selected source table')

        -- If Right Clicked
        if reaper.ImGui_BeginPopupContextItem(ctx) then
            -- CombineTakes checkbox.
            _, CombineTakes = reaper.ImGui_Checkbox(ctx, 'Combine Editable Takes?', CombineTakes)
            ToolTip(GUISettings.tips, 'If true and have multiple takes in the MIDI Editor, will combine all the notes from all the takes into one source. If false, will create a source for each take with selected notes.')

            reaper.ImGui_EndPopup(ctx)
        end

        -------- Save Source Button
        -------- Load Source Button
        
        
        ---------------------------------------------
        ------------------------------------- Action
        ---------------------------------------------


        reaper.ImGui_Separator(ctx)
        --- Title
        TitleTextCenter('Action')
        TextCenter('Using Selected Source Table and This Parameters:')

        ------------------- Action Parameters
        local col1 = 40
        local col2 = 85+col1 -- for the second radio option 
        local col3 = 215+col1 -- for the order
        ----------------------- Pitch
        reaper.ImGui_SetCursorPosX(ctx, col1)
        local retval, retval2, old_radio_pitch = nil,nil,PitchSettings.mode
        retval, PitchSettings.mode = reaper.ImGui_RadioButtonEx(ctx, 'Pitch##PitchRadio', PitchSettings.mode, 1)
        ToolTip(GUISettings.tips, 'If true, will change the pitch of selected notes using a markov based on MIDI pitch values or pitch classes, the markov chances are created from the sources at the selected source table.')
        PitchRightClickMenu()

        reaper.ImGui_SameLine(ctx,col2)
        retval2, PitchSettings.mode = reaper.ImGui_RadioButtonEx(ctx, 'Interval##IntervalRadio', PitchSettings.mode, 2)
        ToolTip(GUISettings.tips, 'If true, will change the pitch of selected notes using a markov based on the intervals, the markov chances are created from the sources at the selected source table.')
        PitchRightClickMenu()

        -- If user click at the selected value it will descelect all. 
        if (retval or retval2) and old_radio_pitch == PitchSettings.mode then
            PitchSettings.mode = 0            
        end
        reaper.ImGui_SameLine(ctx,col3)
        reaper.ImGui_SetNextItemWidth(ctx, 30)
        _, PitchSettings.order = reaper.ImGui_InputInt(ctx, 'Order##PitchOrder', PitchSettings.order,0)
        ToolTip(GUISettings.tips, 'Markov order for pitch/interval')
        if PitchSettings.order <= 0 then PitchSettings.order = 1 end


        --------------------- Rhythms
        reaper.ImGui_SetCursorPosX(ctx, col1)
        local retval, retval2, old_radio_rhythm = nil,nil,RhythmSettings.mode
        retval, RhythmSettings.mode = reaper.ImGui_RadioButtonEx(ctx, 'Rhythm##RhythmRadio', RhythmSettings.mode, 1)
        ToolTip(GUISettings.tips, 'If true, will change the position of selected notes using a markov based on the rhythms(distance between events), the markov chances are created from the sources at the selected source table.')
        RhythmRightClickMenu()

        reaper.ImGui_SameLine(ctx,col2)
        retval2, RhythmSettings.mode = reaper.ImGui_RadioButtonEx(ctx, 'Measure Position##GrooveRadio', RhythmSettings.mode, 2)
        ToolTip(GUISettings.tips, 'If true, will change the position of selected notes using a markov based on the measure position(distance from the start of the measure), the markov chances are created from the sources at the selected source table.')
        RhythmRightClickMenu()

        -- If user click at the selected value it will descelect all.
        if (retval or retval2) and old_radio_rhythm == RhythmSettings.mode then
            RhythmSettings.mode = 0
        end
        reaper.ImGui_SameLine(ctx,col3)
        reaper.ImGui_SetNextItemWidth(ctx, 30)
        _, RhythmSettings.order = reaper.ImGui_InputInt(ctx, 'Order##RhythmOrder', RhythmSettings.order,0)
        ToolTip(GUISettings.tips, 'Markov order for rhythm/measure position.')
        if RhythmSettings.order <= 0 then RhythmSettings.order = 1 end


        ------- Velocity
        reaper.ImGui_SetCursorPosX(ctx, col1)
        local retval, old_radio_velocity = nil , VelSettings.mode
        retval, VelSettings.mode = reaper.ImGui_RadioButtonEx(ctx, 'Velocity##VelocityRadio', VelSettings.mode, 1)
        ToolTip(GUISettings.tips, 'If true, will change the velocity of selected notes using a markov based velocity, the markov chances are created from the sources at the selected source table.')
        VelocityRightClickMenu()


        if retval  and old_radio_velocity == VelSettings.mode then
            VelSettings.mode = 0
        end
        reaper.ImGui_SameLine(ctx,col3)
        reaper.ImGui_SetNextItemWidth(ctx, 30)
        _, VelSettings.order = reaper.ImGui_InputInt(ctx, 'Order##VelocityOrder', VelSettings.order,0)
        ToolTip(GUISettings.tips, 'Markov order for velocity.')
        if VelSettings.order <= 0 then VelSettings.order = 1 end

        ------------------- Links
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_SetCursorPosX( ctx, (2*col1)/3)

        local links_tooltip = 'Link parameters together. This helps to have more consistency between the parameters, without links they are completely independent. Not compatible with weights.'
        if reaper.ImGui_TreeNode(ctx, 'Link') then
            ToolTip(GUISettings.tips, links_tooltip)

            --TitleTextCenter('Links')
            local retval
            reaper.ImGui_SetCursorPosX( ctx, col1 )
            retval, LinkSettings.pitch = reaper.ImGui_Checkbox(ctx, 'Pitch##PLink', LinkSettings.pitch)
            if retval and LinkSettings.pitch then
                PCWeight = nil
            end
            LinkRightClickMenu()
            reaper.ImGui_SameLine(ctx,((col3-col1)/2)+col1)
            retval, LinkSettings.rhythm = reaper.ImGui_Checkbox(ctx, 'Rhythm##RLink', LinkSettings.rhythm)
            if retval and LinkSettings.rhythm then
                PosQNWeight = nil
            end
            LinkRightClickMenu()
            reaper.ImGui_SameLine(ctx,col3)
            retval, LinkSettings.vel = reaper.ImGui_Checkbox(ctx, 'Velocity##VLink', LinkSettings.vel)
            LinkRightClickMenu()   
            reaper.ImGui_TreePop(ctx)
        else
            ToolTip(GUISettings.tips, links_tooltip)
        end

     

        ------------------- Action Buttons
        reaper.ImGui_Separator(ctx)
        ------- Apply Button
        local buttons_pad = 12
        if reaper.ImGui_Button(ctx, 'Apply',-1,-1) then
            if #SelectedSourceTable >= 1 then
                ReaperApplyMarkov(SelectedSourceTable,PitchSettings,RhythmSettings,VelSettings,LinkSettings, Gap,IsGap,Legato) -- SelectedSourceTable,pitch_settings,rhythm_settings,vel_setting,event_size,is_event
            else
                reaper.ShowMessageBox('Ops! You dont have anything inside the selected source table!\nClick on "Get" to put selected notes inside selected source table!', ScriptName..' Ops!', 0)
            end 
        end
        ToolTip(GUISettings.tips, 'Apply the markov algorithm at the selected notes, based on the selected source table. Apply only the parameters selected on the UI.')
        -- If Right Clicked
        if reaper.ImGui_BeginPopupContextItem(ctx) then
            local old_legato = Legato
            local legato_radio = (Legato == true and 1) or (Legato == 'take' and 2) or (not Legato and 0)
            local retval, legato_radio = reaper.ImGui_RadioButtonEx(ctx, 'Legato', legato_radio, 1)
            ToolTip(GUISettings.tips, 'If true, will make a legato between the notes per take')
            if retval then
                Legato = true
            end
            local retval2, legato_radio = reaper.ImGui_RadioButtonEx(ctx, 'Legato Multiple Takes', legato_radio, 2)
            ToolTip(GUISettings.tips, 'If true, will make a legato between the notes')
            if retval2 then
                Legato = 'take'
            end

            if (retval2 == true or retval == true) and old_legato == Legato then
                Legato = false
            end
            reaper.ImGui_EndPopup(ctx)
        end
        reaper.ImGui_End(ctx)
    end 

    OpenPopups() 
    reaper.ImGui_PopFont(ctx) -- Pop Font
    
    PopGeneralStyle()

    if open then
        --demo.PopStyle(ctx)
        reaper.defer(loop)
    else
        reaper.ImGui_DestroyContext(ctx)
        SaveSettings(ScriptPath,SettingsFileName)
    end
end