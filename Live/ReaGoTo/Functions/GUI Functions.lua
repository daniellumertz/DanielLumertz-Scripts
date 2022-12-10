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

            -- Popup to rename and delete
            if reaper.ImGui_BeginPopupContextItem(ctx) then 
                is_save = RenamePlaylistPopUp(playlist)
                -- delete
                if reaper.ImGui_Button(ctx, 'Delete Group',-FLTMIN) then
                    reaper.ImGui_CloseCurrentPopup(ctx)
                    table.remove(playlists,playlist_key)
                    is_save = true
                end
                _, playlist.reset = reaper.ImGui_Checkbox(ctx, 'Reset at stop', playlist.reset)
                reaper.ImGui_SameLine(ctx)
                _, playlist.shuffle = reaper.ImGui_Checkbox(ctx, 'Shuffle playlist at end.', playlist.shuffle)

                reaper.ImGui_EndPopup(ctx)
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
            reaper.ImGui_SetNextItemWidth(ctx, 150)
            local retval, p_selected = reaper.ImGui_Selectable(ctx, region_name..'##'..region_idx, region_idx == playlist.current, reaper.ImGui_SelectableFlags_AllowItemOverlap() )

            -- Double Click goto region
            if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx,0) then
                print('se fudeu')
                -- TODO make a goto function here
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
                reaper.SetProjectMarker2( FocusedProj, region_markrgnindexnumber, region_isrgn, region_pos, region_rgnend, TempName )
                TempName = nil
                TempWasOpen  = nil
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
        
            if reaper.ImGui_Button(ctx, 'Add', -FLTMIN) and TempRegionID then
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
    end
    
end

function RenameRegionMarkerPopUp(playlist, k)
    local region_table = playlist[k]
    local _
    reaper.ImGui_Text(ctx, 'Edit name:')
    if reaper.ImGui_IsWindowAppearing(ctx) then
        reaper.ImGui_SetKeyboardFocusHere(ctx)
    end
    _, TempName = reaper.ImGui_InputText(ctx, "##renameinput", TempName)

    -- Chance 
    local change
    reaper.ImGui_SetNextItemWidth(ctx, 30)
    change, region_table.chance = reaper.ImGui_InputInt(ctx, 'Chance##'..k, region_table.chance, 0, 0)
    if region_table.chance < 0 then region_table.chance = 0 end

    -- Loop 

    if region_table.type == 'region' then
        reaper.ImGui_SameLine(ctx)
        _, region_table.loop = reaper.ImGui_Checkbox(ctx, 'Loop Region ##loopcheckbox'..k, region_table.loop)
    end

    -- remove button
    if reaper.ImGui_Button(ctx, 'Remove Region/Marker', -FLTMIN) then
        table.remove(playlist,k) -- remove from the main table
        return true
    end

    -- Enter close popup
    if reaper.ImGui_IsKeyDown(ctx, 13) then
        reaper.ImGui_CloseCurrentPopup(ctx)
    end
end

function RenamePlaylistPopUp(playlist)
    reaper.ImGui_Text(ctx, 'Edit name:')
    if reaper.ImGui_IsWindowAppearing(ctx) then
        reaper.ImGui_SetKeyboardFocusHere(ctx)
    end
    reaper.ImGui_SetNextItemWidth(ctx, -FLTMIN)
    _, playlist.name = reaper.ImGui_InputText(ctx, "##renameinput", playlist.name)
    -- Enter
    if reaper.ImGui_IsKeyDown(ctx, 13) then
        reaper.ImGui_CloseCurrentPopup(ctx)
    end
end

