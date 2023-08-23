-- @noindex
function GuiInit()
    ctx = reaper.ImGui_CreateContext(ScriptName, reaper.ImGui_ConfigFlags_DockingEnable()) -- Add VERSION TODO
    --- Text Font
    FontText = reaper.ImGui_CreateFont('sans-serif', 14) -- Create the fonts you need
    reaper.ImGui_Attach(ctx, FontText)-- Attach the fonts you need
    --- Smaller Font for smaller widgets
    FontTiny = reaper.ImGui_CreateFont('sans-serif', 10) 
    reaper.ImGui_Attach(ctx, FontTiny)
end

function PlaylistSelector(playlists)
    -- calculate positions
    local _
    -- tabs
    if reaper.ImGui_BeginTabBar(ctx, 'Playlist', reaper.ImGui_TabBarFlags_Reorderable() | reaper.ImGui_TabBarFlags_AutoSelectNewTabs() ) then
        local is_save
        for playlist_key, playlist in ipairs(playlists) do -- iterate every playlist
            local open, keep = reaper.ImGui_BeginTabItem(ctx, ('%s###tab%d'):format(playlist.name, playlist_key), false) -- Start each tab
            ToolTip(UserConfigs.tooltips,'This is a playlist. Right Click for more options.')        

            -- Popup to rename and delete
            if reaper.ImGui_BeginPopupContextItem(ctx) then 
                is_save = RenamePlaylistPopUp(playlist, playlist_key, playlists) 
                reaper.ImGui_EndPopup(ctx)
            elseif PreventKeys.playlist_popup == playlist_key  then
                PreventKeys.playlist_popup = nil
            end

            -- Show regions and markers inside this group
            if open then
                playlists.current = playlist_key  -- current playlist user is looking at 1 based
                local change = PlaylistTab(playlist)
                is_save = change or is_save
                reaper.ImGui_EndTabItem(ctx) 
            end

        end
        -- Add Playlist
        if reaper.ImGui_TabItemButton(ctx, '+', reaper.ImGui_TabItemFlags_Trailing() | reaper.ImGui_TabItemFlags_NoTooltip()) then -- Start each tab
            table.insert(playlists,CreateNewPlaylist('P'..#playlists+1)) -- TODO
            is_save = true
        end

        if is_save then -- Save settings
            SaveProjectSettings(FocusedProj, ProjConfigs[FocusedProj]) -- TODO
        end
        
        reaper.ImGui_EndTabBar(ctx)
    end
end

function PlaylistTab(playlist)
    local project_table = ProjConfigs[FocusedProj]
    local is_save -- if something changed than save

    -- Button
    if reaper.ImGui_Button(ctx, 'Add Region/Marker', -FLTMIN) then
        TempRegionID = ''
        TempIsRegion = true
        reaper.ImGui_OpenPopup( ctx, 'Add Region/Marker##popup'..playlist.name )
        --Popup insert idx or name
    end
    ToolTip(UserConfigs.tooltips,'Add a region/marker to the playlist')        
    AddRegionPopUp(playlist)

    -- Each region/marker
    local avail_x, avail_y = reaper.ImGui_GetContentRegionAvail(ctx)
    local line_size = reaper.ImGui_GetTextLineHeight(ctx) -- give space for the buttons bellow
    if reaper.ImGui_BeginChild(ctx, 'GroupSelect', -FLTMIN, avail_y-line_size*3.5, true, reaper.ImGui_WindowFlags_NoScrollbar()) then

        for region_idx, region_table in ipairs(playlist) do
            local guid = region_table.guid
            -- Each region/marker info:
            local _, region_id = reaper.GetSetProjectInfo_String( FocusedProj, 'MARKER_INDEX_FROM_GUID:'..guid, '', false )
            local retval, region_isrgn, region_pos, region_rgnend, region_name, region_markrgnindexnumber = reaper.EnumProjectMarkers2( FocusedProj, region_id) 
            local selectable_name = (region_name == '' and region_markrgnindexnumber) or region_name
            reaper.ImGui_SetNextItemWidth(ctx, 150)
            local retval, p_selected = reaper.ImGui_Selectable(ctx, selectable_name..'##'..region_idx, region_idx == playlist.current, reaper.ImGui_SelectableFlags_AllowItemOverlap() )
            ToolTip(UserConfigs.tooltips,'This is a region/marker at the playlist. Right Click for more options. Drag to change the order. Double click to trigger a GOTO to that position, hold alt and double click to execute the goto immediately.')        

            if project_table.is_triggered and tonumber(project_table.is_triggered:match('^goto(.+)')) == region_idx then
                local alpha = MapRange(GUIButtomAnimationVal,-1,1,0.2,0.5) --adds alpha based on animation step
                DrawRectLastItem(40/360, 0.84, 0.92,alpha)
            end

            -- Double Click/ MIDI Trigger goto region
            local midi_trigger = CheckMIDITrigger(region_table.midi)
            if (reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx,0)) or midi_trigger then
                SetGoTo(FocusedProj, 'goto'..region_idx)
                if reaper.ImGui_GetKeyMods(ctx) == reaper.ImGui_Mod_Alt() then
                    GoTo(ProjConfigs[FocusedProj].is_triggered,FocusedProj)
                end
            end

            -- rename / delete take popup
            if reaper.ImGui_BeginPopupContextItem(ctx) then
                TempWasOpen = region_idx
                TempName = region_name -- Temporary holds the name as the user writes
                local is_del = RenameRegionMarkerPopUp(playlist, region_idx, region_name)
                if is_del then -- take was removed from table
                    TempName = nil
                    TempWasOpen  = nil
                    is_save = is_save or true
                end
                reaper.ImGui_EndPopup(ctx)
            elseif TempWasOpen == region_idx then
                if TempName ~= region_name then
                    reaper.Undo_BeginBlock2(FocusedProj)
                    reaper.SetProjectMarker2( FocusedProj, region_markrgnindexnumber, region_isrgn, region_pos, region_rgnend, TempName )
                    reaper.Undo_EndBlock2(FocusedProj, 'Rename Region', -1)
                end
                TempName = nil
                TempWasOpen  = nil
                PreventKeys.region_popup = nil
                is_save = true -- always resave when closing 
            end

            -- Drag
            if reaper.ImGui_BeginDragDropSource(ctx, reaper.ImGui_DragDropFlags_None()) then
                -- Set payload to carry the index of our take (could be anything)
                reaper.ImGui_SetDragDropPayload(ctx, 'TAKESLIST', tostring(region_idx))
        
                reaper.ImGui_EndDragDropSource(ctx)
            end
            -- Drop
            if reaper.ImGui_BeginDragDropTarget(ctx) then
                local payload, rv
                rv,payload = reaper.ImGui_AcceptDragDropPayload(ctx, 'TAKESLIST')
                if rv then
                    local source_idx = tonumber(payload) -- source idx
                    local move_val = playlist[source_idx] -- Source val
   
                    table.remove(playlist,source_idx)
                    table.insert(playlist,region_idx,move_val)
                    is_save = is_save or true
                end
                reaper.ImGui_EndDragDropTarget(ctx)
            end

        end
        reaper.ImGui_EndChild(ctx)
    end

    return is_save
end

function AddRegionPopUp(playlist,playlist_idx) -- STOP HERE TESTING
    if reaper.ImGui_BeginPopup(ctx, 'Add Region/Marker##popup'..playlist.name) then
        if reaper.ImGui_IsWindowAppearing(ctx) then
            PreventKeys.add_region = true
        end
        local retval
        --- Input options
        reaper.ImGui_Text(ctx, 'Region ID/Name:')
        retval, TempRegionID = reaper.ImGui_InputText(ctx, '##Input region'..playlist.name, TempRegionID) -- Why it can't erase everything???
        -- checkbox
        retval, TempIsRegion = reaper.ImGui_Checkbox(ctx, 'Is Region', TempIsRegion)
        reaper.ImGui_SameLine(ctx)
        retval, TempAddByName = reaper.ImGui_Checkbox(ctx, 'Add By name', TempAddByName)
        if not TempAddByName then TempRegionID = tonumber(TempRegionID) end 
        -- Get the information
        local getmarkfunc = (TempAddByName and GetMarkByName) or GetMarkByID
        local retval, isrgn, mark_pos, rgnend, mark_name, markrgnindexnumber, color, idx = getmarkfunc(FocusedProj,TempRegionID,(TempIsRegion and 2 or 1))
        --- Helper text (little text to show name or ID) 
        if retval then

            ImPrint('Name        :',mark_name)
            ImPrint('Idx Number  :', markrgnindexnumber)

            local is_enter =  reaper.ImGui_IsKeyDown(ctx, 13)
            if (reaper.ImGui_Button(ctx, 'Add', -FLTMIN) or is_enter ) and TempRegionID then
                if idx then 
                    local region_table = CreateNewRegion(idx, FocusedProj)
                    if region_table then
                        table.insert(playlist,region_table)
                    end
                end
                TempRegionID = nil
                TempIsRegion = nil
                TempAddByName = nil
                reaper.ImGui_CloseCurrentPopup(ctx)
            end
        else
            ImPrint('Region or Marker Not Found!')
        end
        reaper.ImGui_EndPopup(ctx)
    else
        PreventKeys.add_region = nil
    end
    
end

function RenameRegionMarkerPopUp(playlist, k)
    local region_table = playlist[k]
    local _
    reaper.ImGui_Text(ctx, 'Edit name:')
    
    if reaper.ImGui_IsWindowAppearing(ctx) then
        PreventKeys.region_popup = true
        reaper.ImGui_SetKeyboardFocusHere(ctx)
    end
    _, TempName = reaper.ImGui_InputText(ctx, "##renameinput", TempName)

    -- Chance 
    local change
    reaper.ImGui_SetNextItemWidth(ctx, 30)
    change, region_table.chance = reaper.ImGui_InputInt(ctx, 'Chance##'..k, region_table.chance, 0, 0)
    if region_table.chance < 0 then region_table.chance = 0 end
    ToolTip(UserConfigs.tooltips,'When triggering a GOTO random this determine the change this region haves.')        


    -- Loop 
    if region_table.type == 'region' then
        reaper.ImGui_SameLine(ctx)
        _, region_table.loop = reaper.ImGui_Checkbox(ctx, 'Loop Region ##loopcheckbox'..k, region_table.loop)
    end
    ToolTip(UserConfigs.tooltips,'When triggering this region make a loop around it.')        

    -- remove button
    if reaper.ImGui_Button(ctx, 'Remove Region/Marker', -FLTMIN) then
        table.remove(playlist,k) -- remove from the main table
        return true
    end

    -- MIDI
    reaper.ImGui_Separator(ctx)
    MIDILearn(region_table.midi)
    

    -- Enter close popup
    if reaper.ImGui_IsKeyDown(ctx, 13) then
        reaper.ImGui_CloseCurrentPopup(ctx)
    end
end

function RenamePlaylistPopUp(playlist, playlist_key, playlists)
    local is_save, change
    reaper.ImGui_Text(ctx, 'Playlist name:')
    if reaper.ImGui_IsWindowAppearing(ctx) then
        PreventKeys.playlist_popup = playlist_key
        reaper.ImGui_SetKeyboardFocusHere(ctx)
    end
    reaper.ImGui_SetNextItemWidth(ctx, -FLTMIN)
    change, playlist.name = reaper.ImGui_InputText(ctx, "##renameinput", playlist.name)
    is_save = is_save or change
    -- delete
    if reaper.ImGui_Button(ctx, 'Delete Playlist',-FLTMIN) then
        reaper.ImGui_CloseCurrentPopup(ctx)
        table.remove(playlists,playlist_key)
        is_save = true
    end

    change, playlist.reset = reaper.ImGui_Checkbox(ctx, 'Reset at stop', playlist.reset)
    is_save = is_save or change
    ToolTip(UserConfigs.tooltips,'When stopping/pausing the project the playlist will go back to the first region/marker.')    

    if playlist.reset then
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_SetNextItemWidth(ctx, -FLTMIN)
        change, playlist.reset_n = reaper.ImGui_InputInt(ctx, "##resetnumber", playlist.reset_n, 0, 0)
        if change then
            playlist.reset_n = LimitNumber(playlist.reset_n,0,#playlist)
        end
        is_save = is_save or change
        ToolTip(true,'When stopping/pausing the project the playlist will go to which playlist value?')    

        change, playlist.reset_playhead = reaper.ImGui_Checkbox(ctx, 'Move Playhead at Reset', playlist.reset_playhead)
        is_save = is_save or change
        ToolTip(UserConfigs.tooltips,'When stopping/pausing the project move the playhead to the selected playlist value.')    
    end

    change, playlist.shuffle = reaper.ImGui_Checkbox(ctx, 'Shuffle playlist at end.', playlist.shuffle)
    is_save = is_save or change
    ToolTip(UserConfigs.tooltips,'When the playlist loops around it will shuffle the region/markers order.')    

    -- Enter Close it fucking down
    if reaper.ImGui_IsKeyDown(ctx, 13) then
        reaper.ImGui_CloseCurrentPopup(ctx)
    end
    return is_save
end

function TriggerButtons(playlists)
    local function triggered_button_style(check_trigger, proj)
        if not proj then proj = FocusedProj end
        if ProjConfigs[proj].is_triggered == check_trigger then 
            local alpha = MapRange(GUIButtomAnimationVal,-1,1,0.6,0.9) --adds alpha based on animation step
            local button_collor = HSVtoImGUI(40/360, 0.84, 0.92, alpha)
            local button_collor_hover = HSVtoImGUI(40/360, 0.84, 0.92, 0.9)
            local button_collor_active = HSVtoImGUI(40/360, 0.84, 0.92, 1)
            
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        button_collor)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), button_collor_hover)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  button_collor_active)
            return true
        end
        return false
    end

    local function pop_button_style(check)
        if check then 
            reaper.ImGui_PopStyleColor(ctx, 3)
        end
    end

    local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
    local button_gap = 8
    local button_cnt = 3
    local button_size = ((avail_w-((button_cnt-1)*button_gap))/button_cnt)
    local is_just_activated = ProjConfigs[FocusedProj].is_triggered and true   -- check if a button was just activated in this frame, to prevent 'cancel' button to appear in just one frame.
    do -- Prev Button
        local trigger_string = 'prev'
        local midi_trigger = CheckMIDITrigger(ProjConfigs[FocusedProj].buttons.prev.midi) -- Trigger the current random (if holding ctrl without reptitio, holding ctrl can be itself )
        local paint = triggered_button_style(trigger_string)
        if reaper.ImGui_Button(ctx, '<',button_size) or midi_trigger then
            SetGoTo(FocusedProj, 'prev')
            if reaper.ImGui_GetKeyMods(ctx) == reaper.ImGui_Mod_Alt() then
                GoTo(ProjConfigs[FocusedProj].is_triggered,FocusedProj)
            end
        end
        ToolTip(UserConfigs.tooltips,'Goto previous at the playlist. Right click for MIDI Learn. Alt Click to execute immediataly.')        

        pop_button_style(paint)
        MidiPopupButtons(ProjConfigs[FocusedProj].buttons.prev.midi)
    end

    do -- Random Button
        local trigger_string
        if reaper.ImGui_GetKeyMods(ctx) == reaper.ImGui_Mod_Ctrl() then
            trigger_string = 'random_with_rep'
        else
            trigger_string = 'random'
        end
        local midi_trigger = CheckMIDITrigger(ProjConfigs[FocusedProj].buttons.random.midi) -- Trigger the current random (if holding ctrl without reptitio, holding ctrl can be itself )
        local paint = triggered_button_style('random')
        local paint2 = triggered_button_style('random_with_rep')
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, '?',button_size) or midi_trigger then
            SetGoTo(FocusedProj, trigger_string)
            if reaper.ImGui_GetKeyMods(ctx) == reaper.ImGui_Mod_Alt() then
                GoTo(ProjConfigs[FocusedProj].is_triggered,FocusedProj)
            end
        end
        pop_button_style(paint or paint2)
        MidiPopupButtons(ProjConfigs[FocusedProj].buttons.random.midi)
    end
    ToolTip(UserConfigs.tooltips,'Goto a random region/marker at the playlist. If holding Ctrl/Command it can repeat itself. Right click for MIDI Learn. Alt Click to execute immediataly.')        


    do -- Next Button
        reaper.ImGui_SameLine(ctx)
        local trigger_string = 'next'
        local midi_trigger = CheckMIDITrigger(ProjConfigs[FocusedProj].buttons.next.midi)
        local paint = triggered_button_style(trigger_string)
        if reaper.ImGui_Button(ctx, '>',button_size) or midi_trigger then
            SetGoTo(FocusedProj, trigger_string)
            if reaper.ImGui_GetKeyMods(ctx) == reaper.ImGui_Mod_Alt() then
                GoTo(ProjConfigs[FocusedProj].is_triggered,FocusedProj)
            end
        end
        ToolTip(UserConfigs.tooltips,'Goto next at the playlist. Right click for MIDI Learn. Alt Click to execute immediataly.')        

        pop_button_style(paint)
        MidiPopupButtons(ProjConfigs[FocusedProj].buttons.next.midi)
    end

    do -- Cancel button
        if is_just_activated and ProjConfigs[FocusedProj].is_triggered then
            local midi_trigger = CheckMIDITrigger(ProjConfigs[FocusedProj].buttons.cancel.midi)
            if reaper.ImGui_Button(ctx, 'Cancel Trigger',-FLTMIN) or midi_trigger then
                SetGoTo(FocusedProj, false)
            end
            ToolTip(UserConfigs.tooltips,'Cancel trigger.')        

            MidiPopupButtons(ProjConfigs[FocusedProj].buttons.cancel.midi)
        end
    end
