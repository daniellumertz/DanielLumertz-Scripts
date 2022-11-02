--@noindex

function GuiInit()
    ctx = reaper.ImGui_CreateContext(ScriptName)
    -- set the font
    --- Text Font
    TextFont = reaper.ImGui_CreateFont(ScriptPath..'Fonts/Poppins-Regular.ttf', 18)
    reaper.ImGui_AttachFont(ctx, TextFont)
    --- Set Initital Values
    Gui_W, Gui_H = 215, 350
    Flags = reaper.ImGui_WindowFlags_NoScrollbar() -- Flags for the main window
    BtnSize = 25
end


function loop()
    PushStyle()
    --demo.PushStyle(ctx)
    --demo.ShowDemoWindow(ctx)

    if not reaper.ImGui_IsAnyItemActive(ctx) then
        PassKeys()
    end

    reaper.ImGui_SetNextWindowSize(ctx, Gui_W, Gui_H, reaper.ImGui_Cond_Once())
    reaper.ImGui_SetNextWindowSizeConstraints(ctx, 187, 280, 300, 1920)

    reaper.ImGui_PushFont(ctx, TextFont)
    local visible, open = reaper.ImGui_Begin(ctx, ScriptName..' '..Version, true, Flags)
    if visible then
        local retval 

        if reaper.ImGui_BeginPopupContextItem(ctx) then
            retval, Settings.Tips = reaper.ImGui_MenuItem(ctx, 'Show Tooltips', nil, Settings.Tips, nil)
            reaper.ImGui_EndPopup(ctx)
        end
        -------- Get
        local cur_w, cur_h = reaper.ImGui_GetWindowSize(ctx)
        -------- GUI
        if reaper.ImGui_Button(ctx, 'Add Markers at Items', -1, BtnSize) then
            ApplyMarkersToItems()
        end
        ToolTip(Settings.Tips, 'Add markers at the start of each item, using item colors')

        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_Button(ctx, 'Get Notes', -1, BtnSize) then
            MarkersList = MakeMarkersList(IsSelected,FilterMuted)
        end
        ToolTip(Settings.Tips, 'Get Notes from the selected items and add them to the Fake Grids notes settings.')
        notes_rc()

        if reaper.ImGui_Button(ctx, 'Add Markers at Notes', -1, BtnSize) then
            ApplyMarkers(MarkersList,IsSelected,FilterMuted)
        end
        ToolTip(Settings.Tips, 'Add markers at the start of each note from the selected items, using colors and names defined at the Fake Grids notes settings.')
        notes_rc()

        reaper.ImGui_Separator(ctx)

        if reaper.ImGui_Button(ctx, 'Delete Markers', -1, BtnSize) then
            DeleteMarkers()
        end
        ToolTip(Settings.Tips, 'Delete all markers created from Fake Grids.')


        if reaper.ImGui_Button(ctx, 'Subdivide', cur_w*2/3, BtnSize) then
            ApplyMarkersSubdivide()
        end
        ToolTip(Settings.Tips, 'Add markers in between the Fake Grids markers.')

        if reaper.ImGui_BeginPopupContextItem(ctx) then
            retval, Sub.color = reaper.ImGui_ColorEdit3( ctx, '##subcoloredit', Sub.color, reaper.ImGui_ColorEditFlags_NoInputs())
            ToolTip(Settings.Tips, 'Choose the color for the subdivisions.')

            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 50)
            retval, Sub.name = reaper.ImGui_InputText(ctx, '##subtext', Sub.name)
            ToolTip(Settings.Tips, 'Choose the name for the subdivisions.')


            if reaper.ImGui_Button(ctx, 'Delete Subdivisions') then 
                DeleteSubMarkers()
            end
            ToolTip(Settings.Tips, 'Delete all subdivisions markers.')


            reaper.ImGui_EndPopup(ctx)
        end

        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_SetNextItemWidth(ctx, -1)
        retval, Sub.divisions = reaper.ImGui_InputInt(ctx, '##sub', Sub.divisions, 0)
        ToolTip(Settings.Tips, 'Set the number of divisions between the Fake Grids markers. 2 = dividing in half; 3 = dividing in thirds; etc.')

        if retval then
            Sub.divisions = LimitNumber(Sub.divisions, 2)
        end

        if reaper.ImGui_BeginChild(ctx, 'Child', -1, -1,true) then
            for index, mark_options_table in ipairs(MarkersList) do
                local retval
                local name = NumberToNote(mark_options_table.note, IsSharp, true)
                retval, mark_options_table.on = reaper.ImGui_Checkbox(ctx, "##check"..index, mark_options_table.on)
                ToolTip(Settings.Tips, 'Enable or disable the marker for every '..name..' note.')

                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_Text(ctx, name)

                reaper.ImGui_SameLine(ctx,74) -- hard code 74 as the biggest poistion needed for the note name 
                --ToolTip(true, reaper.ImGui_GetCursorPosX(ctx)) test the position needed
                retval, mark_options_table.color = reaper.ImGui_ColorEdit3( ctx, '##coloredit'..index, mark_options_table.color, reaper.ImGui_ColorEditFlags_NoInputs() )
                ToolTip(Settings.Tips, 'Choose the color for the markers for every '..name..' note.')
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_SetNextItemWidth(ctx, -1)
                retval, mark_options_table.name = reaper.ImGui_InputText(ctx, '##text'..index, mark_options_table.name)
                ToolTip(Settings.Tips, 'Choose the name for the markers for every '..name..' note.')
            end
            reaper.ImGui_EndChild(ctx)
        end

        -------- GUI
        reaper.ImGui_End(ctx)
    end
    reaper.ImGui_PopFont(ctx)

    --demo.PopStyle(ctx)
    PopStyle()

    if open then
        reaper.defer(loop)
    end
end

function notes_rc()
    if reaper.ImGui_BeginPopupContextItem(ctx) then
        retval, IsSharp = reaper.ImGui_Checkbox(ctx, 'Show Notes as Sharp', IsSharp)
        retval, IsSelected = reaper.ImGui_Checkbox(ctx, 'Only to selected notes', IsSelected)
        retval, FilterMuted = reaper.ImGui_Checkbox(ctx, 'Filter muted notes ', FilterMuted)
        reaper.ImGui_EndPopup(ctx)
    end
end