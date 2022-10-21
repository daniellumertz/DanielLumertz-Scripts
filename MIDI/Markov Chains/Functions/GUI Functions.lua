-- @noindex
function GuiInit(ScriptName)
    ctx = reaper.ImGui_CreateContext(ScriptName) -- Add VERSION TODO
    -- Define Globals GUI
    Gui_W,Gui_H= 365,400
    --- Text Font
    FontText = reaper.ImGui_CreateFont('sans-serif', 14) -- Create the fonts you need
    reaper.ImGui_AttachFont(ctx, FontText)-- Attach the fonts you need
    --- Title Font
    FontTitle = reaper.ImGui_CreateFont('sans-serif', 24) 
    reaper.ImGui_AttachFont(ctx, FontTitle)
end


--- Gui Parts: 

function OpenPopups() -- need to be outside the if conditions. to run every defer loop.
    if  TempRenamePopup then -- only run to set the popup once.
        reaper.ImGui_OpenPopup(ctx, 'Rename###RenamePopup')
        TempRenamePopup = nil -- to only run once
        -- set popup position
        local x, y = reaper.GetMousePosition()
        reaper.ImGui_SetNextWindowPos(ctx, x-125, y-30)
    end

    RenamePopup()
end

function RenamePopup()
    -- Set Rename Popup Position first time it runs 
    if TempRename_x then
        reaper.ImGui_SetNextWindowPos(ctx, TempRename_x-125, TempRename_y-30)
        TempRename_x = nil
        TempRename_y = nil
    end

    if reaper.ImGui_BeginPopupModal(ctx, 'Rename###RenamePopup', nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()| reaper.ImGui_WindowFlags_TopMost()) then
        --Body
        if reaper.ImGui_IsWindowAppearing(ctx) then -- First Run
            reaper.ImGui_SetKeyboardFocusHere(ctx)
            --TempRename_x, TempRename_y = reaper.GetMousePosition()
        end
        local _ 
        _, TempMarkovTableRename.name = reaper.ImGui_InputText(ctx, "##Rename", TempMarkovTableRename.name, reaper.ImGui_InputTextFlags_AutoSelectAll())
        
        if reaper.ImGui_Button(ctx, 'Close', -1) or reaper.ImGui_IsKeyDown(ctx, 13) then
            if TempMarkovTableRename.name == '' then TempMarkovTableRename.Name = 'No Name Markov Table ' end -- If Name == '' Is difficult to see in the GUI. Maybe count and put Markov #1, Markov #2, etc.
            TempMarkovTableRename = nil -- delete the temp variable

            reaper.ImGui_CloseCurrentPopup(ctx) 
        end
        --End
        reaper.ImGui_EndPopup(ctx)
    end    
end

---Set the width of the next button based on a portion of w_size. Centralizes the object
---@param ratio number w_size/ratio = new w
---@param w_size any
function SetNextItemWidthRatio(ratio,w_size)
    local new_width = w_size / ratio -- Change how muh space the combo takes
    local new_x = (w_size/2) - (new_width/2)
    reaper.ImGui_SetCursorPosX(ctx, new_x)
    reaper.ImGui_SetNextItemWidth(ctx, new_width)
    return new_width
end

