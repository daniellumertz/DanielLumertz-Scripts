--@noindex

-- Get

function MakeMarkersList(is_selected,filter_mute)
    local markers_list = {}
    -- Default values for name, color, turned on
    local name = ''
    local colors = {0x8D8D8D, 0x1A1A19, 0x44981A, 0x96980E, 0x9B1111, 0x0E9598 } 
    local on = true
    -- Get selected pitch classes
    local take_list = {}
    for item in enumSelectedItems() do
        take_list[#take_list+1] = reaper.GetActiveTake(item)
    end
    local pitches = GetSelectedPitches(is_selected,filter_mute,take_list)
    -- Get errors
    if #pitches == 0 then 
        if #take_list == 0 then 
            reaper.ShowMessageBox('Select a MIDI Item', ScriptName, 0)
        else
            reaper.ShowMessageBox('Add/Select Some notes', ScriptName, 0)
        end
        return {}
    end
    for index, note in ipairs(pitches) do
        local t = {
            name = name,
            note = note,
            color = colors[math.random(#colors)],
            on = on
        }
        table.insert(markers_list,t)        
    end

    return markers_list
end

---- Apply

function ApplyMarkers(markers_list,is_selected,filter_mute)
    if #markers_list == 0 then return end
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    
    for item in enumSelectedItems() do
        local take = reaper.GetActiveTake(item)
        for selected, muted, startppqpos, endppqpos, chan, pitch, vel, noteidx in IterateMIDINotes(take) do
            if ((not is_selected) or (is_selected and selected)) and ((not filter_mute) or (filter_mute and not muted)) then -- if passes the script setting
                for index, markers_options in ipairs(markers_list) do -- loop every note in the list until match 
                    if markers_options.note == pitch and markers_options.on then -- if match add a marker and break
                        local new_color = RGBA_To_ReaperRGB(markers_options.color)
                        local pos = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)
                        reaper.AddProjectMarker2(0, false, pos, 0, Identfier..markers_options.name, -1, new_color)
                        break
                    end
                end
            end
        end
    end

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock(ScriptName..': Add markers at MIDI notes.', -1)
end

function ApplyMarkersToItems()
    reaper.Undo_BeginBlock2(0)
    reaper.PreventUIRefresh(1)

    for item in enumSelectedItems() do
        -- get item position
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        -- get item color
        local color = reaper.GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
        
        local retval, num_markers, num_regions = reaper.CountProjectMarkers(proj)
        reaper.AddProjectMarker2(0, false, pos, 0, Identfier, num_markers+1,color)
    end

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    
    reaper.Undo_EndBlock2(0, ScriptName..': Add markers at Items Start.', -1)
end

function ApplyMarkersSubdivide()
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    -- Iterate all markers delete with sub identifier, make a list of markers position
    local cnt, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local positions = {}
    for i = cnt-1, 0, -1  do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers(i)
        if not isrgn and name:match('^'..Identfier) then
            table.insert(positions,pos)
        elseif not isrgn and name:match('^%'..Identfier_sub)  then
            reaper.DeleteProjectMarker(0, markrgnindexnumber, isrgn)
        end
    end

    table.sort(positions)

    for i = 1, #positions-1 do
        local pos = positions[i]
        local next_pos = positions[i+1]
        local length = next_pos - pos
        local sub_length = length / Sub.divisions
        for j = 1, Sub.divisions-1 do
            local sub_pos = pos + (sub_length * j)
            local new_color = RGBA_To_ReaperRGB(Sub.color)
            reaper.AddProjectMarker2(0, false, sub_pos, 0, Identfier_sub..Sub.name, -1, new_color)
        end
    end

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock2(0, ScriptName..': Add markers Fake grids.', -1)

end

--- Delete

function DeleteSubMarkers()
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    -- Iterate all markers delete with sub identifier, make a list of markers position
    local cnt, num_markers, num_regions = reaper.CountProjectMarkers(0)
    for i = cnt-1, 0, -1  do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers(i)
        if not isrgn and name:match('^%'..Identfier_sub)  then
            reaper.DeleteProjectMarker(0, markrgnindexnumber, isrgn)
        end
    end

    reaper.PreventUIRefresh(-1)

    reaper.UpdateArrange()
    reaper.Undo_EndBlock(ScriptName..': Delete subdivision markers.', -1)
end

function DeleteMarkers()
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    
    local cnt, num_markers, num_regions = reaper.CountProjectMarkers(0)
    for i = cnt-1, 0, -1  do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers(i)
        if (not isrgn) and (name:match('^'..Identfier) or name:match('^%'..Identfier_sub)) then
            reaper.DeleteProjectMarker(0, markrgnindexnumber, isrgn)
        end
    end

    reaper.PreventUIRefresh(-1)

    reaper.UpdateArrange()
    reaper.Undo_EndBlock(ScriptName..': Delete markers.', -1)
end

-- Style

function PushStyle()
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_Alpha(),               1)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_DisabledAlpha(),       0.6)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(),       8, 8)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(),      0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowBorderSize(),    1)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowMinSize(),       32, 32)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowTitleAlign(),    0, 0.5)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(),       0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildBorderSize(),     1)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_PopupRounding(),       0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_PopupBorderSize(),     1)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(),        4, 3)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(),       0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(),     1)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(),         8, 4)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemInnerSpacing(),    4, 4)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_IndentSpacing(),       21)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_CellPadding(),         4, 2)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarSize(),       14)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarRounding(),   9)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabMinSize(),         12)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabRounding(),        0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_TabRounding(),         4)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ButtonTextAlign(),     0.5, 0.5)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_SelectableTextAlign(), 0, 0)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(),                  0xFFFFFFFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextDisabled(),          0x808080FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(),              0x2C2C2CFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(),               0x00000096)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PopupBg(),               0x232323FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(),                0x6E6E8080)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_BorderShadow(),          0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(),               0x232323FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(),        0x484747FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(),         0x7F7C7CFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(),               0x0A0A0AFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(),         0x268451FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgCollapsed(),      0x00000082)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_MenuBarBg(),             0x242424FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarBg(),           0x05050587)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrab(),         0x4F4F4FFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrabHovered(),  0x696969FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrabActive(),   0x828282FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(),             0x32D396FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(),            0x3DE092FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(),      0x42FA7DFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),                0x9393935F)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(),         0x2C6845FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),          0x1DC537FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(),                0x4296FA4F)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(),         0x4296FACC)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(),          0x4296FAFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Separator(),             0x6E6E8080)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SeparatorHovered(),      0x1A66BFC7)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SeparatorActive(),       0x1A66BFFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGrip(),            0x2C6845FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGripHovered(),     0x25AC5DFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGripActive(),      0x1DC537FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Tab(),                   0x2E5994DC)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabHovered(),            0x4296FACC)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabActive(),             0x3369ADFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabUnfocused(),          0x111A26F8)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabUnfocusedActive(),    0x23436CFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_DockingPreview(),        0x4296FAB3)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_DockingEmptyBg(),        0x333333FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PlotLines(),             0x9C9C9CFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PlotLinesHovered(),      0xFF6E59FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PlotHistogram(),         0xE6B300FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PlotHistogramHovered(),  0xFF9900FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableHeaderBg(),         0x303033FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableBorderStrong(),     0x4F4F59FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableBorderLight(),      0x3B3B40FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableRowBg(),            0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableRowBgAlt(),         0xFFFFFF0F)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextSelectedBg(),        0x42FA4659)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_DragDropTarget(),        0xFFFF00E6)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_NavHighlight(),          0x4296FAFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_NavWindowingHighlight(), 0xFFFFFFB3)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_NavWindowingDimBg(),     0xCCCCCC33)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ModalWindowDimBg(),      0xCCCCCC59)
end

function  PopStyle()
    reaper.ImGui_PopStyleVar(ctx, 25)
    reaper.ImGui_PopStyleColor(ctx, 55)
end

