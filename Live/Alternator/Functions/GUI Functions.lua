-- @noindex
function GuiInit(ScriptName)
    ctx = reaper.ImGui_CreateContext(ScriptName, reaper.ImGui_ConfigFlags_DockingEnable()) -- Add VERSION TODO
    --- Text Font
    FontText = reaper.ImGui_CreateFont('sans-serif', 14) -- Create the fonts you need
    reaper.ImGui_Attach(ctx, FontText)-- Attach the fonts you need
    --- Smaller Font for smaller widgets
    FontTiny = reaper.ImGui_CreateFont('sans-serif', 10) 
    reaper.ImGui_Attach(ctx, FontTiny)
end

function GroupSelector(groups)
    -- calculate positions
    local _
    -- tabs
    if reaper.ImGui_BeginTabBar(ctx, 'Groups', reaper.ImGui_TabBarFlags_Reorderable() | reaper.ImGui_TabBarFlags_AutoSelectNewTabs() ) then
        local is_save
        for group_key, group in ipairs(groups) do
            local open, keep = reaper.ImGui_BeginTabItem(ctx, ('%s###tab%d'):format(group.name, group_key), false) -- Start each tab

            -- Popup to rename
            if reaper.ImGui_BeginPopupContextItem(ctx) then 
                RenameGroupPopUp(group)
                if reaper.ImGui_Button(ctx, 'Delete Group',-FLTMIN) then
                    reaper.ImGui_CloseCurrentPopup(ctx)
                    table.remove(groups,group_key)
                    is_save = true
                end
                reaper.ImGui_EndPopup(ctx)
            end

            -- Show takes inside this group
            if open then
                TakeTab(group)
                reaper.ImGui_EndTabItem(ctx) 
            end

        end
        -- Add Group
        if reaper.ImGui_TabItemButton(ctx, '+', reaper.ImGui_TabItemFlags_Trailing() | reaper.ImGui_TabItemFlags_NoTooltip()) then -- Start each tab
            table.insert(groups,CreateNewGroup('G'..#groups+1))
            is_save = true
        end

        if is_save then -- Save settings
            SaveProjectSettings(FocusedProj, ProjConfigs[FocusedProj])
        end
        
        reaper.ImGui_EndTabBar(ctx)
    end
end

function TakeTab(group)
    local is_save -- if something changed than save
    -- Mode
    local text = (group.mode == 0 and 'Random') or (group.mode == 1 and 'Shuffle') or (group.mode == 2 and 'Playlist')
    reaper.ImGui_SetNextItemWidth(ctx, -FLTMIN)
    if reaper.ImGui_BeginCombo(ctx, '##ComboMode', text) then
        if reaper.ImGui_Selectable(ctx, 'Random', false) then
            group.mode = 0
            is_save = true
        end
        if reaper.ImGui_Selectable(ctx, 'Shuffle', false) then
            group.mode = 1
            is_save = true
        end
        if reaper.ImGui_Selectable(ctx, 'Playlist', false) then
            group.mode = 2
            is_save = true
        end
        reaper.ImGui_EndCombo(ctx)
    end

    -- Button
    if reaper.ImGui_Button(ctx, "Get Selected Items", -FLTMIN) then
        if reaper.ImGui_GetKeyMods(ctx)  ==  reaper.ImGui_Mod_Ctrl() then
            AddToGroup(group)
        else
            SetGroup(group)
        end
        is_save = true
    end

    -- Each take
    local avail_x, avail_y = reaper.ImGui_GetContentRegionAvail(ctx)
    local line_size = reaper.ImGui_GetTextLineHeight(ctx)
    if reaper.ImGui_BeginChild(ctx, 'GroupSelect', -FLTMIN, avail_y-line_size*2, true) then
        for k, v in ipairs(group) do
            local take = v.take

            -- Each take name display:
            local retval, take_name = reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', '', false)
            reaper.ImGui_SetNextItemWidth(ctx, 150)
            local retval, p_selected = reaper.ImGui_Selectable(ctx, take_name..'##'..k, k == group.selected+1, reaper.ImGui_SelectableFlags_AllowItemOverlap())


            -- rename / delete take popup
            if reaper.ImGui_BeginPopupContextItem(ctx) then
                TempWasOpen = k
                TempName = take_name -- Temporary holds the name as the user writes
                local is_del = RenameTakePopUp(group, k)
                if is_del then -- take was removed from table
                    TempName = nil
                    TempWasOpen  = nil
                    is_save = true
                end
                reaper.ImGui_EndPopup(ctx)
            elseif TempWasOpen == k then
                retval, take_name = reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', TempName, true)
                TempName = nil
                TempWasOpen  = nil
            end
            

            -- Drag
            if reaper.ImGui_BeginDragDropSource(ctx, reaper.ImGui_DragDropFlags_None()) then
                -- Set payload to carry the index of our take (could be anything)
                reaper.ImGui_SetDragDropPayload(ctx, 'TAKESLIST', tostring(k))
        
                reaper.ImGui_EndDragDropSource(ctx)
            end
            -- Drop
            if reaper.ImGui_BeginDragDropTarget(ctx) then
                local payload, rv
                rv,payload = reaper.ImGui_AcceptDragDropPayload(ctx, 'TAKESLIST')
                if rv then
                    local source_idx = tonumber(payload) -- source idx
                    local move_val = group[source_idx] -- Source val
   
                    table.remove(group,source_idx)
                    table.insert(group,k,move_val)
                    is_save = true
                end
                reaper.ImGui_EndDragDropTarget(ctx)
            end

            --Double Click Select and enable 
            if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
                if not (reaper.ImGui_GetKeyMods(ctx) == reaper.ImGui_Mod_Shift()) then
                    AlternateSelectTake(group,k)
                end
                local item = reaper.GetMediaItemTake_Item(take)
                --SetItemSelected()
                reaper.SelectAllMediaItems( FocusedProj, false )
                reaper.SetMediaItemSelected(item, true)
                local start_time, end_time = reaper.GetSet_ArrangeView2( FocusedProj, false, 0, 0, 0, 0 )
                local pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
                if pos < start_time or pos > end_time then -- Item out of view, center the view at the item start
                    local pad = 2/3
                    local len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
                    local dif = end_time - start_time
                    start_time, end_time = reaper.GetSet_ArrangeView2( FocusedProj, true, 0, 0, pos-(dif*1/3), pos+(dif*2/3))
                end
                reaper.UpdateArrange()
            end

            -- Probability box
            local change
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetCursorPosX(ctx, Gui_W-110) -- change that to something flexible
            reaper.ImGui_Text(ctx, 'Chance: ')
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 30)
            change, v.chance = reaper.ImGui_InputInt(ctx, '##'..take_name..k, v.chance, 0, 0)
            is_save = change or is_save
            if v.chance < 0 then v.chance = 0 end
        end
        reaper.ImGui_EndChild(ctx)
    end

    -- Triggers checkboxes
    local change
    change, group.doatstop = reaper.ImGui_Checkbox(ctx, 'At Stop', group.doatstop)
    is_save = change or is_save
    reaper.ImGui_SameLine(ctx)
    change, group.doatloop = reaper.ImGui_Checkbox(ctx, 'At Loop', group.doatloop)
    is_save = change or is_save
    if is_save then -- Save settings
        SaveProjectSettings(FocusedProj, ProjConfigs[FocusedProj])
    end

    reaper.ImGui_SameLine(ctx, Gui_W - 50)
    if reaper.ImGui_Button(ctx, 'Do it', -FLTMIN) then
        if reaper.ImGui_GetKeyMods(ctx)  ==  reaper.ImGui_Mod_Ctrl() then
            AlternateItems(ProjConfigs[FocusedProj].groups,true)
        else
            AlternateItems({group},true)
        end
    end
end

function RenameGroupPopUp(group)
    reaper.ImGui_Text(ctx, 'Edit name:')
    if reaper.ImGui_IsWindowAppearing(ctx) then
        reaper.ImGui_SetKeyboardFocusHere(ctx)
    end
    _, group.name = reaper.ImGui_InputText(ctx, "##renameinput", group.name)
    -- Enter
    if reaper.ImGui_IsKeyDown(ctx, 13) then
        reaper.ImGui_CloseCurrentPopup(ctx)
    end
end

function RenameTakePopUp(group, k)
    reaper.ImGui_Text(ctx, 'Edit name:')
    if reaper.ImGui_IsWindowAppearing(ctx) then
        reaper.ImGui_SetKeyboardFocusHere(ctx)
    end
    _, TempName = reaper.ImGui_InputText(ctx, "##renameinput", TempName)
    -- remove button
    if reaper.ImGui_Button(ctx, 'Remove Take', -FLTMIN) then
        -- get if this take exist in the shuffle table
        local retval, used_idx = TableHaveValue(group.used_idx, group[k])
        if used_idx then
            table.remove(group.used_idx,used_idx) -- remove from the main table
        end
        -- remove from the main table
        table.remove(group,k) -- remove from the main table
        -- che
        if retval then table.remove(group.used_idx, used_idx) end -- remove from the shuffle table ( if is there )
        return true
    end
    -- Enter close popup
    if reaper.ImGui_IsKeyDown(ctx, 13) then
        reaper.ImGui_CloseCurrentPopup(ctx)
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