function SourceCombo()
    local function right_click_source(source_table, source_idx)
        -- if right click at a selectable open popup
        if reaper.ImGui_BeginPopupContextItem(ctx) then
            -- Save Button
            if reaper.ImGui_MenuItem(ctx, 'Save') then
                SaveSourceTable(source_table)
            end
            ToolTip(GUISettings.tips, 'Save the Source Table as a file')

            -- Recreate From Source
            if reaper.ImGui_MenuItem(ctx, 'Recreate Sources') then
                RecreateSourceTable(source_table)
            end
            ToolTip(GUISettings.tips, 'This will create/paste new MIDI Items with the sources into reaper arrange')


            -- Print Probability
            if reaper.ImGui_MenuItem(ctx, 'Print Probability') then
                PrintChanceTable(SelectedSourceTable, PitchSettings,RhythmSettings,VelSettings,LinkSettings)
            end
            ToolTip(GUISettings.tips, 'This will show the learned events and the possible next events and their probability. The probability wont be weighted as the weights are position dependendent!')

            -- Rename button.
            if reaper.ImGui_MenuItem(ctx, 'Rename') then
                -- set a variable  to open the popup, need to be ouside this if loops else the popup will not be run every defer loop.
                TempMarkovTableRename = source_table -- to remember which markov table we are renaming
                TempRenamePopup = true 
            end
            ToolTip(GUISettings.tips, 'Rename this Source Table')

            -- Clean Button
            if reaper.ImGui_MenuItem(ctx, 'Clear Sources') then
                local name_keeper = source_table.name
                table.remove(AllSources,source_idx)
                source_table = CreateSourceTable(AllSources)
                source_table.name = name_keeper
                SelectedSourceTable = source_table
            end
            ToolTip(GUISettings.tips, 'Clear all Sources from this Table')

            -- Delete button.
            if reaper.ImGui_MenuItem(ctx, 'Delete') then
                table.remove(AllSources,source_idx)
                if #AllSources < 1 then
                    SelectedSourceTable = CreateSourceTable(AllSources)
                end
                SelectedSourceTable = AllSources[1]
            end
            ToolTip(GUISettings.tips, 'Delete this Source Table')            
            
            reaper.ImGui_EndPopup(ctx)
        end
    end

    if reaper.ImGui_BeginCombo(ctx, '##SourceCombo',SelectedSourceTable.name) then
        for source_idx,source_table in ipairs(AllSources) do
            -- name this selectable
            local name = source_table.name
            if source_table == SelectedSourceTable then
                name = name..' * ' -- Mark the selected source table.
            end
            name = name..'###'..source_idx -- Add the index to the name to make it unique for imgui
            -- create selectable
            if reaper.ImGui_Selectable(ctx, name) then
                SelectedSourceTable = source_table -- Change the SelectedSourceTable at user input.
            end

            right_click_source(source_table, source_idx)
        end

        reaper.ImGui_Separator(ctx)
        -- Create selecdable to add a new markov table
        if reaper.ImGui_Selectable(ctx, 'Create Clean Source Table') then
            SelectedSourceTable = CreateSourceTable(AllSources)
        end
        ToolTip(GUISettings.tips, 'Create a new Source Table with no sources.')


        -- Load Source Button
        if reaper.ImGui_Selectable(ctx, 'Load Source Table') then
            SelectedSourceTable = LoadSource(AllSources) or SelectedSourceTable
        end
        ToolTip(GUISettings.tips, 'Load a Source Table from a file.')


        reaper.ImGui_EndCombo(ctx)
    end  
    ToolTip(GUISettings.tips, 'Select the Source Table to use. The source table holds the MIDI sequence used to feed the markov algorithm. You can right click each Source Table for More options')

    local boll, source_idx = TableHaveValue(AllSources, SelectedSourceTable) 
    right_click_source(SelectedSourceTable, source_idx)  
end

function MenuBar()
    if reaper.ImGui_BeginMenuBar(ctx) then
        if reaper.ImGui_BeginMenu(ctx, 'Settings') then
            local _

            _, GUISettings.tips = reaper.ImGui_MenuItem(ctx, 'Show ToolTips', optional_shortcutIn, GUISettings.tips) 

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

            if reaper.ImGui_MenuItem(ctx, 'Forum') then
                open_url('https://forum.cockos.com/showthread.php?p=2606674#post2606674')
            end

            if reaper.ImGui_MenuItem(ctx, 'Manual') then
                open_url('https://drive.google.com/file/d/1Ci1yCuG7hoFg7vPJfOLKSXKQLg6DbQky/view?usp=sharing')
            end



            reaper.ImGui_EndMenu(ctx)

        end
        local _
        _, Pin = reaper.ImGui_MenuItem(ctx, 'Pin', optional_shortcutIn, Pin)
        ToolTip(GUISettings.tips, 'Keep this window in the foreground')


        reaper.ImGui_EndMenuBar(ctx)
    end
end