end

function MenuBar()
    local function DockBtn()
        local reval_dock =  reaper.ImGui_IsWindowDocked(ctx)
        local dock_text =  reval_dock and  'Undock' or 'Dock'
    
        if reaper.ImGui_MenuItem(ctx,dock_text ) then
            if reval_dock then -- Already Docked
                SetDock = 0
            else -- Not docked
                SetDock = -3 -- Dock to the right 
            end
        end
    end
    
    local _

    if reaper.ImGui_BeginMenuBar(ctx) then
        if reaper.ImGui_BeginMenu(ctx, 'Settings') then
            if reaper.ImGui_BeginMenu(ctx, 'Goto Project Settings') then
                ------------------------------------------------ General
                reaper.ImGui_Text(ctx, 'Geral:')

                local proj_table = ProjConfigs[FocusedProj]
                local retval
                _, proj_table.moveview = reaper.ImGui_Checkbox(ctx, 'Move Arrange View at Go To', proj_table.moveview)
                ToolTip(true, 'If move arrange view position when changing position.')

                _, proj_table.stop_trigger = reaper.ImGui_Checkbox(ctx, 'Cancel Triggers at Project Stop.', proj_table.stop_trigger)
                ToolTip(true, 'When stoping/pausing playback it will cancel any goto trigger.')
                ------------------------------------------------ Marks
                reaper.ImGui_NewLine(ctx)
                reaper.ImGui_Separator(ctx)
                reaper.ImGui_Text(ctx, 'Trigger Type:')

                retval, proj_table.is_marker = reaper.ImGui_Checkbox(ctx, 'Use Goto Markers', proj_table.is_marker)
                ToolTip(true, 'Trigger Goto at goto identified markers.')
                if retval and SmoothSettings.is_smoothseek then
                    local new_val = proj_table.is_marker and 3 or 1 -- 3 = marker and smooth seek, 1 = bar and smooth seek
                    reaper.SNM_SetIntConfigVar('smoothseek', new_val)
                    proj_table.grid.is_grid = false
                end

                if proj_table.is_marker  then
                    local old_name, change = proj_table.identifier, nil
                    change, proj_table.identifier = reaper.ImGui_InputText(ctx, '##inputmarkername', proj_table.identifier)
                    ToolTip(true, 'Goto Mark Identifier, every goto marker should start with this string.\n\nAfter the indentifier is possible to use a overwrite trigger, like "#goto next" will always trigger the next region/marker at the playlist. Overwrite options are:\n\nnext=next at playlist.\nprev=prev at playlist\nrandom=random at playlist(filter current region)\nrandom_with_rep=random at playlist\ngoto..regionidx = goto a playlist idx\npos..seconds= go to a certain time in seconds\nqn..value = goto a certain position in quarter note\nbar..barnumber = goto a certainbar\nmark..mark_index = goto a certain mark\nretion..region_index = goto a region index\n\nCan also use {} to have multiple options that will chosen randomly, like {next,prev,prev,random} will choose randomly between this 4 options',300)
                    --if change then -- intrusive
                    --    RenameMarkers(FocusedProj, old_name,proj_table.identifier)
                    --end
                end

                ------------------------------------------------ Unit
                retval, proj_table.grid.is_grid = reaper.ImGui_Checkbox(ctx, 'Use Unit', proj_table.grid.is_grid)
                ToolTip(true, 'Trigger Goto by bars/whole note values.')
                if retval and SmoothSettings.is_smoothseek then
                    local new_val = proj_table.grid.is_grid and 1 or 3 -- 3 = marker and smooth seek, 1 = bar and smooth seek
                    reaper.SNM_SetIntConfigVar('smoothseek', new_val)
                    proj_table.is_marker = false
                end

                if proj_table.grid.is_grid then
                    reaper.ImGui_SetNextItemWidth(ctx, -FLTMIN)
                    _, proj_table.grid.unit_str = reaper.ImGui_InputText(ctx, '##inputval', proj_table.grid.unit_str)
                    ToolTip(true, 'Use "bar" for bars as unit. Use numbers or fractions for whole notes values. 1 = whole note, 1/4 = quarter note, etc...')

                    
                    if (not reaper.ImGui_IsItemActive(ctx))  then
                        TempStr = proj_table.grid.unit_str -- need to be in a global variable outside any table
                        TempUnit = proj_table.grid.unit
                        local function error() end
                        local set_user_val = load('TempUnit = '..TempStr) -- if RhythmSettings have math expression, it will be executed. or just get the number
                        local retval = xpcall(set_user_val,error)
                        if not tonumber(TempUnit) then -- call xpcall(set_user_val,error)
                            TempUnit = 'bar'
                            TempStr = 'bar'
                        end 
                        proj_table.grid.unit_str = TempStr
                        proj_table.grid.unit = TempUnit

                        TempStr = nil
                        TempUnit = nil
                    end
                end

                ---------------------------------------------- Force 
                reaper.ImGui_NewLine(ctx)
                reaper.ImGui_Separator(ctx)
                reaper.ImGui_Text(ctx, 'Force Update:')

                _, proj_table.is_force_goto = reaper.ImGui_Checkbox(ctx, 'Use Force Marks', proj_table.is_force_goto)
                if proj_table.is_force_goto then 
                    _, proj_table.force_identifier = reaper.ImGui_InputText(ctx, '##inputforcename', proj_table.force_identifier)
                    ToolTip(true, 'Force Marker identifier. Start the marker name with this identifier and then add an goto command like: #force next or #force prev. \nPossible Commands are: \n\nnext=next at playlist.\nprev=prev at playlist\nrandom=random at playlist(filter current region)\nrandom_with_rep=random at playlist\ngoto..regionidx = goto a playlist idx\npos..seconds= go to a certain time in seconds\nqn..value = goto a certain position in quarter note\nbar..barnumber = goto a certainbar\nmark..mark_index = goto a certain mark\nretion..region_index = goto a region index\n\nCan also use {} to have multiple options that will chosen randomly, like {next,prev,prev,random} will choose randomly between this 4 options',300) 
                end

                TempGotoProjSettings = true -- save on close

                reaper.ImGui_EndMenu(ctx)
            elseif TempGotoProjSettings then
                SaveProjectSettings(FocusedProj, ProjConfigs[FocusedProj])
                TempGotoProjSettings = nil
            end

            if reaper.ImGui_BeginMenu(ctx, 'Goto Settings') then
                local _
                _, UserConfigs.tooltips = reaper.ImGui_MenuItem(ctx, 'Show ToolTips', optional_shortcutIn, UserConfigs.tooltips)
                
                _, UserConfigs.only_focus_project = reaper.ImGui_Checkbox(ctx, 'Only Focused Project', UserConfigs.only_focus_project)
                ToolTip(true, 'Only trigger ReaGoTo at the focused project.')

                _, UserConfigs.trigger_when_paused = reaper.ImGui_Checkbox(ctx, 'Execute when not playing.', UserConfigs.trigger_when_paused)
                ToolTip(true, 'Execute goto action immediately when REAPER is not playing.')
    
                _, UserConfigs.add_markers = reaper.ImGui_Checkbox(ctx, 'Add Markers When Trigger', UserConfigs.add_markers)
                ToolTip(true, 'Mostly to debug where it is triggering the goto action.')

                reaper.ImGui_Separator(ctx)
                if reaper.ImGui_BeginMenu(ctx, 'Advanced') then
                    reaper.ImGui_Text(ctx, 'Compensate Defer. Default is 2')
                    _, UserConfigs.compensate = reaper.ImGui_InputDouble(ctx, '##CompensateValueinput', UserConfigs.compensate, 0, 0, '%.2f')
                    UserConfigs.compensate = UserConfigs.compensate > 1 and UserConfigs.compensate or 1
                    ToolTip(true, 'Compensate the defer instability. The bigger the compensation the earlier it will change playback position before the marker/region. The shorter more chances to not get the triggering point. NEVER SMALLER THAN 1!!')
    
                    reaper.ImGui_Text(ctx, 'Smooth seek anticipate (ms). Default is 0.350')
                    _,  SmoothSettings.min_time = reaper.ImGui_InputDouble(ctx, '##antecipatesmooth', SmoothSettings.min_time, 0, 0, '%.3f')
                    ToolTip(true, 'Unfortunatelly REAPER smooth seek have some bugs when the playhead position change just before the triggering moment, this can cause two things:\n\n1) It wont trigger on time\n\n2) It can break REAPER loops.\n\nUntil REAPER fix these bugs the workaround is to change the edit cursor much before the time position. Set the value here, default is 0.350sec if you are experiencing the bugs described increase the value. If you antecipation value is to high to be lower then decrease this value it. With smooth seek markers after the loop start '..tostring(SmoothSettings.min_time)..'sec will have no effect.')

                    reaper.ImGui_EndMenu(ctx)
                end

                TempGoToSettings = true -- to save when close
    
                reaper.ImGui_EndMenu(ctx)
            elseif TempGoToSettings then
                SaveSettings(ScriptPath,SettingsFileName)

                TempGoToSettings = nil
            end



            reaper.ImGui_Separator(ctx)

            if reaper.ImGui_BeginMenu(ctx, 'Reaper Settings') then
                ---- Buffering
                reaper.ImGui_Text(ctx, 'Audio > Buffering')

                reaper.ImGui_Text(ctx, 'Media Buffer Size:')
                local change, num = reaper.ImGui_InputInt(ctx, '##Buffersize', reaper.SNM_GetIntConfigVar( 'workbufmsex', 0 ), 0, 0, 0)
                ToolTip(true, 'Lower Buffer will process the change of takes/change mute state faster, higher buffer settings will result in bigger delays at project changes. For manipulating with the playhead in live scenarios I recommend leaving at 0 or leave it as default and use smooth seek!\n\nREAPER Definition: Media buffering uses RAM and CPU to avoid having to wait for disk IO. For systems with slower disks this should be set higher. Zero disables buffering. Default 1200 ')
                if change then
                    reaper.SNM_SetIntConfigVar( 'workbufmsex', num )
                end
                ----
                reaper.ImGui_Text(ctx, 'Media Buffer Size with take FX :')
                local change, num = reaper.ImGui_InputInt(ctx, '##FxBuffersize', reaper.SNM_GetIntConfigVar( 'workbuffxuims', 0 ), 0, 0, 0)
                ToolTip(true, 'Buffer size when per-take FX are showing.\n\nREAPER Definition: When per-take FX are showing, use a lower media buffer to minimize lag between audio playback and the visual response of the plugin. Default 200')
                if change then
                    reaper.SNM_SetIntConfigVar( 'workbuffxuims', num )
                end
                ----
                local render_configs = reaper.SNM_GetIntConfigVar('workrender', 0)
                local is_anticipate = GetNbit(render_configs,0)

                local retval, new_v = reaper.ImGui_Checkbox(ctx, 'Anticipate FX', is_anticipate)
                if retval then
                    local render_val = ChangeBit(render_configs, 0, (new_v and 1 or 0)) -- 1 bit is the anticipate value
                    reaper.SNM_SetIntConfigVar('workrender', render_val)
                end
                ToolTip(true, 'Render FX ahead. The lower the value more in real time the modifications will take effect, higher values spare more CPU. For live situations manipulating tracks with FX I recommend the lowest as possible. \n\n REAPER Definition: Use spare CPU to render FX ahead of time. This is beneficial regardless of CPU count, but may need to be disabled for use with some plug-ins(UAD). Default: ON')

                if is_anticipate then
                    reaper.ImGui_Text(ctx, 'Anticipate FX Size :')
                    local change, num = reaper.ImGui_InputInt(ctx, '##Renderahead', reaper.SNM_GetIntConfigVar( 'renderaheadlen', 0 ), 0, 0, 0)
                    ToolTip(true, 'Render FX ahead. The lower the value more in real time the modifications will take effect, higher values spare more CPU. For live situations manipulating tracks with FX I recommend the lowest as possible. \n\n REAPER Definition: Use spare CPU to render FX ahead of time. This is beneficial regardless of CPU count, but may need to be disabled for use with some plug-ins(UAD). Default: 200')
                    if change then
                        reaper.SNM_SetIntConfigVar( 'renderaheadlen', num )
                    end
                end

                ---- Seeking
                reaper.ImGui_NewLine(ctx)
                reaper.ImGui_Separator(ctx)
                reaper.ImGui_Text(ctx, 'Audio > Seeking')


                local retval
                retval, SmoothSettings.is_smoothseek = reaper.ImGui_Checkbox(ctx, 'Smooth Seek', SmoothSettings.is_smoothseek)
                if retval then
                    local new_val = ((SmoothSettings.is_smoothseek and 1) or 0) | (((not SmoothSettings.is_bar) and 2) or 0)-- 3 = marker and smooth seek, 1 = bar and smooth seek
                    reaper.SNM_SetIntConfigVar('smoothseek', new_val)
                end
                ToolTip(true, '(Recommended turned on for better playback) With smooth seek it will change the playhead position exactly on the bar/#goto marker, will avoid gaps/stutters on the sound. When using Smooth seek you can only trigger ReaGoto via markers or via bars(unit), not both. REAPER Smooth seek have some bugs, basically it needs '..tostring(SmoothSettings.min_time)..'sec to process an position change, be aware that you need '..tostring(SmoothSettings.min_time)..'sec of antecedence before the triggering point. An #goto maker need to be at least '..tostring(SmoothSettings.min_time)..'sec after the loop start.\n\nIf you are experiencing that it is not triggering where it should, then try to increase the smooth seek antecipate value at Goto Settings>Advanced. \n\nREAPER Definition: Smooth seek enables a more natural-sounding transition.')

                if SmoothSettings.is_smoothseek then
                    if reaper.ImGui_RadioButton(ctx, 'Smooth Seek at Bars', SmoothSettings.is_bar) then
                        SmoothSettings.is_bar = true
                        reaper.SNM_SetIntConfigVar('smoothseek', 1) -- 3 = marker and smooth seek, 1 = bar and smooth seek
                    end
                    ToolTip(true, 'Changing smooth seek to bars will automatically change ReaGoto to trigger at bars. Be aware that Reaper Smooth seek haves some bugs and because of that the size of a measure needs to be bigger than '..tostring(SmoothSettings.min_time)..'sec. If the bar is smaller goto wont be able to trigger. Hopefully REAPER devs will fix the bugs and this feature will have no drawbacks. I really cant do more here.  If you are experiencing the playhead not looping or it not triggering where it should increase the smooth seek antecipate value at Goto Settings>Advanced.')
                    
                    if reaper.ImGui_RadioButton(ctx, 'Smooth Seek at Markers', not SmoothSettings.is_bar) then
                        SmoothSettings.is_bar = false
                        reaper.SNM_SetIntConfigVar('smoothseek', 3) -- 3 = marker and smooth seek, 1 = bar and smooth seek
                    end
                    ToolTip(true, 'Changing smooth seek to markers will automatically change ReaGoto to trigger #goto markers. Be aware that Reaper Smooth seek haves some bugs and because of that #goto at the start of the loop will have no effect, so place the markers at least '..tostring(SmoothSettings.min_time)..'sec away from the beginning of the loop. Hopefully REAPER devs will fix the bugs and this feature will have no drawbacks. I really cant do more here.  If you are experiencing the playhead not looping or it not triggering where it should increase the smooth seek antecipate value at Goto Settings>Advanced.')

                end

                reaper.ImGui_EndMenu(ctx)
            end
            
            reaper.ImGui_EndMenu(ctx)
        end


        if reaper.ImGui_BeginMenu(ctx, 'About') then
            if reaper.ImGui_MenuItem(ctx, 'Donate') then
                open_url('https://www.paypal.com/donate/?hosted_button_id=RWA58GZTYMZ3N')
            end
            ToolTip(true, 'Recommended doantion 20$ - 40$')

            if reaper.ImGui_MenuItem(ctx, 'Forum') then
                open_url('https://forum.cockos.com/showthread.php?t=276313')
            end

            if reaper.ImGui_BeginMenu(ctx, 'Videos') then
                if reaper.ImGui_MenuItem(ctx, 'Introduction') then
                    open_url('https://youtu.be/dyoWlduQIAg')
                end  

                if reaper.ImGui_MenuItem(ctx, 'Layers') then
                    open_url('https://youtu.be/qfoRAYN-1q4')
                end  

                if reaper.ImGui_MenuItem(ctx, 'Alternator') then
                    open_url('https://youtu.be/Oh1xKXGrSFA')
                end  

                if reaper.ImGui_MenuItem(ctx, 'ReaGoTo') then
                    open_url('https://youtu.be/mwXdwAlXXuU')
                end  

                if reaper.ImGui_MenuItem(ctx, 'Advanced Settings') then
                    open_url('https://youtu.be/KWM4EhEz8aY')
                end  

                reaper.ImGui_EndMenu(ctx)
            end
            
            reaper.ImGui_EndMenu(ctx)
        end
        _, GuiSettings.Pin = reaper.ImGui_MenuItem(ctx, 'Pin', optional_shortcutIn, GuiSettings.Pin)

        DockBtn()

        local mark_text, help_text, mark_func, arg
        if  reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl())  then
            mark_text = '-'
            help_text = 'Delete all goto markers at time selection. Hold Shift to also delete force markers.'
            mark_func = DeleteGotoMarkersAtTimeSelection
            if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftShift()) then
                arg = true
            end
        else
            mark_text = '+'
            help_text = 'Add goto marker. Hold Shift to add an force marker. Hold ctrl to delete. '
            mark_func = AddGotoMarker
            if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftShift()) then
                arg = true
            end
        end


        if reaper.ImGui_MenuItem(ctx, mark_text) then
            mark_func(arg)
        end
        ToolTip(true, help_text)

        reaper.ImGui_EndMenuBar(ctx)
    end
