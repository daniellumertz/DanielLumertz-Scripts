--@noindex
DL_Manager = DL_Manager or {}
-- Gui variable
local ctx = ImGui.CreateContext(SCRIPT_NAME..SCRIPT_V)
--- Text Font
local font_text = ImGui.CreateFont('monospace', 24) -- Create the fonts you need
ImGui.Attach(ctx, font_text)-- Attach the fonts you need
local guiW, guiH = 1280,375
local FLT_MIN, FLT_MAX = ImGui.NumericLimits_Float()
local INT_MIN, INT_MAX = ImGui.NumericLimits_Int()
local gui_var = {
    donation_link = "https://www.paypal.com/donate/?hosted_button_id=RWA58GZTYMZ3N",
    counter = 'https://script.google.com/macros/s/AKfycbwBxX9V8NRP-EFNao0jVbCKHns4m-2tY78h40gAm6xH5zkqwbtOCzJYBwAWqrt-KtAXLg/exec',
    proj_button = {
        text = 'Project Path',
        size = 120 
    },
    recursive_checkbox = {
        text = 'Recursive',
        size = 120
    },
    table = {
        header = {
            { name = "Relative Path", key = "path" },
            { name = "Versions", key = "v_count"},
            { name = "Date Modified", key = "mod_time" },
            { name = "Size", key = "size" },
            --{ name = "Type", key = "type" }
        },

        selection_history = { -- each value is a table containing the rows it will change ex: {{1}, {2}, {1,2,3}}

        }
    },

    actions = {
        height = 4 -- in lines
    },

    del_pu = {
        n_items = -1,
        name = 'Delete File Window',
        buttons = {
            del = 'Delete!',
            cancel = 'Cancel'
        },
        w = 475,
        h = 125
    },

    ver_pu = {
        n_items = -1,
        name = 'Limit Version Window',
        buttons = {
            del = 'Delete!',
            cancel = 'Cancel',
            calculate = 'Calculate Changes',
        },
        w = 700,
        h = 135,
        v_limit = 1 
    },

    min_size = {
        w = 750,
        h = 300
    },

    count_ver = {
        bar_w = 100
    }
}
local proj = 0
local ext = reaper.GetExtState('DL_BackupManager', 'Counter') 
if not ext or ext == '' then
    local site = DL.url.CurlFormat(gui_var.counter)
    reaper.ExecProcess(site, 500)
    reaper.SetExtState('DL_BackupManager', 'Counter', 'y', true) 