function PitchRightClickMenu()
    if reaper.ImGui_BeginPopupContextItem(ctx) then
        ------ Muted Notes
        local boll = PitchSettings.use_muted == 2 --if generate a muted note will apply it. Add user setting to go between the three --- Ignore Mute = 0 (remove the mute symbol)--- Mute Type = 1 (dont change nothing) --- One Mute = 2 (parameters marked with mute will be only a muted symbol and wont differentiate between they. Exemple : Muted C and Muted D will become just Muted symbol) 
        local retval, r = reaper.ImGui_Checkbox(ctx, 'Generate Muted Notes', boll)
        ToolTip(GUISettings.tips, 'If true, and the selected source table haves muted notes, then the markov will consider muted notes as a different note from non muted, and if choosen they will generate muted notes')
        if retval then
            PitchSettings.use_muted = (r and 2) or 0
        end
        ----- Keep Start
        retval, PitchSettings.keep_start = reaper.ImGui_Checkbox(ctx, 'Keep Start', PitchSettings.keep_start)
        ToolTip(GUISettings.tips, 'If true, the first nºOrder parameters from the selected notes will be the same, the markov will start from it.')

        ----- Drop Resolution
        reaper.ImGui_Separator(ctx)
        local text = (PitchSettings.mode == 1 and 'Use Pitch Class')  or 'Simple Intervals' 
        local tips = (PitchSettings.mode == 1 and 'If true markov is based on pitch classes, will always move to the closest pitch class position(if a tie will go up, like a tritone in 12EDO).')  or 'If true will reduce all complex intervals to simple intervals' 
        local is_drop = PitchSettings.drop and true
        local retval, is_drop= reaper.ImGui_Checkbox(ctx, text,is_drop)
        ToolTip(GUISettings.tips, tips)
        if retval then
            if is_drop then
                PitchSettings.drop = 12
            else
                PitchSettings.drop = false
            end
        end
        if PitchSettings.drop  then
            reaper.ImGui_Text(ctx, 'Octave Size')
            ToolTip(GUISettings.tips, 'Octave size to be used when reducing to pitch classes/simple intervals.')
            reaper.ImGui_SetNextItemWidth(ctx, -1)
            _, PitchSettings.drop = reaper.ImGui_InputInt(ctx, '###Octavesize', PitchSettings.drop,0,0,reaper.ImGui_InputTextFlags_CharsDecimal())
        end

        ---- Weight
        ----------------- PCWeight
        if PitchSettings.mode == 1 then 
            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Text(ctx, 'Pitch Class Weight:')
            -- btton to get select item
            if reaper.ImGui_Button(ctx, 'Get Selected Item##PC', -1) then
                local item = reaper.GetSelectedMediaItem(0,0)
                if item then
                    local take = reaper.GetActiveTake(item)
                    PCWeight = {w = 2, take = take, octave_size = 12, item = item}
                else
                    reaper.ShowMessageBox('Please Select an Item!', 'Markov Chains', 0)
                end

                if LinkSettings.pitch then -- not link compatible
                    LinkSettings.pitch = false
                end
            end
            ToolTip(GUISettings.tips, 'Weight the chances of a pitch class being used(or not) in a certain moment. Click at this button to select the weight item. When applying the markov it will use the notes at the weight item for weighting. A note with velocity > 64 in the weight item will make that note pitch class more probable of happening, a note with < 64 velocity will make that note pitch class less likely to be selected. Not compatible with links.')

            if PCWeight then
                reaper.ImGui_SetNextItemWidth(ctx, 100)
                reaper.ImGui_Text(ctx, 'Weight')
                local  retval,  v = reaper.ImGui_InputDouble(ctx, '##PCWeight', PCWeight.w, 0, 0, '%.2f', reaper.ImGui_InputTextFlags_CharsDecimal())
                ToolTip(GUISettings.tips, 'Weight value to be used in the weighting. The higher the value the more it will weight the chances.')
                PCWeight.w = LimitNumber(v, 1)

                reaper.ImGui_Text(ctx, 'Octave Size')
                ToolTip(GUISettings.tips, 'Octave size to be used when weigthing pitch classes.')
                reaper.ImGui_SetNextItemWidth(ctx, -1)
                _, PCWeight.octave_size = reaper.ImGui_InputInt(ctx, '###PCWeightOctavesize', PCWeight.octave_size,0,0,reaper.ImGui_InputTextFlags_CharsDecimal())

                if reaper.ImGui_Button(ctx, 'Select Current Item##PC', -1) then -- Button to select the weight item
                    if reaper.ValidatePtr2(0, PCWeight.item, 'MediaItem*') then
                        reaper.Undo_BeginBlock2(0)
                        local item = reaper.GetMediaItemTake_Item(PCWeight.take)
                        SelectItemList(item)
                        reaper.UpdateArrange()
                        reaper.Undo_EndBlock2(0, 'Markov: Select Pitch Class Weight Item', -1)
                    else -- if item is removed remove weight
                        reaper.ShowMessageBox('The item is no longer available, please select a new one.', 'Markov Chains', 0)
                        PCWeight = nil
                    end
                end
                ToolTip(GUISettings.tips, 'Select the Weight item in the arrange view')

                if reaper.ImGui_Button(ctx, 'Remove Weight##PC', -1) then
                    PCWeight = nil
                end
            end
        end


        reaper.ImGui_EndPopup(ctx)
    end    