end

function MIDILearn(midi_table)
    reaper.ImGui_Text(ctx, 'MIDI:')
    local learn_text = midi_table.is_learn and 'Cancel' or 'Learn'
    if reaper.ImGui_Button(ctx, learn_text, -FLTMIN) then
        midi_table.is_learn = not midi_table.is_learn
    end
    ToolTip(UserConfigs.tooltips,'Trigger with MIDI.')        


    if midi_table.is_learn then
        if MIDIInput[1] then
            local msg_type,msg_ch,val1 = UnpackMIDIMessage(MIDIInput[1].msg)
            if msg_type == 9 or msg_type == 11 or msg_type == 8 then 
                midi_table.type = ((msg_type == 9 or msg_type == 8) and 9) or 11
                midi_table.ch = msg_ch
                midi_table.val1 = val1
                midi_table.device = MIDIInput[1].device
                midi_table.is_learn = false
            end
        end
    end
    
    local w = reaper.ImGui_GetContentRegionAvail(ctx)
    local x_pos = w - 10 -- position of X buttons
    if midi_table.type then 
        local name_type = midi_table.type == 9 and 'Note' or 'CC'
        ImPrint(name_type..' : ',midi_table.val1)
        reaper.ImGui_SameLine(ctx,x_pos)
        if reaper.ImGui_Button(ctx, 'X##all') then
            midi_table.type = nil
            midi_table.ch = nil
            midi_table.val1 = nil
            midi_table.device = nil
            midi_table.is_learn = false
        end
        ToolTip(UserConfigs.tooltips,'Remove the MIDI learned.')        
    end


    if midi_table.ch then 
        ImPrint('Channel : ',midi_table.ch)
        reaper.ImGui_SameLine(ctx,x_pos)
        if reaper.ImGui_Button(ctx, 'X##ch') then
            midi_table.ch = nil
        end
        ToolTip(UserConfigs.tooltips,'Remove the channel filter.')        
    end  

    if midi_table.device then 
        local retval, device_name = reaper.GetMIDIInputName(midi_table.device, '')
        ImPrint('Device : ',device_name)
        reaper.ImGui_SameLine(ctx,x_pos)
        if reaper.ImGui_Button(ctx, 'X##dev') then
            midi_table.device = nil
        end
        ToolTip(UserConfigs.tooltips,'Remove the device filter.')        
    end

