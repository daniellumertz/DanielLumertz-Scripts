--@noindex

-- INIT
function GuiInit(ScriptName,ScriptPath)
    ctx = reaper.ImGui_CreateContext(ScriptName) -- Add VERSION TODO
    -- Define Globals GUI
    Gui_W,Gui_H= 200,450
    --- Text Font
    FontText = reaper.ImGui_CreateFont('sans-serif', 14) -- Create the fonts you need
    reaper.ImGui_AttachFont(ctx, FontText)-- Attach the fonts you need
    --- Title Font
    --FontTitle = reaper.ImGui_CreateFont('sans-serif', 18) 
    FontTitle = reaper.ImGui_CreateFont(ScriptPath..'Fonts/Poppins-Regular.ttf', 21)
    reaper.ImGui_AttachFont(ctx, FontTitle)
    --- Symbol Font
    SymbolFont = reaper.ImGui_CreateFont(ScriptPath..'Fonts/Symbols.ttf', 14)
    reaper.ImGui_AttachFont(ctx, SymbolFont)

end

function MenuBar()
    if reaper.ImGui_BeginMenuBar(ctx) then
        if reaper.ImGui_BeginMenu(ctx, 'Settings') then
            local _

            _, GUISettings.tips = reaper.ImGui_MenuItem(ctx, 'Show ToolTips', optional_shortcutIn, GUISettings.tips) 
            --_, GUISettings.pitch_as_numbers = reaper.ImGui_MenuItem(ctx, 'Show Pitch as Numbers', optional_shortcutIn, GUISettings.pitch_as_numbers) 
            _, GUISettings.use_sharps = reaper.ImGui_MenuItem(ctx, 'Pitch Names With Sharps', optional_shortcutIn, GUISettings.use_sharps)
            ToolTip(GUISettings.tips, 'If enabled, pitch names will be with sharp. If false pitch names will be with flats')


            reaper.ImGui_Separator(ctx) ---------------------

            _, IsGap = reaper.ImGui_MenuItem(ctx, 'Event', optional_shortcutIn, IsGap, optional_enabledIn)
            ToolTip(GUISettings.tips, 'If enabled, the script will group close notes as one event. If disabled, every note is a separate event.')



            --_, Gap = reaper.ImGui_InputInt(ctx, 'Gap Size', Gap,0)
            if IsGap then
                reaper.ImGui_Text(ctx, 'Event Size (QN)')
                reaper.ImGui_SetNextItemWidth(ctx, -1)

                local change
                if not GapString then
                    GapString = tostring(Gap)
                end
                change, GapString = reaper.ImGui_InputText(ctx, '###UserInputLength', GapString, reaper.ImGui_InputTextFlags_CharsDecimal())
                ToolTip(GUISettings.tips, 'If Event is enabled then set the size of a event in QN(Quarter Note = 1), you can set as a decimal value or a fraction. If the QN distance from a note to the next is smaller than this value they will form a event together.')

                if (not reaper.ImGui_IsItemActive(ctx)) then
                    local backup_val = Gap -- in case user mess up
                    local function error() end
                    local set_user_val = load('Gap = '..GapString) -- if RhythmSettings have math expression, it will be executed. or just get the number
                    local retval = xpcall(set_user_val,error)
                    if not retval then -- call xpcall(set_user_val,error)
                        Gap = backup_val
                    else
                        if not tonumber(Gap) then
                            Gap = 1/16
                            GapString = '1/16'
                        end
                    end
                end
            end
            reaper.ImGui_EndMenu(ctx)
        end

        if reaper.ImGui_BeginMenu(ctx, 'About') then
            local _
            if reaper.ImGui_MenuItem(ctx, 'Donate') then
                open_url('https://www.paypal.com/donate/?hosted_button_id=RWA58GZTYMZ3N')
            end
            ToolTip(GUISettings.tips, 'Recommended Donation : One Billion dollars')
            if reaper.ImGui_MenuItem(ctx, 'Manual') then
                open_url('https://drive.google.com/file/d/1asBpkunaSgQzybhVIXwJihE5GuRepoyy/view')
            end
            if reaper.ImGui_MenuItem(ctx, 'Forum') then
                open_url('https://forum.cockos.com/showthread.php?t=272241')
            end

            reaper.ImGui_EndMenu(ctx)

        end
        local _
        reaper.ImGui_PushFont(ctx, SymbolFont)
        _, GUISettings.pin = reaper.ImGui_MenuItem(ctx, 'F', optional_shortcutIn, GUISettings.pin)
        reaper.ImGui_PopFont(ctx)
        ToolTip(GUISettings.tips, 'Keep this window in the foreground')


        reaper.ImGui_EndMenuBar(ctx)
    end
end