end

function RhythmRightClickMenu()
    if reaper.ImGui_BeginPopupContextItem(ctx) then
        ------ Muted Notes
        local boll = RhythmSettings.use_muted == 1 --if generate a muted note will apply it. Add user setting to go between the three --- Ignore Mute = 0 (remove the mute symbol)--- Mute Type = 1 (dont change nothing) --- One Mute = 2 (parameters marked with mute will be only a muted symbol and wont differentiate between they. Exemple : Muted C and Muted D will become just Muted symbol) 
        local retval, r = reaper.ImGui_Checkbox(ctx, 'Generate Muted Notes', boll)
        ToolTip(GUISettings.tips, 'If true, and the selected source table haves muted notes, then the markov will consider muted notes as a different note from non muted, and if choosen they will generate muted notes')
        if retval then
            RhythmSettings.use_muted = (r and 1) or 0
        end
        ----- Keep Start
        retval, RhythmSettings.keep_start = reaper.ImGui_Checkbox(ctx, 'Keep Start', RhythmSettings.keep_start)
        ToolTip(GUISettings.tips, 'If true, the first nºOrder parameters from the selected notes will be the same, the markov will start from it.')

        ----- Drop Resolution
        local is_drop = RhythmSettings.drop and true
        local retval, is_drop= reaper.ImGui_Checkbox(ctx, 'Quantize',is_drop)
        ToolTip(GUISettings.tips, 'If true will quantize the rhythms/measure positions to the nearst multiple of the selected value, in quarter notes.')
        if retval then
            if is_drop then
                RhythmSettings.drop = 1/4
                RhythmSettings.drop_quantize_text = '1/4'
            else
                RhythmSettings.drop = false
            end
        end
        if RhythmSettings.drop  then
            reaper.ImGui_Text(ctx, 'Quantize Val (QN)')
            reaper.ImGui_SetNextItemWidth(ctx, -1)
            local change
            change, RhythmSettings.drop_quantize_text = reaper.ImGui_InputText(ctx, '###quantizedrop', RhythmSettings.drop_quantize_text, reaper.ImGui_InputTextFlags_CharsDecimal())
            ToolTip(GUISettings.tips, 'Quantize value')

            if (not reaper.ImGui_IsItemActive(ctx)) then
                local backup_val = RhythmSettings.drop  -- in case user mess up
                local function error() end
                local set_user_val = load('RhythmSettings.drop = '..RhythmSettings.drop_quantize_text) -- if RhythmSettings have math expression, it will be executed. or just get the number
                local retval = xpcall(set_user_val,error)
                if not retval then -- call xpcall(set_user_val,error)
                    RhythmSettings.drop = backup_val
                else
                    if not tonumber(RhythmSettings.drop) then
                        RhythmSettings.drop = 1/4
                        RhythmSettings.drop_quantize_text = '1/4'
                    end
                end
            end
        end

        ------  Weight options
        reaper.ImGui_Separator(ctx)
        local tips_1 = 'Weight the chances of a position being used(or not) for a note start. Click at this button to select the weight item. When applying the markov it will use the notes at the weight item for weighting. A note with velocity > 64 in the weight item will make that position more probable of happening, a note with < 64 velocity will make that position less likely to happen. Not compatible with links. '
        local tips_2 = 'Weight the chances of a measure position being used(or not) for a note start. Click at this button to select the weight item. When applying the markov it will use the notes at the weight item for weighting. A note with velocity > 64 in the weight item will make that measure position more probable of happening, a note with < 64 velocity will make that measure position less likely to happen. Not compatible with links. '
        local tips = RhythmSettings.mode == 1 and tips_1 or tips_2
        reaper.ImGui_Text(ctx, 'Weight Options:')
        if reaper.ImGui_Button(ctx, 'Get Selected Item', -1) then
            local item = reaper.GetSelectedMediaItem(0,0)
            local take = reaper.GetActiveTake(item)
            PosQNWeight = {w = 2, take = take, item = item}

            if LinkSettings.rhythm then -- not link compatible
                LinkSettings.rhythm = false
            end
        end
        ToolTip(GUISettings.tips, tips)

        if PosQNWeight then
            reaper.ImGui_SetNextItemWidth(ctx, 100)

            local  retval,  v = reaper.ImGui_InputDouble(ctx, 'Weight##PosWeight', PosQNWeight.w, 0, 0, '%.2f', reaper.ImGui_InputTextFlags_CharsDecimal())
            ToolTip(GUISettings.tips, 'Weight value to be used in the weighting. The higher the value the more it will weight the chances.')
            PosQNWeight.w = LimitNumber(v, 1)

            if reaper.ImGui_Button(ctx, 'Select Current Item', -1) then -- Button to select the weight item
                if reaper.ValidatePtr2(0, PosQNWeight.item, 'MediaItem*') then
                    reaper.Undo_BeginBlock2(0)
                    local item = reaper.GetMediaItemTake_Item(PosQNWeight.take)
                    SelectItemList(item)
                    reaper.UpdateArrange()
                    reaper.Undo_EndBlock2(0, 'Markov: Select Pos Weight Item', -1)
                else
                    reaper.ShowMessageBox('The item is no longer available, please select a new one.', 'Markov Chains', 0)
                    PosQNWeight = nil
                end
            end
            ToolTip(GUISettings.tips, 'Select weight item at arrange view.')


            if reaper.ImGui_Button(ctx, 'Remove Weight', -1) then
                PosQNWeight = nil
            end
            ToolTip(GUISettings.tips, 'Remove weight')

        end


        reaper.ImGui_EndPopup(ctx)
    end    