function TriggerButtons(playlists)
    local function triggered_button_style(is_trigger)
        if is_trigger then 
        end

    end
    local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
    local button_gap = 8
    local button_cnt = 3
    local button_size = ((avail_w-((button_cnt-1)*button_gap))/button_cnt)

    if reaper.ImGui_Button(ctx, '<',button_size) then
        SetGoTo(FocusedProj, 'prev')
    end
    reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, '?',button_size) then
        SetGoTo(FocusedProj, 'random')
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, '>',button_size) then
        SetGoTo(FocusedProj, 'next')
    end
    --_, _ = reaper.ImGui_InputText(ctx, '##gototext', 'buf') --TODO optional goto personalized
    --reaper.ImGui_SameLine(ctx)
    --reaper.ImGui_Button(ctx, 'Go To',-FLTMIN)

    if ProjConfigs[FocusedProj].is_triggered and reaper.ImGui_Button(ctx, 'Cancel Trigger',-FLTMIN) then
        SetGoTo(FocusedProj, false)
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
            _, UserConfigs.only_focus_project = reaper.ImGui_MenuItem(ctx, 'Only Focused Project', optional_shortcutIn, UserConfigs.only_focus_project)
            ToolTip(true, 'Only trigger at the focused project, if more project are open they will consume less resources.')
            _, UserConfigs.trigger_when_paused = reaper.ImGui_MenuItem(ctx, 'Execute when not playing.', optional_shortcutIn, UserConfigs.trigger_when_paused)
            ToolTip(true, 'Execute goto action immediately when  REAPER is not playing.')

            _, UserConfigs.add_markers = reaper.ImGui_MenuItem(ctx, 'Add Markers When Trigger', optional_shortcutIn, UserConfigs.add_markers)
            reaper.ImGui_Separator(ctx)
            if reaper.ImGui_BeginMenu(ctx, 'Advanced') then
                reaper.ImGui_Text(ctx, 'Compensate Defer. Default is 2')
                _, UserConfigs.compensate = reaper.ImGui_InputDouble(ctx, '##CompensateValueinput', UserConfigs.compensate, 0, 0, '%.2f')
                UserConfigs.compensate = UserConfigs.compensate > 1 and UserConfigs.compensate or 1 
                ToolTip(true, 'Compensate the defer instability. The bigger the compensation the earlier it will change before the loop end. The shorter more chances to not get the loop section, the muting/unmutting take some time to work, so it is better to do it a little earlier. NEVER SMALLER THAN 1!!')

                reaper.ImGui_EndMenu(ctx)
            end

            if reaper.ImGui_BeginMenu(ctx, 'Reaper Settings') then
                reaper.ImGui_Text(ctx, 'Media Buffer Size:')
                local change, num = reaper.ImGui_InputInt(ctx, '##Buffersize', reaper.SNM_GetIntConfigVar( 'workbufmsex', 0 ), 0, 0, 0)
                ToolTip(true, 'Lower Buffer will process the change of takes/change mute state faster, higher buffer settings will result in bigger delays to mute and unmute. For manipulating with audio items in live scenarios I recommend leaving at 0\n\nREAPER Definition: Media buffering uses RAM and CPU to avoid having to wait for disk IO. For systems with slower disks this should be set higher. Zero disables buffering. Default 1200 ')
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
                reaper.ImGui_Separator(ctx) -------
                ----
                reaper.ImGui_Text(ctx, 'Anticipate FX :')
                local change, num = reaper.ImGui_InputInt(ctx, '##Renderahead', reaper.SNM_GetIntConfigVar( 'renderaheadlen', 0 ), 0, 0, 0)
                ToolTip(true, 'Render FX ahead. The lower the value more in real time the modifications will take effect, higher values spare more CPU. For live situations manipulating tracks with FX I recommend the lowest as possible. \n\n REAPER Definition: Use spare CPU to render FX ahead of time. This is beneficial regardless of CPU count, but may need to be disabled for use with some plug-ins(UAD)')
                if change then
                    reaper.SNM_SetIntConfigVar( 'renderaheadlen', num )
                end


                reaper.ImGui_EndMenu(ctx)
            end
            
            reaper.ImGui_EndMenu(ctx)
        end

        if reaper.ImGui_BeginMenu(ctx, 'About') then
            if reaper.ImGui_MenuItem(ctx, 'Donate') then
                open_url('https://www.paypal.com/donate/?hosted_button_id=RWA58GZTYMZ3N')
            end

            --if reaper.ImGui_MenuItem(ctx, 'Forum') then
            --    open_url('https://forum.cockos.com/showthread.php?p=2606674#post2606674')
            --end

            reaper.ImGui_EndMenu(ctx)
        end
        _, GuiSettings.Pin = reaper.ImGui_MenuItem(ctx, 'Pin', optional_shortcutIn, GuiSettings.Pin)

        DockBtn()

        reaper.ImGui_EndMenuBar(ctx)
    end
end