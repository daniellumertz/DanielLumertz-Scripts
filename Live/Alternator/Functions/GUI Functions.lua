-- @noindex
function GuiInit(ScriptName)
    ctx = reaper.ImGui_CreateContext(ScriptName, reaper.ImGui_ConfigFlags_DockingEnable()) -- Add VERSION TODO
    --- Text Font
    FontText = reaper.ImGui_CreateFont('sans-serif', 14) -- Create the fonts you need
    reaper.ImGui_Attach(ctx, FontText)-- Attach the fonts you need
    --- Smaller Font for smaller widgets
    FontTiny = reaper.ImGui_CreateFont('sans-serif', 12) 
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
            ToolTip(UserConfigs.tooltips,'This is an alternator Group. Right click to rename/delete.')        

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
        ToolTip(UserConfigs.tooltips,'Create a new Alternator Group.')        


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
    local open = reaper.ImGui_BeginCombo(ctx, '##ComboMode', text)
    ToolTip(UserConfigs.tooltips,'Alternator group mode')        
    if open then
        if reaper.ImGui_Selectable(ctx, 'Random', false) then
            group.mode = 0
            is_save = true
        end
        if reaper.ImGui_Selectable(ctx, 'Shuffle', false) then
            group.mode = 1
            group.used_idx = TableiCopy(group) -- reset it 
            is_save = true
        end
        if reaper.ImGui_Selectable(ctx, 'Playlist', false) then
            group.mode = 2
            is_save = true
        end
        reaper.ImGui_EndCombo(ctx)
    end

    -- Button
    if reaper.ImGui_Button(ctx, "Get Selected Takes", -FLTMIN) then
        if reaper.ImGui_GetKeyMods(ctx)  ==  reaper.ImGui_Mod_Ctrl() then
            AddToGroup(group)
        else
            SetGroup(group)
        end
        is_save = true
    end
    ToolTip(UserConfigs.tooltips,'Set Group items to the selected items. Hold ctrl to add to the group')        

    -- Each take
    local avail_x, avail_y = reaper.ImGui_GetContentRegionAvail(ctx)
    local line_size = reaper.ImGui_GetTextLineHeight(ctx)
    local ci_size = 55 --chance_input_size
    if reaper.ImGui_BeginChild(ctx, 'GroupSelect', -FLTMIN, avail_y-line_size*2, true) then
        for k, v in ipairs(group) do
            local take = v.take
            local child_table = v.child_takes

            -- Each take name display:
            local retval, take_name = reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', '', false)
            local cur_x, cur_y = reaper.ImGui_GetCursorScreenPos(ctx)
            reaper.ImGui_PushClipRect(ctx, cur_x, cur_y, cur_x+avail_x-ci_size, cur_y+600, true) -- Clip the selectable text in case take name is long
            reaper.ImGui_SetNextItemWidth(ctx, 150)
            local retval, p_selected = reaper.ImGui_Selectable(ctx, take_name..'##'..tostring(take)..k, k == group.selected+1, reaper.ImGui_SelectableFlags_AllowItemOverlap())
            reaper.ImGui_PopClipRect(ctx)
            ToolTip(UserConfigs.tooltips,'Right Click for more options. Drag to reorder.\nDouble click to select + enable.\nShift + double click to select the item and child items.')        


            -- rename / delete take popup
            if reaper.ImGui_BeginPopupContextItem(ctx) then
                TempWasOpen = k
                local is_del = RenameTakePopUp(group, k, take_name)
                if is_del then -- take was removed from table
                    TempName = nil
                    TempWasOpen  = nil
                    is_save = true
                end
                reaper.ImGui_EndPopup(ctx)
            elseif TempWasOpen == k then
                if TempName ~= take_name then
                    reaper.Undo_BeginBlock2(FocusedProj)
                    retval, take_name = reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', TempName, true)
                    reaper.Undo_EndBlock2(FocusedProj, 'Rename Take', -1)
                end
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
                    group.used_idx = TableiCopy(group) -- reset it 
                else
                    local to_be_selected = {}
                    table.insert(to_be_selected, reaper.GetMediaItemTake_Item(take)) -- main item
                    for child_idx, child_take in ipairs(child_table) do
                        table.insert(to_be_selected, reaper.GetMediaItemTake_Item(child_take))
                    end
                    SetItemSelected(FocusedProj, to_be_selected, true)
                end

                reaper.UpdateArrange()
            end

            -- Probability box
            local change
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetCursorPosX(ctx, Gui_W-ci_size) -- change that to something flexible
            --reaper.ImGui_SetCursorPosX(ctx, Gui_W-110) -- change that to something flexible
            --reaper.ImGui_Text(ctx, 'Chance: ')
            --reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, -FLTMIN)
            local current_y = reaper.ImGui_GetCursorPosY(ctx)
            reaper.ImGui_PushFont(ctx, FontTiny)
            reaper.ImGui_SetCursorPosY(ctx, current_y-2)
            change, v.chance = reaper.ImGui_InputInt(ctx, '##'..take_name..k, v.chance, 0, 0)
            reaper.ImGui_PopFont(ctx)
            is_save = change or is_save
            if v.chance < 0 then v.chance = 0 end
            ToolTip(UserConfigs.tooltips,'When the mode is "Random" use this to set the chance. At other modes set to 0 to disable this take.')        
        end
        reaper.ImGui_EndChild(ctx)
    end

    -- Triggers checkboxes
    local change
    change, group.doatstop = reaper.ImGui_Checkbox(ctx, 'At Stop', group.doatstop)
    ToolTip(UserConfigs.tooltips,'When pausing/stopping it will trigger.')        

    is_save = change or is_save
    reaper.ImGui_SameLine(ctx)
    change, group.doatloop = reaper.ImGui_Checkbox(ctx, 'At Loop', group.doatloop)
    ToolTip(UserConfigs.tooltips,'When looping it will trigger.')        

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
    ToolTip(UserConfigs.tooltips,'Click = Trigger focused group. Hold Ctrl to trigger all groups.')        