end

function VelocityRightClickMenu()
    if reaper.ImGui_BeginPopupContextItem(ctx) then
        ------ Muted Notes
        local boll = VelSettings.use_muted == 2 --if generate a muted note will apply it. Add user setting to go between the three --- Ignore Mute = 0 (remove the mute symbol)--- Mute Type = 1 (dont change nothing) --- One Mute = 2 (parameters marked with mute will be only a muted symbol and wont differentiate between they. Exemple : Muted C and Muted D will become just Muted symbol) 
        local retval, r = reaper.ImGui_Checkbox(ctx, 'Generate Muted Notes', boll)
        ToolTip(GUISettings.tips, 'If true, and the selected source table haves muted notes, then the markov will consider muted notes as a different note from non muted, and if choosen they will generate muted notes')

        if retval then
            VelSettings.use_muted = (r and 2) or 0
        end
        ----- Keep Start
        retval, VelSettings.keep_start = reaper.ImGui_Checkbox(ctx, 'Keep Start', VelSettings.keep_start)
        ToolTip(GUISettings.tips, 'If true, the first nºOrder parameters from the selected notes will be the same, the markov will start from it.')

        reaper.ImGui_Separator(ctx)
        ----- Drop/Group
        local is_drop = VelSettings.drop and true
        local retval, is_drop= reaper.ImGui_Checkbox(ctx, 'Group',is_drop)
        ToolTip(GUISettings.tips, 'If true, will group velocity in groups, usefull for groupping the possibilities by reducing the resolution.')

        if retval then
            if is_drop then
                VelSettings.drop = {{low = 1, high = 40},{low = 41, high = 100},{low = 101, high = 127}} -- Make this a slider
            else
                VelSettings.drop = false
            end
        end        

        if VelSettings.drop then 
            reaper.ImGui_Text(ctx, 'Groups divisions')
            -- Make the Grabber Table
            local grabbers = {}
            for i = 1, #VelSettings.drop-1 do
                grabbers[i] = VelSettings.drop[i].high
            end
            -- Slider
            reaper.ImGui_SetNextItemWidth(ctx, 150)
            local boll, grabbers = ImGui_MultiSlider(ctx,'##MultisliderDrop',grabbers,1,127,true)

            -- If Change then new Grabber Table to VelSettings.drop 
            if boll then
                VelSettings.drop = {}
                local old_grab_val = 1
                for index, value in ipairs(grabbers) do
                    VelSettings.drop[index] = {}
                    VelSettings.drop[index].high = value
                    VelSettings.drop[index].low = old_grab_val     
                    old_grab_val = value            
                end
                -- Last Group
                table.insert( VelSettings.drop, {low = old_grab_val, high = 127})
            end

        end 

        reaper.ImGui_EndPopup(ctx)
    end    