function PermutateGUI()
    if not reaper.ImGui_CollapsingHeader(ctx, 'Rotator',false) then
        ToolTip(GUISettings.tips, 'Rotate the parameters on selected notes')
        return
    end
    ToolTip(GUISettings.tips, 'Rotate the parameters on selected notes')


    -- Pitch
    reaper.ImGui_PushFont(ctx, FontTitle) 
    reaper.ImGui_Text(ctx, 'Pitch:')
    reaper.ImGui_PopFont(ctx) -- Pop Font
    
    -- Buttons
    reaper.ImGui_PushFont(ctx, SymbolFont) 
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetCursorPosX(ctx, CurrentW-104)

    if reaper.ImGui_Button(ctx, 'D##pitchup') then
        PermutateVertical('pitch',true,Gap,IsGap) 
        if ctrl and alt and shift then 
            if not StuckFunction then 
                StuckFunction = {func = PermutateVertical, arg1 = 'pitch', arg2 = true}
            else
                StuckFunction = nil
            end
        end
    end
    ToolTip(GUISettings.tips, 'Rotate the pitch values upwards.\n E.g. the sequence of notes is 20 127 1 30 will become 30 1 20 127.')
    
    reaper.ImGui_SameLine(ctx,nil,3)
    if reaper.ImGui_Button(ctx, 'E##pitchdown') then
        PermutateVertical('pitch',false,Gap,IsGap) 
        if ctrl and alt and shift then 
            if not StuckFunction then 
                StuckFunction = {func = PermutateVertical, arg1 = 'pitch', arg2 = false}
            else
                StuckFunction = nil
            end
        end
    end
    ToolTip(GUISettings.tips, 'Rotate the pitch values downwards.\n E.g. the sequence of notes is 20 127 1 30 will become 1 30 127 20.')

    
    reaper.ImGui_SameLine(ctx,nil,3)
    if reaper.ImGui_Button(ctx, 'B##pitchleft') then 
        Permutate('pitch',true,Gap,IsGap) 
        if ctrl and alt and shift then 
            if not StuckFunction then 
                StuckFunction = {func = Permutate, arg1 = 'pitch', arg2 = true}
            else
                StuckFunction = nil
            end
        end
    end
    ToolTip(GUISettings.tips, 'Rotate the pitch values to the left.\n E.g. the sequence of notes is 20 127 1 30 will become 127 1 30 20.')


    reaper.ImGui_SameLine(ctx,nil,3)
    if reaper.ImGui_Button(ctx, 'C##pitchright') then 
        Permutate('pitch',false,Gap,IsGap) 
        if ctrl and alt and shift then 
            if not StuckFunction then 
                StuckFunction = {func = Permutate, arg1 = 'pitch', arg2 = false}
            else
                StuckFunction = nil
            end
        end
    end
    ToolTip(GUISettings.tips, 'Rotate the pitch values to the right.\n E.g. the sequence of notes is 20 127 1 30 will become 30 20 127 1.')


    reaper.ImGui_PopFont(ctx) -- Pop Font

    reaper.ImGui_Separator(ctx)

    -- Interval
    reaper.ImGui_PushFont(ctx, FontTitle) 
    reaper.ImGui_Text(ctx, 'Interval:')
    reaper.ImGui_PopFont(ctx) -- Pop Font

    -- Buttons
    reaper.ImGui_PushFont(ctx, SymbolFont) 
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetCursorPosX(ctx, CurrentW-104)

    if reaper.ImGui_Button(ctx, 'D##intup') then
        PermutateVertical('interval',true,Gap,IsGap) 
        if ctrl and alt and shift then 
            if not StuckFunction then 
                StuckFunction = {func = PermutateVertical, arg1 = 'interval', arg2 = true}
            else
                StuckFunction = nil
            end
        end
    end
    ToolTip(GUISettings.tips, 'Rotate the interval values upwards.\n E.g. the sequence of notes is 2 7 -3 3 will become 3 -3 2 7.')

    
    reaper.ImGui_SameLine(ctx,nil,3)
    if reaper.ImGui_Button(ctx, 'E##intdown') then
        PermutateVertical('interval',false,Gap,IsGap) 
        if ctrl and alt and shift then 
            if not StuckFunction then 
                StuckFunction = {func = PermutateVertical, arg1 = 'interval', arg2 = false}
            else
                StuckFunction = nil
            end
        end
    end
    ToolTip(GUISettings.tips, 'Rotate the interval values downwards.\n E.g. the sequence of notes is 2 7 -3 3 will become -3 3 7 2.')


    reaper.ImGui_SameLine(ctx,nil,3)
    if reaper.ImGui_Button(ctx, 'B##intervalleft') then 
        Permutate('interval',true,Gap,IsGap) 
        if ctrl and alt and shift then 
            if not StuckFunction then 
                StuckFunction = {func = Permutate, arg1 = 'interval', arg2 = true}
            else
                StuckFunction = nil
            end
        end
    end
    ToolTip(GUISettings.tips, 'Rotate the interval values to the left.\n E.g. the sequence of notes is 2 7 -3 3 will become 7 -3 3 2.')

    reaper.ImGui_SameLine(ctx,nil,3)
    if reaper.ImGui_Button(ctx, 'C##intervalright') then 
        Permutate('interval',false,Gap,IsGap) 
        if ctrl and alt and shift then 
            if not StuckFunction then 
                StuckFunction = {func = Permutate, arg1 = 'interval', arg2 = false}
            else
                StuckFunction = nil
            end
        end
    end
    ToolTip(GUISettings.tips, 'Rotate the interval values to the right.\n E.g. the sequence of notes is 2 7 -3 3 will become 3 2 7 -3.')

    reaper.ImGui_PopFont(ctx)

    reaper.ImGui_Separator(ctx)

    -- Rhythm
    reaper.ImGui_PushFont(ctx, FontTitle) 
    reaper.ImGui_Text(ctx, 'Rhythm:')
    reaper.ImGui_PopFont(ctx) -- Pop Font

    -- Buttons
    reaper.ImGui_PushFont(ctx, SymbolFont) 
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetCursorPosX(ctx, CurrentW-104)

    if reaper.ImGui_Button(ctx, 'D##rhythmup') then
        PermutateVertical('rhythm_qn',true,Gap,IsGap) 
        if ctrl and alt and shift then 
            if not StuckFunction then 
                StuckFunction = {func = PermutateVertical, arg1 = 'rhythm_qn', arg2 = true}
            else
                StuckFunction = nil
            end
        end
    end
    ToolTip(GUISettings.tips, 'Rotate the rhythm values upwards.\n E.g. the sequence of rhythms is 0.25 0.5 1 0.33 will become 0.33 1 0.25 0.5')
    
    reaper.ImGui_SameLine(ctx,nil,3)
    if reaper.ImGui_Button(ctx, 'E##rhythmdown') then
        PermutateVertical('rhythm_qn',false,Gap,IsGap) 
        if ctrl and alt and shift then 
            if not StuckFunction then 
                StuckFunction = {func = PermutateVertical, arg1 = 'rhythm_qn', arg2 = false}
            else
                StuckFunction = nil
            end
        end
    end
    ToolTip(GUISettings.tips, 'Rotate the rhythm values downwards.\n E.g. the sequence of rhythms is 0.25 0.5 1 0.33 will become 1 0.33 0.5 0.25')

    reaper.ImGui_SameLine(ctx,nil,3)
    if reaper.ImGui_Button(ctx, 'B##rhythmleft') then 
        Permutate('rhythm_qn',true,Gap,IsGap) 
        if ctrl and alt and shift then 
            if not StuckFunction then 
                StuckFunction = {func = Permutate, arg1 = 'rhythm_qn', arg2 = true}
            else
                StuckFunction = nil
            end
        end
    end
    ToolTip(GUISettings.tips, 'Rotate the rhythm values to the left.\n E.g. the sequence of rhythms is 0.25 0.5 1 0.33 will become 0.5 1 0.33 0.25.')        

    reaper.ImGui_SameLine(ctx,nil,3)
    if reaper.ImGui_Button(ctx, 'C##rhythmright') then 
        Permutate('rhythm_qn',false,Gap,IsGap) 
        if ctrl and alt and shift then 
            if not StuckFunction then 
                StuckFunction = {func = Permutate, arg1 = 'rhythm_qn', arg2 = false}
            else
                StuckFunction = nil
            end
        end
    end
    ToolTip(GUISettings.tips, 'Rotate the rhythm values to the right.\n E.g. the sequence of rhythms is 0.25 0.5 1 0.33 will become 0.33 0.25 0.5 1.')

    reaper.ImGui_PopFont(ctx)

    reaper.ImGui_Separator(ctx)


    -- Measure Pos
    reaper.ImGui_PushFont(ctx, FontTitle) 
    reaper.ImGui_Text(ctx, 'Measure:')
    reaper.ImGui_PopFont(ctx) -- Pop Font

    -- Buttons
    reaper.ImGui_PushFont(ctx, SymbolFont) 
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetCursorPosX(ctx, CurrentW-104)

    if reaper.ImGui_Button(ctx, 'D##measurep') then
        PermutateVertical('measure_pos_qn',true,Gap,IsGap) 
        if ctrl and alt and shift then 
            if not StuckFunction then 
                StuckFunction = {func = PermutateVertical, arg1 = 'measure_pos_qn', arg2 = true}
            else
                StuckFunction = nil
            end
        end
    end
    ToolTip(GUISettings.tips, 'Rotate the measure position of each note upwards.\n E.g. the sequence of measure positions is 0 1 2 3.5 will become 1 2 3.5 0')
    
    reaper.ImGui_SameLine(ctx,nil,3)
    if reaper.ImGui_Button(ctx, 'E##rmeasurep') then
        PermutateVertical('measure_pos_qn',false,Gap,IsGap) 
        if ctrl and alt and shift then 
            if not StuckFunction then 
                StuckFunction = {func = PermutateVertical, arg1 = 'measure_pos_qn', arg2 = false}
            else
                StuckFunction = nil
            end
        end
    end
    ToolTip(GUISettings.tips, 'Rotate the measure position of each note downwards.\n E.g. the sequence of measure positions is 0 1 2 3.5 will become 3.5 0 1 2')


    reaper.ImGui_SameLine(ctx,nil,3)
    if reaper.ImGui_Button(ctx, 'B##MPleftt') then 
        Permutate('measure_pos_qn',true,Gap,IsGap) 
        if ctrl and alt and shift then 
            if not StuckFunction then 
                StuckFunction = {func = Permutate, arg1 = 'measure_pos_qn', arg2 = true}
            else
                StuckFunction = nil
            end
        end
    end    
    ToolTip(GUISettings.tips, 'Rotate the measure position of each note to the left.\n E.g. the sequence of measure positions is 0 1 2 3.5 will become 1 2 3.5 0')

    reaper.ImGui_SameLine(ctx,nil,3)
    if reaper.ImGui_Button(ctx, 'C##MPleft') then 
        Permutate('measure_pos_qn',false,Gap,IsGap) 
        if ctrl and alt and shift then 
            if not StuckFunction then 
                StuckFunction = {func = Permutate, arg1 = 'measure_pos_qn', arg2 = false}
            else
                StuckFunction = nil
            end
        end
    end    
    ToolTip(GUISettings.tips, 'Rotate the measure position of each note to the right.\n E.g. the sequence of measure positions is 0 1 2 3.5 will become 3.5 0 1 2')

    
    reaper.ImGui_PopFont(ctx)

    reaper.ImGui_Separator(ctx)


    -- Velocity
    reaper.ImGui_PushFont(ctx, FontTitle) 
    reaper.ImGui_Text(ctx, 'Velocity:')
    reaper.ImGui_PopFont(ctx) -- Pop Font

    -- Buttons
    reaper.ImGui_PushFont(ctx, SymbolFont) 
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetCursorPosX(ctx, CurrentW-104)

    if reaper.ImGui_Button(ctx, 'D##velup') then
        PermutateVertical('vel',true,Gap,IsGap) 
        if ctrl and alt and shift then 
            if not StuckFunction then 
                StuckFunction = {func = PermutateVertical, arg1 = 'vel', arg2 = true}
            else
                StuckFunction = nil
            end
        end
    end
    ToolTip(GUISettings.tips, 'Rotate the velocity values upwards.\n E.g. the sequence of notes is 20 127 1 30 will become 30 1 20 127.')

    
    reaper.ImGui_SameLine(ctx,nil,3)
    if reaper.ImGui_Button(ctx, 'E##veldown') then
        PermutateVertical('vel',false,Gap,IsGap) 
        if ctrl and alt and shift then 
            if not StuckFunction then 
                StuckFunction = {func = PermutateVertical, arg1 = 'vel', arg2 = false}
            else
                StuckFunction = nil
            end
        end
    end
    ToolTip(GUISettings.tips, 'Rotate the velocity values downwards.\n E.g. the sequence of notes is 20 127 1 30 will become 1 30 127 20.')


    reaper.ImGui_SameLine(ctx,nil,3)
    if reaper.ImGui_Button(ctx,  'B##Velleft') then 
        Permutate('vel',true,Gap,IsGap) 
        if ctrl and alt and shift then 
            if not StuckFunction then 
                StuckFunction = {func = Permutate, arg1 = 'vel', arg2 = true}
            else
                StuckFunction = nil
            end
        end
    end
    ToolTip(GUISettings.tips, 'Rotate the velocity values to the left.\n E.g. the sequence of notes is 20 127 1 30 will become 127 1 30 20.')
  
    
    reaper.ImGui_SameLine(ctx,nil,3)
    if reaper.ImGui_Button(ctx,  'C##VelRight') then 
        Permutate('vel',false,Gap,IsGap) 
        if ctrl and alt and shift then 
            if not StuckFunction then 
                StuckFunction = {func = Permutate, arg1 = 'vel', arg2 = false}
            else
                StuckFunction = nil
            end
        end
    end  
    reaper.ImGui_PopFont(ctx)
    ToolTip(GUISettings.tips, 'Rotate the velocity values to the right.\n E.g. the sequence of notes is 20 127 1 30 will become 30 20 127 1.')