end

function RenameGroupPopUp(group)
    reaper.ImGui_Text(ctx, 'Edit group name:')
    if reaper.ImGui_IsWindowAppearing(ctx) then
        reaper.ImGui_SetKeyboardFocusHere(ctx)
    end
    _, group.name = reaper.ImGui_InputText(ctx, "##renameinput", group.name)
    -- Enter
    if reaper.ImGui_IsKeyDown(ctx, 13) then
        reaper.ImGui_CloseCurrentPopup(ctx)
    end
end

function RenameTakePopUp(group, k, take_name)
    reaper.ImGui_Text(ctx, 'Edit take name:')
    if reaper.ImGui_IsWindowAppearing(ctx) then
        TempName = take_name -- Temporary holds the name as the user writes
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
    -- Show Child
    reaper.ImGui_Separator(ctx)
    if reaper.ImGui_BeginMenu(ctx, 'Child Takes') then

        MenuChildTakes(group,k)
        
        reaper.ImGui_EndMenu(ctx)
    end
    -- Enter close popup
    if reaper.ImGui_IsKeyDown(ctx, 13) then
        reaper.ImGui_CloseCurrentPopup(ctx)
    end
end

function MenuChildTakes(group,k)
    local w = 200
    local take_table = group[k]
    local child_table = take_table.child_takes
    -- Button to add Child
    if reaper.ImGui_Button(ctx, 'Get Selected Takes', w) then -- if holding alt then add
        if reaper.ImGui_GetKeyMods(ctx)  ==  reaper.ImGui_Mod_Ctrl() then
            Add_ChildTakes(take_table) 
        else
            Set_ChildTakes(take_table)
        end
    end
    ToolTip(UserConfigs.tooltips,'Set child items to the selected items. Hold ctrl to add to the child group')        

    -- Manage Current Child
    for child_idx, child_take in ipairs(child_table) do
        local retval, take_name = reaper.GetSetMediaItemTakeInfo_String(child_take, 'P_NAME', '', false)
        local open_menu = reaper.ImGui_BeginMenu(ctx, take_name..'###'..tostring(child_take))
        ToolTip(UserConfigs.tooltips,'Double click to select child item in arrange.')        
        if open_menu then
            --Rename
            reaper.ImGui_Text(ctx, 'Edit take name:')
            reaper.ImGui_SetNextItemWidth(ctx, w)
            local change, new_name = reaper.ImGui_InputText(ctx, "##renameinput"..tostring(child_take), take_name)
            if change then 
                local retval, _ = reaper.GetSetMediaItemTakeInfo_String(child_take, 'P_NAME', new_name, true)
            end
            -- Delete
            if reaper.ImGui_Button(ctx, 'Remove Child Take', w) then
                table.remove(child_table,child_idx)
            end

            reaper.ImGui_EndMenu(ctx)
        end    
        -- Double click to select the child item
        if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            local chil_item = reaper.GetMediaItemTake_Item(child_take)
            SetItemSelected(FocusedProj, chil_item, true)
            reaper.UpdateArrange()
            
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
            _, UserConfigs.only_focus_project = reaper.ImGui_MenuItem(ctx, 'Only Focused Project', optional_shortcutIn, UserConfigs.only_focus_project)
            ToolTip(true, 'Only trigger at the focused project, if more project are open they will consume less resources.')

            _, UserConfigs.add_markers = reaper.ImGui_MenuItem(ctx, 'Add Markers When Trigger', optional_shortcutIn, UserConfigs.add_markers)
            ToolTip(true, 'Mostly to debug where it is triggering the goto action.')

            _, UserConfigs.tooltips = reaper.ImGui_MenuItem(ctx, 'Show tooltips', optional_shortcutIn, UserConfigs.tooltips)


            reaper.ImGui_Separator(ctx)
            if reaper.ImGui_BeginMenu(ctx, 'Advanced') then
                reaper.ImGui_Text(ctx, 'Compensate Defer. Default is 2')
                _, UserConfigs.compensate = reaper.ImGui_InputDouble(ctx, '##CompensateValueinput', UserConfigs.compensate, 0, 0, '%.2f')
                UserConfigs.compensate = UserConfigs.compensate > 1 and UserConfigs.compensate or 1 
                ToolTip(true, 'Compensate the defer instability. The bigger the compensation the earlier it will change before the loop end. The shorter more chances to not get the loop section, the muting/unmutting take some time to work, so it is better to do it a little earlier. NEVER SMALLER THAN 1!!')

                reaper.ImGui_EndMenu(ctx)
            end

            if reaper.ImGui_BeginMenu(ctx, 'Reaper Settings') then
                ---- Buffering
                reaper.ImGui_Text(ctx, 'Audio > Buffering')

                reaper.ImGui_Text(ctx, 'Media Buffer Size:')
                local change, num = reaper.ImGui_InputInt(ctx, '##Buffersize', reaper.SNM_GetIntConfigVar( 'workbufmsex', 0 ), 0, 0, 0)
                ToolTip(true, 'Lower Buffer will process the change of takes/change mute state faster, higher buffer settings will result in bigger delays at project changes. For manipulating with audio items in live scenarios I recommend leaving at 0\n\nREAPER Definition: Media buffering uses RAM and CPU to avoid having to wait for disk IO. For systems with slower disks this should be set higher. Zero disables buffering. Default 1200 ')
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

        reaper.ImGui_EndMenuBar(ctx)
    end
end