end

function LinkRightClickMenu()
    if reaper.ImGui_BeginPopupContextItem(ctx) then
        ----- Keep Start
        local retval
        retval, LinkSettings.keep_start = reaper.ImGui_Checkbox(ctx, 'Keep Start', LinkSettings.keep_start)

        reaper.ImGui_EndPopup(ctx)
    end  
end


--- Misc Functions:

function PassKeys() -- Might be a little tough on resource
    --Get keys pressed
    local active_keys = {}
    for key_val = 0,255 do
        if reaper.ImGui_IsKeyPressed(ctx, key_val, true) then -- true so holding will perform many times
            active_keys[#active_keys+1] = key_val
        end
    end

    --Send Message
    if LastWindowFocus then 
        if #active_keys > 0  then
            for k, key_val in pairs(active_keys) do
                PostKey(LastWindowFocus, key_val)
            end
        end
    end

    -- Get focus window (if not == Script Title)
    local win_focus = reaper.JS_Window_GetFocus()
    local win_name = reaper.JS_Window_GetTitle( win_focus )

    -- Need to retain the last window focused that isn't this script! 
    if LastWindowFocus ~= win_focus and (win_name == 'trackview' or win_name == 'midiview')  then -- focused win title is different? INSERT HERE
        LastWindowFocus = win_focus
    end    
end

function PostKey(hwnd, vk_code)
    reaper.JS_WindowMessage_Post(hwnd, "WM_KEYDOWN", vk_code, 0,0,0)
    reaper.JS_WindowMessage_Post(hwnd, "WM_KEYUP", vk_code, 0,0,0)
end

--- Misc
function TitleTextCenter(title_text)
    reaper.ImGui_PushFont(ctx, FontTitle) -- Says you want to start using a specific font
    TextCenter(title_text)
    reaper.ImGui_PopFont(ctx)
end

function TextCenter(text)
    local text_w, text_h = reaper.ImGui_CalcTextSize(ctx, text)
    reaper.ImGui_SetCursorPosX(ctx, Gui_W/2 - text_w/2)
    reaper.ImGui_Text(ctx, text)
end

function GetLastItemWidth()
    local minx, miny = reaper.ImGui_GetItemRectMin(ctx)
    local maxx, maxy = reaper.ImGui_GetItemRectMax(ctx)
    return maxx - minx
end

---Return Last Item Min X,Y, Max X,Y
---@return number minx min x
---@return number miny min y
---@return number maxx max x
---@return number maxy max y
function GetLastItemEdges()
    local minx, miny = reaper.ImGui_GetItemRectMin(ctx)
    local maxx, maxy = reaper.ImGui_GetItemRectMax(ctx)
    return minx, miny, maxx, maxy
end

function GetCursorX()
    reaper.ImGui_SameLine(ctx)
    local curx = reaper.ImGui_GetCursorPosX(ctx)
    reaper.ImGui_NewLine(ctx)    
    return curx
end

function DrawRectLastItem(r,g,b,a)
    local minx, miny = reaper.ImGui_GetItemRectMin(ctx)
    local maxx, maxy = reaper.ImGui_GetItemRectMax(ctx)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    --local color =  reaper.ImGui_ColorConvertRGBtoHSV( r,  g,  b,  a )
    local color =  rgba2num(r,  g,  b,  a)
    
    reaper.ImGui_DrawList_AddRectFilled(draw_list, minx-50, miny, maxx, maxy, color)
end

function rgba2num(red, green, blue, alpha)

	local blue = blue * 256
	local green = green * 256 * 256
	local red = red * 256 * 256 * 256
	
	return red + green + blue + alpha
end

function ToolTip(is_tooltip, text)
    if is_tooltip and reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_BeginTooltip(ctx)
        --reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 20)
        reaper.ImGui_PushTextWrapPos(ctx, 200)
        reaper.ImGui_Text(ctx, text)
        reaper.ImGui_PopTextWrapPos(ctx)
        reaper.ImGui_EndTooltip(ctx)
    end
end