end 
function DL_Manager.GUI()
    --- Window
    ImGui.SetNextWindowSize(ctx, guiW, guiH, ImGui.Cond_Once)
    ImGui.SetNextWindowSizeConstraints(ctx, gui_var.min_size.w, gui_var.min_size.h, INT_MAX, INT_MAX)
    --ImGui.PushFont(ctx, font_text)
    DL_Manager.Themes.Dark.Push(ctx)
    local window_flags
    local visible, open = ImGui.Begin(ctx, SCRIPT_NAME..' '..SCRIPT_V, true, window_flags) 
    if visible then
        local win_w, win_h = ImGui.GetWindowSize(ctx)
        local win_x, win_y = ImGui.GetWindowPos(ctx)
        do
            ------ Folder Path
            ImGui.SetNextItemWidth(ctx, -FLT_MIN -gui_var.proj_button.size)
            _, DL_Manager.backup.input.path = ImGui.InputText(ctx, '##checkpath', DL_Manager.backup.input.path)
            -- Drag n Drop
            if ImGui.BeginDragDropTarget(ctx) then
                if ImGui.AcceptDragDropPayloadFiles(ctx) then
                    local _, input_path = ImGui.GetDragDropPayloadFile(ctx, 0) -- Will just get the first csv
                    DL_Manager.backup.input.path = input_path
                end
                ImGui.EndDragDropTarget(ctx)
            end
            
            ------ Get proj 
            ImGui.SameLine(ctx)
            --local aw, ah = ImGui.GetContentRegionAvail(ctx)
            if ImGui.Button(ctx, gui_var.proj_button.text, gui_var.proj_button.size - 12) then
                local proj_path = DL.proj.GetFullPath(proj)
                if reaper.file_exists(proj_path) then -- if file does not exist, the project has not been saved. And it will return the documents folder or another directory.
                    print(proj_path)
                    proj_path = DL.files.GetDir(proj_path)
                end
                DL_Manager.backup.input.path = proj_path
            end
        end

        do 
            if DL_Manager.backup.input.path and DL_Manager.backup.input.path ~= '' then
                if ImGui.Button(ctx, 'Search Backup Files', -gui_var.recursive_checkbox.size) then
                    DL_Manager.backup.files = DL_Manager.backup.search(DL_Manager.backup.input.path, DL_Manager.backup.input.extension, DL_Manager.backup.input.recursive)
                    if DL_Manager.backup.files == 0 then
                        reaper.ShowMessageBox( "No backup file found", 'Backup Manager', 0)
                    end
                    DL_Manager.backup.files.path = DL_Manager.backup.input.path
                end

                ImGui.SameLine(ctx)
                --ImGui.SameLine(ctx)
                _, DL_Manager.backup.input.recursive= ImGui.Checkbox(ctx, gui_var.recursive_checkbox.text, DL_Manager.backup.input.recursive)
            end
        end

        ImGui.Separator(ctx)

        -----------------------
        --- TABLE
        -----------------------
        
        -- Handle Commands
        if not ImGui.IsAnyItemFocused(ctx) and #gui_var.table.selection_history > 0 then
            local history = gui_var.table.selection_history
            if ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl) and ImGui.IsKeyPressed(ctx, ImGui.Key_Z, true) then -- CTRL Z
                for k, row in ipairs(history[#history]) do
                    DL_Manager.backup.files[row].select = not DL_Manager.backup.files[row].select 
                end
                history[#history] = nil
            end

            if ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl) and ImGui.IsKeyPressed(ctx, ImGui.Key_A, false) then -- CTRL A
                DL_Manager.backup.SelectAll(nil, history)
            end
        end
        -- Draw
        if #DL_Manager.backup.files > 0 then
            local flags =  ImGui.TableFlags_ScrollY         |
                      ImGui.TableFlags_RowBg           |
                      ImGui.TableFlags_BordersOuter    |
                      ImGui.TableFlags_BordersV        |
                      ImGui.TableFlags_Sortable        |
                      --ImGui.TableFlags_SortMulti       |
                      --ImGui.TableFlags_SortTristate    |
                      ImGui.TableFlags_Reorderable     |
                      ImGui.TableFlags_NoSavedSettings |
                      ImGui.TableFlags_Hideable        |
                      ImGui.TableFlags_Resizable       
                      --ImGui.TableFlags_SizingStretchSame 
                      --ImGui.TableFlags_SizingFixedFit

            local aw, ah = ImGui.GetContentRegionAvail(ctx)
            local table_height = ah - (ImGui.GetFrameHeight(ctx) * gui_var.actions.height)
            if ImGui.BeginTable(ctx, '##Backupfilestable', #gui_var.table.header, flags, 0, table_height) then
                local line_height = 17
                local scr = ImGui.GetScrollY(ctx)
                if type(scr) == 'number' then 
                    ImGui.SetScrollY(ctx, DL.num.Quantize(scr, line_height))
                end
                -- Make Header row always visible
                ImGui.TableSetupScrollFreeze(ctx, 0, 1) 
                -- Header
                for k, v in ipairs(gui_var.table.header) do
                    local name = v.name
                    local flags =  v.key == 'path' and ImGui.TableColumnFlags_WidthStretch or ImGui.TableColumnFlags_WidthFixed   
                    local peso = v.key == 'path' and 20 or -- path 
                              v.key == 'select' and 1 or  -- selected (not used)
                              v.key == 'mod_time' and 140 or  -- time
                              v.key == 'size' and 85 or  -- size
                              v.key == 'type' and 1 or  -- type
                              v.key == 'v_count' and 80 or  -- version count
                              0
                    ImGui.TableSetupColumn(ctx, name..'##k', flags, peso, k)
                end
                ImGui.TableHeadersRow(ctx)

                -- Sort
                if ImGui.TableNeedSort(ctx) then
                    DL_Manager.backup.SortFiles(ctx)
                end

                -- Table
                local history = gui_var.table.selection_history
                local files = DL_Manager.backup.files
                local path = DL_Manager.backup.files.path
                local last_path, last_row = '', -1
                gui_var.table.clipper = ImGui.ValidatePtr( gui_var.table.clipper, "ImGui_ListClipper*" ) and gui_var.table.clipper or ImGui.CreateListClipper(ctx)
                local clipper = gui_var.table.clipper
                ImGui.ListClipper_Begin(clipper, #files)
                while ImGui.ListClipper_Step(clipper) do
                    local display_start, display_end = ImGui.ListClipper_GetDisplayRange(clipper) -- 0 based Return the lines that are visible in the clipper
                    for row = display_start + 1, display_end do
                        ImGui.TableNextRow(ctx) 
                        for k,v in ipairs(gui_var.table.header) do
                            local key = v.key
                            ImGui.TableNextColumn(ctx)
                            local value = files[row][key]
                            if key == 'path' then
                                local text = value
                                -- make it relative:
                                local r_text = text:match('^'..path..'[\\/]*(.+)')
                                -- remove which ever directiories in common with last collumn 
                                local short_text = r_text
                                if last_row == row -1 then -- list clipper always render the first row. We only want to short the name after the >actual< second row. 
                                    short_text = DL_Manager.misc.removeCommonDirectories(last_path, r_text)
                                end
                                last_path, last_row = r_text, row
                                local change, new_val = ImGui.Selectable(ctx, short_text..'##sel '..row, files[row].select, ImGui.SelectableFlags_SpanAllColumns | ImGui.SelectableFlags_AllowOverlap, 0)
                                if ImGui.BeginPopupContextItem(ctx) then
                                    if ImGui.MenuItem(ctx, 'Open in Explorer/Finder') then
                                        DL.files.GoToPath(DL.files.GetDir(files[row].path))
                                    end
                                    if ImGui.MenuItem(ctx, 'Copy Path') then
                                        reaper.CF_SetClipboard( files[row].path )
                                    end
                                    ImGui.EndPopup(ctx)
                                end
                                -- Ctrlz and shift select
                                if change then
                                    if #history > 0 and ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) then
                                        local last_save = history[#history]
                                        local last_row = last_save[#last_save]
                                        local start = math.min(row, last_row)
                                        local finish = math.max(row, last_row)
                                        local undo_state = {}
                                        for i = start, finish do
                                            -- save in the undo only the changed values
                                            if not files[i].select then
                                                undo_state[#undo_state+1] = i
                                            end 
                                            files[i].select = true
                                        end
                                        table.insert(history, undo_state)
                                    else
                                        files[row].select = new_val 
                                        table.insert(history, {row})
                                    end
                                end
                                --ImGui.Text(ctx, short_text)
                            elseif key == 'select' then -- not used
                                --local is_selected = value
                                --_, files[row][key] = ImGui.Checkbox(ctx, '##isselected'..row, is_selected)
                            elseif key == 'mod_time' then
                                local time = value
                                ImGui.Text(ctx, time)
                            elseif key == 'size' then
                                local size = value
                                size = DL.files.formatFileSize(size)
                                local tw = ImGui.CalcTextSize(ctx, size)
                                local w = ImGui.GetContentRegionAvail(ctx)
                                local x = ImGui.GetCursorPosX(ctx)
                                ImGui.SetCursorPosX(ctx, x + (w-tw))
                                ImGui.Text(ctx, size)
                            elseif key == 'v_count' then
                                if type(value) == 'number' then
                                    ImGui.Text(ctx, value)
                                elseif type(value) == 'string' then
                                    ImGui.Text(ctx, '')
                                end
                            end
                        end
                    end
                end

                ImGui.EndTable(ctx)
            end

            ------ Select Buttons
            if ImGui.Button(ctx, 'Select All') then
                local history = gui_var.table.selection_history
                DL_Manager.backup.SelectAll(true, history)
            end
            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, 'Clear Selection') then
                local history = gui_var.table.selection_history
                DL_Manager.backup.SelectAll(false, history)
            end

            local cx, cy = ImGui.GetCursorPos(ctx)
            ---------------------- Del Buttons
            local del_w = 150
            ------ Version Limit
            if DL_version_btn then
                ImGui.SameLine(ctx, aw - (del_w*2 + ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)))
                if ImGui.Button(ctx, 'Limit Versions##button', del_w, -FLT_MIN) then
                    gui_var.ver_pu.n_items, gui_var.ver_pu.items_size = DL_Manager.backup.CountSelected(DL_Manager.backup.files)
                    if gui_var.ver_pu.n_items > 0 then
                        ImGui.OpenPopup(ctx, gui_var.ver_pu.name)
                    else
                        reaper.ShowMessageBox('Select at least one backup file.', 'Error', 0)
                    end
                end
            end
            ------ Delete Button
            ImGui.SameLine(ctx, aw - del_w)
            if ImGui.Button(ctx, 'Delete Files##button', -FLT_MIN, -FLT_MIN) then
                gui_var.del_pu.n_items, gui_var.del_pu.items_size = DL_Manager.backup.CountSelected(DL_Manager.backup.files)
                if gui_var.del_pu.n_items > 0 then
                    ImGui.OpenPopup(ctx, gui_var.del_pu.name)
                else
                    reaper.ShowMessageBox('Select at least one backup file.', 'Error', 0)
                end
            end

            ------ Select Latest Buttons
            ImGui.SetCursorPos(ctx, cx, cy)
            local latest = DL_Manager.backup.actions.keep_latests
            if ImGui.Button(ctx, 'Unselect :') then
                local history = gui_var.table.selection_history
                DL_Manager.backup.SelectNewest(false, latest.n, history)
            end
            ImGui.SameLine(ctx)
            ImGui.SetNextItemWidth(ctx, 50)
            _, latest.n = ImGui.DragInt(ctx, '##keepr', latest.n, 0.01, 1, INT_MAX)
            if ImGui.IsItemDeactivatedAfterEdit(ctx) then
                if latest.n < 1 then
                    latest.n = 1
                end
            end
            ImGui.SameLine(ctx)
            ImGui.Text(ctx, 'Latest Backups For Each Folder.')

            ------ SEARCH bUTTON
            if ImGui.Button(ctx, 'Count Versions', 200) then
                gui_var.AddVersionCountToTable = coroutine.wrap(DL_Manager.backup.AddVersionCountToTable)
            end

            if gui_var.AddVersionCountToTable then
                local is_done, num, total = gui_var.AddVersionCountToTable(DL_Manager.backup.files)
                local stop = is_done
                if not is_done then
                    ImGui.SameLine(ctx)
                    ImGui.ProgressBar(ctx, num/total, gui_var.count_ver.bar_w)
                    ImGui.SameLine(ctx)
                    if ImGui.Button(ctx, 'Cancel') then
                        stop = true
                    end
                end
                if stop then
                    gui_var.AddVersionCountToTable = nil
                end
            end
        end
        DL_Manager.DeletePopUp(win_x, win_y, win_w, win_h)
        DL_Manager.DeleteVersionPopUp(win_x, win_y, win_w, win_h)

        ImGui.End(ctx)
    end
    --ImGui.PopFont(ctx)
    DL_Manager.Themes.Dark.Pop(ctx)

    if open then
        reaper.defer(DL_Manager.GUI)
    end 
end

function DL_Manager.DeletePopUp(win_x, win_y, win_w, win_h)
    local flags = ImGui.WindowFlags_NoResize
    ImGui.SetNextWindowSize(ctx, gui_var.del_pu.w, gui_var.del_pu.h)
    local pos_x = (win_x + (win_w/2)) - (gui_var.del_pu.w/2)
    local pos_y = (win_y + (win_h/2)) - (gui_var.del_pu.h/2)
    ImGui.SetNextWindowPos(ctx, pos_x, pos_y, ImGui.Cond_Appearing)
    if ImGui.BeginPopupModal(ctx, gui_var.del_pu.name, nil, flags) then
        local n_items = gui_var.del_pu.n_items
        local size = DL.files.formatFileSize(gui_var.del_pu.items_size)
        DL.imgui.CenterText(ctx,'Are you sure you want to delete '..n_items..' backup files?')
        DL.imgui.CenterText(ctx,'Total Size: '..size) 
        DL.imgui.CenterText(ctx,'The files will NOT go to your recycle bin!')
        DL.imgui.CenterText(ctx,'There will be no turning back!')

        --- Buttons
        local btns_w = ImGui.CalcTextSize(ctx, gui_var.del_pu.buttons.del) + ImGui.CalcTextSize(ctx, gui_var.del_pu.buttons.cancel) + 2 * (ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding) * 2)
        local aw, ah = ImGui.GetContentRegionAvail(ctx)
        local cx = (aw/2) - (btns_w/2)
        ImGui.SetCursorPosX(ctx, cx)
        if ImGui.Button(ctx, gui_var.del_pu.buttons.del) then
            DL_Manager.backup.DeleteBackups(DL_Manager.backup.files)
            gui_var.table.selection_history = {}
            local answer = reaper.ShowMessageBox('Backup files deleted!\nIf this script was helpful to you, consider making a small donation!\nWould you like to donate now?', 'Backup Manager', 4)
            if answer == 6 then
                DL.url.OpenURL(gui_var.donation_link)
            end
            ImGui.CloseCurrentPopup(ctx)
        end
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, gui_var.del_pu.buttons.cancel) then
            ImGui.CloseCurrentPopup(ctx)
        end
        ImGui.EndPopup(ctx)
    end
end

function DL_Manager.DeleteVersionPopUp(win_x, win_y, win_w, win_h)
    local flags = ImGui.WindowFlags_NoResize
    ImGui.SetNextWindowSize(ctx, gui_var.ver_pu.w, gui_var.ver_pu.h)
    local pos_x = (win_x + (win_w/2)) - (gui_var.ver_pu.w/2)
    local pos_y = (win_y + (win_h/2)) - (gui_var.ver_pu.h/2)
    ImGui.SetNextWindowPos(ctx, pos_x, pos_y, ImGui.Cond_Appearing)
    if ImGui.BeginPopupModal(ctx, gui_var.ver_pu.name, nil, flags) then
        local n_items = gui_var.ver_pu.n_items

        DL.imgui.CenterText(ctx,'This action will remove previous versions stored in backup files containing multiple versions.')
        ----------
        local text = 'Limit backups versions to the most recent '
        local text2 = 'Versions'
        local dw = 30
        ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
        local total_width = ImGui.CalcTextSize(ctx, text) + ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing) + dw + ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemInnerSpacing) + ImGui.CalcTextSize(ctx, text2)
        local avail_w = ImGui.GetContentRegionAvail(ctx)
        ImGui.SetCursorPosX(ctx, avail_w/2 - total_width/2)
        ImGui.Text(ctx,text)
        ImGui.SameLine(ctx)
        ImGui.SetNextItemWidth(ctx, dw)
        _, gui_var.ver_pu.v_limit = ImGui.DragInt(ctx, text2..'##version_dragint', gui_var.ver_pu.v_limit, 0.01, 1, INT_MAX)
        if ImGui.IsItemDeactivatedAfterEdit(ctx) then
            gui_var.ver_pu.v_limit = DL.num.Clamp(gui_var.ver_pu.v_limit, 1)
        end
        --------
        DL.imgui.CenterText(ctx,'Are you sure you want to modfy up to '..n_items..' backup files?')
        DL.imgui.CenterText(ctx,'There will be no turning back!')

        --- Buttons
        local btns_w = ImGui.CalcTextSize(ctx, gui_var.ver_pu.buttons.del) + ImGui.CalcTextSize(ctx, gui_var.ver_pu.buttons.cancel) + ImGui.CalcTextSize(ctx, gui_var.ver_pu.buttons.calculate) + 3 * (ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding) * 2) + 2 * (ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing))
        local aw, ah = ImGui.GetContentRegionAvail(ctx)
        local cx = (aw/2) - (btns_w/2)
        ImGui.SetCursorPosX(ctx, cx)

        if ImGui.Button(ctx, gui_var.del_pu.buttons.del) then
            DL_Manager.backup.DeleteBackupVersions(DL_Manager.backup.files, gui_var.ver_pu.v_limit)
            gui_var.table.selection_history = {}
            ImGui.CloseCurrentPopup(ctx)
        end
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, gui_var.ver_pu.buttons.calculate) then
            local mod_files, n_versions, size = DL_Manager.backup.CalculateLimitBackups(DL_Manager.backup.files, gui_var.ver_pu.v_limit)
            if mod_files and n_versions and size then 
                local msg = 'This action would modfy '..tostring(mod_files)..' files.\nIt would delete '..tostring(n_versions)..' backup versions.\nAnd free up to '..tostring(DL.files.formatFileSize(size))..' .'
                reaper.ShowMessageBox(msg, 'Version Info', 0)
            else
                print('Calculation error.')
            end
        end
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, gui_var.del_pu.buttons.cancel) then
            ImGui.CloseCurrentPopup(ctx)
        end
        ImGui.EndPopup(ctx)
    end
end