end

function MidiPopupButtons(midi_table)
    reaper.ImGui_SetNextWindowSizeConstraints( ctx,  150, -1, FLTMAX, FLTMAX)
    if reaper.ImGui_BeginPopupContextItem(ctx) then
        MIDILearn(midi_table)
        reaper.ImGui_EndPopup(ctx)
    end
end

function CheckMIDITrigger(midi_table)
    local midi_trigger = false
    if midi_table.type and #MIDIInput > 0 then
        for index, input_midi_table in ipairs(MIDIInput) do
            local msg_input = input_midi_table.msg
            local msg_type,msg_ch,val1,val2,text,msg = UnpackMIDIMessage(msg_input)
            if msg_type ~= midi_table.type then goto continue end
            if msg_type == 11 and val2 < 60 then goto continue end
            if val1 ~= midi_table.val1 then goto continue end
            if midi_table.ch and msg_ch ~= midi_table.ch then goto continue end
            if midi_table.device and input_midi_table.device ~= midi_table.device then goto continue end
            midi_trigger = true
            break
            ::continue::
        end
    end
    return midi_trigger
end

function AnimationValues()
    if not GUIAnimationStep then 
        GUIAnimationStep = 0  --GUIAnimationTrig value between 0 and 4 pi 

    end
    GUIAnimationStep = (GUIAnimationStep + 0.4) % (4*math.pi)
    GUIButtomAnimationVal = math.sin(GUIAnimationStep) -- value between -1 amd 1     
end