end


function Reorder()
    local flags = MapperIsDrag and reaper.ImGui_TreeNodeFlags_OpenOnDoubleClick() or nil 
    
    local open = reaper.ImGui_CollapsingHeader(ctx, 'Serializer',false,flags)
    ToolTip(GUISettings.tips, 'Set a serie of parameters to the selected notes. Reorder current parameters.')

    local y -- return the delta over the header
    if reaper.ImGui_IsItemActive(ctx) then
        local x
        x, y = reaper.ImGui_GetMouseDelta(ctx)
    elseif MapperIsDrag then
        MapperIsDrag = nil
    end

    if not open then
        return y
    end

    local x1 = reaper.ImGui_GetCursorPosX(ctx)
    reaper.ImGui_SetCursorPosX(ctx, x1)
    -- Reorder: Box
    reaper.ImGui_SetNextItemWidth(ctx, 109)
    if reaper.ImGui_BeginCombo(ctx, '##ParamCombo',SelectedParam) then
        for index, value in ipairs(ComboParam) do
            if reaper.ImGui_Selectable(ctx, value, false) then
                SelectedParam = value
            end
        end
        reaper.ImGui_EndCombo(ctx)
    end
    ToolTip(GUISettings.tips, 'Choose the parameter. Right Click for more options.')


    -- Reorder: Buttons
    reaper.ImGui_SameLine(ctx, Gui_W-80)
    reaper.ImGui_PushFont(ctx, SymbolFont)
    if reaper.ImGui_Button(ctx, 'G##Reordershuffle') then -- shuffle
        ReorderTable[SelectedParam] = RandomizeParamsReorder(ReorderTable[SelectedParam])
        SetParamsReorder(Gap,IsGap,ReorderTable,SelectedParam)
    end
    ToolTip(GUISettings.tips, 'Shuffle the values of the selected parameter.')

    reaper.ImGui_SameLine(ctx, nil, 2)
    if reaper.ImGui_Button(ctx, 'H##Reordercopy') then--copy
        GetParamsReorder(Gap,IsGap,ReorderTable)
    end
    ToolTip(GUISettings.tips, 'Get the parameter values from selected notes.')


    reaper.ImGui_SameLine(ctx, nil, 2)
    if reaper.ImGui_Button(ctx, 'I##Reorderpaste') then -- paste
        SetParamsReorder(Gap,IsGap,ReorderTable,SelectedParam)
    end
    ToolTip(GUISettings.tips, 'Set the parameter values to selected notes.')


    reaper.ImGui_PopFont(ctx)

    --- Reorder List
    local internal_sep = '&' -- for iterpolating multiple values in a single string.

    reaper.ImGui_SetCursorPosX(ctx, x1)
    local child_visible = reaper.ImGui_BeginChild(ctx, 'Reorder', -1, -1, true, reaper.ImGui_WindowFlags_HorizontalScrollbar())

    if child_visible then
        local selectable_hover = false
        for i,item in ipairs(ReorderTable[SelectedParam]) do
            reaper.ImGui_PushID(ctx, i)
            -- if pitch change name from numbers to notes
            local name
            if SelectedParam == 'Pitch' then
                name = ''
                item = item..internal_sep -- hard codded the & 
                for note_number in item:gmatch('(%d-)'..internal_sep) do
                    name = name..NumberToNote(tonumber(note_number), GUISettings.use_sharps, true, 4)..internal_sep
                end
                name = name:sub(1,-2) -- remove last &
            end
            name = name or item
            name = name:gsub(internal_sep,', ')

            reaper.ImGui_Selectable(ctx, name)
            ToolTip(GUISettings.tips, 'Parameter value, right click for setting the value or delting. Drag over other values to change the order, drag and hold control/command to copy the value, hold alt to swap places.')


            if reaper.ImGui_IsItemHovered(ctx) then
                selectable_hover = true
            end
            
            if reaper.ImGui_BeginPopupContextItem(ctx) then
                TempNewName = TempNewName or name 
                local retval, TempNewName = reaper.ImGui_InputText(ctx, '##'..SelectedParam..i, TempNewName)
                ToolTip(GUISettings.tips, 'Set a new value for this parameter.')

                if reaper.ImGui_IsItemDeactivated(ctx) then -- try to see if is a valid input if is insert on the table and set order
                    ChangeParamReorder(TempNewName,i)
                    TempNewName = nil
                end

                reaper.ImGui_Separator(ctx)
                if reaper.ImGui_Selectable(ctx, 'Delete') then
                    table.remove(ReorderTable[SelectedParam],i)
                    SetParamsReorder(Gap,IsGap,ReorderTable,SelectedParam)
                end
                ToolTip(GUISettings.tips, 'Delete this parameter value.')

                reaper.ImGui_EndPopup(ctx)
            end

            if reaper.ImGui_BeginDragDropSource(ctx, reaper.ImGui_DragDropFlags_None()) then
                -- Set payload to carry the index of our item (could be anything)
                reaper.ImGui_SetDragDropPayload(ctx, 'LISTPARAM', tostring(i))
        
                -- Display preview (could be anything, e.g. when dragging an image we could decide to display
                -- the filename and a small preview of the image, etc.)
                if not ctrl and shift and not alt then
                    reaper.ImGui_Text(ctx, 'Swap: '..(item:gsub(internal_sep,' ')))
                elseif ctrl and not shift and not alt then
                    reaper.ImGui_Text(ctx, 'Copying: '..(item:gsub(internal_sep,' ')))
                else
                    reaper.ImGui_Text(ctx, 'Moving: '..(item:gsub(internal_sep,' ')))
                end
                reaper.ImGui_EndDragDropSource(ctx)
            end

            if reaper.ImGui_BeginDragDropTarget(ctx) then
                local payload, rv
                rv,payload = reaper.ImGui_AcceptDragDropPayload(ctx, 'LISTPARAM')
                if rv then
                    local source_i = tonumber(payload) -- source idx
                    local move_val = ReorderTable[SelectedParam][source_i] -- Source val
                    if not ctrl and shift and not alt then -- swap [shift]
                        ReorderTable[SelectedParam][source_i] = item
                        ReorderTable[SelectedParam][i] = move_val
                    elseif ctrl and not shift and not alt then -- copy [ctrl]
                        ReorderTable[SelectedParam][i] = move_val
                    else -- move [no mod]
                        table.remove(ReorderTable[SelectedParam],source_i)
                        table.insert(ReorderTable[SelectedParam],i,move_val)
                    end
                    SetParamsReorder(Gap,IsGap,ReorderTable,SelectedParam)

                end
                reaper.ImGui_EndDragDropTarget(ctx)
            end

            reaper.ImGui_PopID(ctx)
        end
        reaper.ImGui_EndChild(ctx)
        local child_is_hovered = reaper.ImGui_IsItemHovered(ctx)
        if child_is_hovered and not selectable_hover then
            ToolTip(GUISettings.tips, 'Double click to add a new value.')
            
            if reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
                table.insert(ReorderTable[SelectedParam],ReorderTable[SelectedParam][#ReorderTable[SelectedParam]] or '1')
            end
        end
    end 


    return y
end

function Mapper()

    if not reaper.ImGui_CollapsingHeader(ctx, 'Mapper',false) then
        ToolTip(GUISettings.tips, 'Swap parameter values.')
        return
    end
    ToolTip(GUISettings.tips, 'Swap parameter values.')

    local x1 = reaper.ImGui_GetCursorPosX(ctx)
    reaper.ImGui_SetCursorPosX(ctx, x1)
    -- Reorder: Box
    reaper.ImGui_SetNextItemWidth(ctx, 109)

    local function right_click()
        if reaper.ImGui_BeginPopupContextItem(ctx) then


            --- Quantize Rhythm

            retval, MapperSettings.is_quantize = reaper.ImGui_Checkbox(ctx, 'Quantize Rhythms', MapperSettings.is_quantize)
            if MapperSettings.is_quantize  then
                reaper.ImGui_Text(ctx, 'Quantize Val (QN)')
                reaper.ImGui_SetNextItemWidth(ctx, -1)
                local change
                change, MapperSettings.quantize_text = reaper.ImGui_InputText(ctx, '###quantizedrop', MapperSettings.quantize_text, reaper.ImGui_InputTextFlags_CharsDecimal())
                ToolTip(GUISettings.tips, 'Quantize Rhythm and Measure Positions Values, unit are in Quarter Notes.')
    
                if (not reaper.ImGui_IsItemActive(ctx)) then
                    local function error() end
                    local set_user_val = load('MapperSettings.quantize_step = '..MapperSettings.quantize_text) -- if RhythmSettings have math expression, it will be executed. or just get the number
                    local retval = xpcall(set_user_val,error)
                    if not retval or not tonumber(MapperSettings.quantize_step) then -- call xpcall(set_user_val,error)
                        MapperSettings.quantize_text = '1/4'
                        MapperSettings.quantize_step = 1/4
                    end
                end
            end
            reaper.ImGui_EndPopup(ctx)
        end
    end
    if reaper.ImGui_BeginCombo(ctx, '##MapperParamCombo',MapperSelectedParam) then
        for index, value in ipairs(MapperComboParam) do
            if reaper.ImGui_Selectable(ctx, value, false) then
                MapperSelectedParam = value
            end
        end
        reaper.ImGui_EndCombo(ctx)
    end
    ToolTip(GUISettings.tips, 'Choose the parameter. Right Click for more options.')

    right_click()


    -- if right click
    

    -- Reorder: Buttons
    reaper.ImGui_SameLine(ctx, Gui_W-56)
    reaper.ImGui_PushFont(ctx, SymbolFont)

    if reaper.ImGui_Button(ctx, 'H##Mappercopy') then--copy
        MapperTable = GetParamsMapper(Gap,IsGap)
    end
    ToolTip(GUISettings.tips, 'Get the values from the selected notes.')

    reaper.ImGui_SameLine(ctx, nil, 2)
    if reaper.ImGui_Button(ctx, 'I##Mapperpaste') then -- paste
        SetParamsMapper(Gap,IsGap,MapperTable,MapperSelectedParam)
    end
    ToolTip(GUISettings.tips, 'Set the values for the selected notes.')


    reaper.ImGui_PopFont(ctx)

    --- Reorder List
    local internal_sep = '&' -- for iterpolating multiple values in a single string.

    reaper.ImGui_SetCursorPosX(ctx, x1)
    local child_visible = reaper.ImGui_BeginChild(ctx, 'Mapper', -1, GUISettings.mapper_size, true, reaper.ImGui_WindowFlags_HorizontalScrollbar())
    if child_visible then
        local width_avail, y = reaper.ImGui_GetContentRegionAvail(ctx)
        for idx,parameter_table in pairs(MapperTable[MapperSelectedParam]) do
            local old_val = parameter_table.old_value     

            local retval
            reaper.ImGui_PushID(ctx, i)
            -- if pitch change name from numbers to notes
            local name
            if MapperSelectedParam == 'Pitch' then
                name = ''
                local old_val = old_val..internal_sep 
                for note_number in old_val:gmatch('(%d-)'..internal_sep) do
                    local show_octave = not MapperSettings.is_pitch_class
                    name = name..NumberToNote(tonumber(note_number), GUISettings.use_sharps, show_octave, 4)..internal_sep
                end
                name = name:sub(1,-2) -- remove last &
            end
            name = name or old_val
            name = name:gsub(internal_sep,', ')
            if tonumber(name) then
                -- format to get only up to the 3rd decimal place if name is only the number and not a multiple value 
                name = string.format("%.3f",name)
            end

            reaper.ImGui_SetNextItemWidth(ctx, 2*width_avail/3)
            retval, parameter_table.new_value = reaper.ImGui_InputText(ctx, name, parameter_table.new_value)
            ToolTip(GUISettings.tips, 'Set a new value for every '..MapperSelectedParam..' parameter with the value of '..name..'.')

            --WriteAtLastObjectasShortkey('text', 255,255,255,255)
            

            reaper.ImGui_PopID(ctx)
        end
        reaper.ImGui_EndChild(ctx)
    end 
end

function CopyPaste()
    local function slider_right_click(param,inter,complete)
        local do_autopaste
        if reaper.ImGui_BeginPopupContextItem(ctx) then
            if reaper.ImGui_IsWindowAppearing(ctx) then -- Make the auto paste goes false 'safety'
                IsAutoPaste = false
                SaveCopy = nil
            end
            reaper.ImGui_Text(ctx, 'Original')
            reaper.ImGui_SameLine(ctx, 200) -- Pad next text
            reaper.ImGui_Text(ctx, 'Copy')
            local _, change, save_current_state
            change, inter = reaper.ImGui_SliderDouble(ctx, '###InterSlider', inter, 0, 1, tostring(math.floor(inter*100))..'%%')
            ToolTip(GUISettings.tips, 'Interpolate between the current value and the copied value')

            if complete then
                _, complete = reaper.ImGui_Checkbox(ctx, 'Fill all chord notes', complete)
                ToolTip(GUISettings.tips, 'If true it will add notes when pasting chords. If false it will only modify the selected notes values')
            end
            save_current_state, IsAutoPaste = reaper.ImGui_Checkbox(ctx, 'Auto Paste', IsAutoPaste)
            ToolTip(GUISettings.tips, 'If true and change the [iterate slider] above it will paste the values to the selected notes')

    
            if save_current_state then
                SaveCopy = CopyParam(Gap,IsGap)
            end

            do_autopaste = change and IsAutoPaste
            if do_autopaste then
                local name
                if param == 'groove' then 
                    name = 'measure_pos_qn'
                else 
                    name = param
                end
                PasteParam(param,SaveCopy[name],1,Gap,IsGap,true)
                PasteParam(param,CopiedParameters[name],inter,Gap,IsGap,complete)
            end
            
            reaper.ImGui_EndPopup(ctx)
        end
        return inter, complete
    end

    if not reaper.ImGui_CollapsingHeader(ctx, 'Copy Paste',false) then
        ToolTip(GUISettings.tips, 'Copy the parameters of a group of notes to paste in other.')
        return
    end
    ToolTip(GUISettings.tips, 'Copy the parameters of a group of notes to paste in other.')


    local btn_height = 29
    local btn_indent = 2
    local x_start = reaper.ImGui_GetCursorPosX(ctx)

    reaper.ImGui_SetCursorPosX(ctx, x_start+btn_indent)
    ButtonStylePush(1)
    if reaper.ImGui_Button(ctx, 'Copy', -btn_indent, btn_height) then
        CopiedParameters = CopyParam(Gap,IsGap)
    end
    ButtonStylePop()
    ToolTip(GUISettings.tips, 'Copy all the parameters of the selected notes.')

    -- paste
    reaper.ImGui_Separator(ctx)

    local paste_text = 'Paste'
    TextCenter(paste_text,Gui_W)

    reaper.ImGui_SetCursorPosX(ctx, x_start+btn_indent)
    ButtonStylePush(CopySettings.pitch_inter)
    if reaper.ImGui_Button(ctx, 'Pitch', -btn_indent, btn_height) and CopiedParameters then
        PasteParam('pitch',CopiedParameters.pitch,CopySettings.pitch_inter,Gap,IsGap,PitchComplete)
    end
    CopySettings.pitch_inter,PitchComplete = slider_right_click('pitch',CopySettings.pitch_inter,PitchComplete)
    ButtonStylePop()
    ToolTip(GUISettings.tips, 'Paste the pitch of the copied notes. Right click to Interpolate between current and paste values.')


    reaper.ImGui_SetCursorPosX(ctx, x_start+btn_indent)
    ButtonStylePush(CopySettings.interval_inter)
    if reaper.ImGui_Button(ctx, 'Interval', -btn_indent, btn_height) and CopiedParameters then
        PasteParam('interval',CopiedParameters.interval,CopySettings.interval_inter,Gap,IsGap,InterComplete)
    end
    CopySettings.interval_inter,InterComplete = slider_right_click('interval',CopySettings.interval_inter,InterComplete)
    ButtonStylePop()
    ToolTip(GUISettings.tips, 'Paste the interval of the copied notes. Right click to Interpolate between current and paste values.')

    reaper.ImGui_SetCursorPosX(ctx, x_start+btn_indent)
    ButtonStylePush(CopySettings.vel_inter)
    if reaper.ImGui_Button(ctx, 'Velocity', -btn_indent, btn_height) and CopiedParameters then
        PasteParam('vel',CopiedParameters.vel,CopySettings.vel_inter,Gap,IsGap)
    end
    CopySettings.vel_inter = slider_right_click('vel',CopySettings.vel_inter)
    ButtonStylePop()
    ToolTip(GUISettings.tips, 'Paste the velocity of the copied notes. Right click to Interpolate between current and paste values.')

    reaper.ImGui_SetCursorPosX(ctx, x_start+btn_indent)
    ButtonStylePush(CopySettings.rhythm_inter)
    if reaper.ImGui_Button(ctx, 'Rhythm', -btn_indent, btn_height) and CopiedParameters then
        PasteParam('rhythm_qn',CopiedParameters.rhythm_qn,CopySettings.rhythm_inter,Gap,IsGap)
    end
    CopySettings.rhythm_inter = slider_right_click('rhythm_qn',CopySettings.rhythm_inter)
    ButtonStylePop()
    ToolTip(GUISettings.tips, 'Paste the rhythm of the copied notes. Right click to Interpolate between current and paste values.')

    reaper.ImGui_SetCursorPosX(ctx, x_start+btn_indent)
    ButtonStylePush(CopySettings.measure_pos_inter)
    if reaper.ImGui_Button(ctx, 'Measure Pos', -btn_indent, btn_height) and CopiedParameters then
        PasteParam('measure_pos_qn',CopiedParameters.measure_pos_qn,CopySettings.measure_pos_inter,Gap,IsGap)
    end
    CopySettings.measure_pos_inter = slider_right_click('measure_pos_qn',CopySettings.measure_pos_inter)
    ButtonStylePop()
    ToolTip(GUISettings.tips, 'Paste the measure position of the copied notes. Right click to Interpolate between current and paste values.')

    reaper.ImGui_SetCursorPosX(ctx, x_start+btn_indent)
    ButtonStylePush(CopySettings.groove_inter)
    if reaper.ImGui_Button(ctx, 'Groove', -btn_indent, btn_height) and CopiedParameters then
        PasteParam('groove',CopiedParameters.measure_pos_qn,CopySettings.groove_inter,Gap,IsGap)
    end
    CopySettings.groove_inter = slider_right_click('groove',CopySettings.groove_inter)
    ButtonStylePop()
    ToolTip(GUISettings.tips, 'Quantize selected notes to the measure position of the copied notes. Right click to Interpolate between current and paste values.')

    reaper.ImGui_SetCursorPosX(ctx, x_start+btn_indent)
    ButtonStylePush(CopySettings.len_inter)
    if reaper.ImGui_Button(ctx, 'Length', -btn_indent, btn_height) and CopiedParameters then
        PasteParam('len_qn',CopiedParameters.len_qn,CopySettings.len_inter,Gap,IsGap)
    end    
    CopySettings.len_inter = slider_right_click('len_qn',CopySettings.len_inter)
    ButtonStylePop()
    ToolTip(GUISettings.tips, 'Paste the length of the copied notes. Right click to Interpolate between current and paste values.')    

end


function ButtonStylePush(val)
    -- make val between red(0) and green(x)
    local h = val *0.5
    local low_bg = HSV(h, 0.82, 0.35, 1) --125 211 149 255
    local med_bg = HSV(h, 0.82, 0.4, 1) --125 211 149 255
    local high_bg = HSV(h, 0.82, 0.45, 1) --125 211 149 255
    local low = HSV(h, 0.82, 0.58, 1) --125 211 149 255
    local med = HSV(h, 0.49, 0.77, 1) --125 197 201
    local high = HSV(h, 0.49, 0.90, 1) --125 93 288 

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(),          low_bg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(),   low_bg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(),    low)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(),        med)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(),       low)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(), high)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),           low)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(),    med)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),     high)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(),           low)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(),    med)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(),     high)
end

function ButtonStylePop()
    reaper.ImGui_PopStyleColor(ctx, 12)

end