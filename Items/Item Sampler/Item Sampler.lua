-- @version 1.3.6
-- @author Daniel Lumertz
-- @provides
--    [nomain] General Functions.lua
--    [nomain] presets.lua
--    [nomain] GUI Functions.lua
--    [nomain] groups.lua
--    [nomain] REAPER Functions.lua
--    [nomain] utils/*.lua
--    [main] Item Simpler.lua
-- @changelog
--    + Correct Checkers

--TODOs
-- Update header require

local version = '1.3.6'
local info = debug.getinfo(1, 'S');
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]



--- Loading
dofile(script_path .. 'General Functions.lua') -- General Functions needed
dofile(script_path .. 'GUI Functions.lua') -- General Functions needed
dofile(script_path .. 'groups.lua') -- General Functions needed
dofile(script_path .. 'presets.lua') -- General Functions needed
dofile(script_path .. 'REAPER Functions.lua') -- preset to work with Tables


if not CheckSWS() or not CheckReaImGUI() or not CheckJS() then return end
-- Imgui shims to 0.7.2 (added after the news at 0.8)
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.7.2')


function TableMin(tab)
    local min = math.huge
    for i = 1, #test_1  do
        min = min < test_1[i] and min or test_1[i]
    end
    return min
end

function ListItems()
    local list = {}
    local count = reaper.CountSelectedMediaItems(0)
    for i = 0, count do
        local loop_item = reaper.GetSelectedMediaItem(0, i)
        table.insert(list, loop_item)
    end
    return list
end

function CleanArea()
    local track_erase_list = {}
    -- Get list of tracks
    for k,item_loop in ipairs(list_sequence) do
        track_erase_list[reaper.GetMediaItemTrack(item_loop)] = 1
    end
    -- Make RE and delte
    local edge = 0.01 -- A liitle time folga
    for track_loop,_ in pairs(track_erase_list) do
        for _,midi_item in ipairs(ListMidi) do
            local item_start = reaper.GetMediaItemInfo_Value(midi_item, "D_POSITION") 
            local item_len = reaper.GetMediaItemInfo_Value(midi_item, "D_LENGTH") 
            -- Clean with Comparasion
            local count_items = reaper.CountTrackMediaItems( track_loop )
            for item_track_loop_idx = count_items-1,0,-1 do 
                local item_comparasion = reaper.GetTrackMediaItem( track_loop, item_track_loop_idx )
                local item_comparasion_start = reaper.GetMediaItemInfo_Value(item_comparasion, "D_POSITION")
                if item_comparasion_start >= item_start-edge and item_comparasion_start <= (item_start+item_len)+edge then -- If item start at the middle of the midi item
                    reaper.DeleteTrackMediaItem( track_loop, item_comparasion )
                end
                -- break sooner 
                --if item_comparasion_start < item_start then break end
            end 
            -- Clean with RE
            reaper.Main_OnCommand(42406, 0) --Razor edit: Clear all areas
            SetTrackRazorEdit(track_loop, item_start, item_start+item_len , true) --track, areaStart, areaEnd, clearSelection)
            reaper.Main_OnCommand(40697, 0) -- Remove items/tracks/envelope points (depending on focus)
        end
    end
end

function CheckGroups() -- Return false if fails tests; return true if pass all tests

    if not ListMidi then 
        print("Select some MIDI!")
        return false
    end

    if #ListMidi < 1 then
        print("Select some MIDI!")
        return false
    end

    for i, value in pairs(Groups) do
        if Groups[i].Selected == true and (not Groups[i].list_sequence or #Groups[i].list_sequence < 1) then
            print("Select some Items Sequence!")
            print("In Group "..Groups[i].name)
            return false
        elseif Groups[i].Selected == true then
            for k,item in pairs(Groups[i].list_sequence) do
                local bol = reaper.ValidatePtr( item, 'MediaItem*' )
                if bol == false then
                    print('At least one item in your sequence is missing in the group '..Groups[i].name)
                    print('Please reselect your Item Sequence')
                    return false
                end
            end

        end
    end


    for k,item in pairs(ListMidi) do
        local bol = reaper.ValidatePtr( item, 'MediaItem*' )
        if bol == false then
            print('At least one MIDI item is missing')
            print('Please reselect your Midi Items')
            return false
        end
    end
    return true
end

function Check2() -- Return false if fails tests; return true if pass all tests

    for k,item in pairs(ListMidi) do
        local bol = reaper.ValidatePtr( item, 'MediaItem*' )
        if bol == false then
            print('ERROR: At least one MIDI item is in the Paste area')
            print('Please move it away')
            print('Action canceled')
            return false
        end
    end

    
    for k,item in pairs(list_sequence) do
        local bol = reaper.ValidatePtr( item, 'MediaItem*' )
        if bol == false then
            print('ERROR: At least one item from Item Sequence is in the Paste area')
            print('Please move it away')
            print('Action canceled')
            return false
        end
    end

    return true
end

function CleanArea2(list_sequence)


    local track_erase_list = {}
    -- Get list of tracks
    

    for k,item_loop in ipairs(list_sequence) do
        track_erase_list[reaper.GetMediaItemTrack(item_loop)] = 1
    end



    local edge = 0.01 -- A liitle time folga
    for track_loop,_ in pairs(track_erase_list) do
        for _,midi_item in ipairs(ListMidi) do
            local item_start = reaper.GetMediaItemInfo_Value(midi_item, "D_POSITION") 
            local item_len = reaper.GetMediaItemInfo_Value(midi_item, "D_LENGTH") 
            -- Clean with Comparasion
            local count_items = reaper.CountTrackMediaItems( track_loop )
            for item_track_loop_idx = count_items-1,0,-1 do 
                local item_comparasion = reaper.GetTrackMediaItem( track_loop, item_track_loop_idx )
                local  retval, string = reaper.GetSetMediaItemInfo_String( item_comparasion, 'P_EXT:Sampler', '', false ) -- Get Ext
                if string ~= 'pasted' then 
                    goto continue
                end
                local item_comparasion_start = reaper.GetMediaItemInfo_Value(item_comparasion, "D_POSITION")
                if item_comparasion_start >= item_start-edge and item_comparasion_start <= (item_start+item_len)+edge then -- If item start at the middle of the midi item
                    reaper.DeleteTrackMediaItem( track_loop, item_comparasion )
                elseif item_comparasion_start < item_start then -- break sooner 
                    break
                end
                ::continue::
            end
        end
    end
    
end

function TryCleanArea()
    for i, value in pairs(Groups) do
        
        if Groups[i].Settings.Erase == true and Groups[i].Selected == true then
            CleanArea2(Groups[i].list_sequence)
        end
    end    
end

function ChangeVolume(pasted_item, vel, Vel_OriginalVal, Vel_Min, Vel_Max)
    local vol_before = reaper.GetMediaItemInfo_Value(pasted_item, 'D_VOL' )
    local delta
    if vel < Vel_OriginalVal then
        delta = scale(vel,1,Vel_OriginalVal,Vel_Min,0) -- Scale vel (1 to Vel_Original)"MIDI" to (delta Settings.Vel_Min, 0)
    elseif vel > Vel_OriginalVal then
        delta = scale(vel,Vel_OriginalVal,127,0,Vel_Max) -- Scale vel (Vel_Original to 127)"MIDI" to (delta Settings.Vel_Min, 0)
    else -- vel == Vel_OriginalVal
        return
    end
    local new_val = AddDBinLinear(vol_before, delta)
    reaper.SetMediaItemInfo_Value( pasted_item, 'D_VOL',new_val)
end


function ChangePitch(pasted_item, pitch, Pitch_Original)
    local item_take = reaper.GetMediaItemTake(pasted_item, 0)
    local pitch_before = reaper.GetMediaItemTakeInfo_Value( item_take, 'D_PITCH' )
    local delta = pitch - Pitch_Original
    reaper.SetMediaItemTakeInfo_Value( item_take, 'D_PITCH', delta + pitch_before )    
end

function PlaceSequenceInGroups(is_random,sequence_reverse,isrand_sequence)
    -- Check 
    if CheckGroups() == false then return end
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()

    
    TryCleanArea()
    for i, v in pairs(Groups) do
        if Groups[i].Selected == true then 
            list_sequence = Groups[i].list_sequence
            Settings = Groups[i].Settings
            --Settings.ListMidi=ListMidi
            Place_Sequence(is_random,sequence_reverse,isrand_sequence) -- (is_random,sequence_reverse,isrand_sequence)
        end
    end
    reaper.Undo_EndBlock2(0, 'Item Sampler: Place Sequence', -1)
    reaper.PreventUIRefresh(-1)
    
end

function Place_Sequence(is_random,sequence_reverse,isrand_sequence)
    

    --Save Info
    reaper.Undo_BeginBlock()
    --reaper.PreventUIRefresh(1)
    
    local selected_items = SaveSelectedItems()
    local selected_tracks = SaveSelectedTracks()

    -- Clean at MIDI item Not used for now Delete with time
    --[[ if Settings.Erase == true then
        CleanArea()
        if Check2() == false then
            reaper.Undo_EndBlock("Item Sequencer: Place", -1)
            reaper.Undo_DoUndo2(0)
            reaper.PreventUIRefresh(-1)
            return 
        end
    end ]]

--[[     if Settings.Erase == true then
        CleanArea2()
    end ]]

    -- Paste
    local not_used
    if is_random == true and isrand_sequence == true then
        not_used = {}
        for i = 1, #list_sequence do
            not_used[i] = i
        end
    end
    local counter = 0

    for i_midi = 1, #ListMidi do
        local item = ListMidi[i_midi]
        local item_take = reaper.GetMediaItemTake(item, 0)
        local retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(item_take)
        for idx_note = 0, notecnt-1 do
            local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( item_take, idx_note )
            -- Range
            if pitch > Settings.NoteRange.Max or pitch < Settings.NoteRange.Min then 
                goto continue 
            end
            if vel > Settings.VelocityRange.Max or pitch < Settings.VelocityRange.Min then 
                goto continue 
            end
            ----

            local quarter = reaper.MIDI_GetProjQNFromPPQPos( item_take, startppqpos )
            local time = reaper.TimeMap2_QNToTime( 0, quarter )
            -- Filter if note start is out of item bounds (before and after)

            -- Choose Item
            local list_idx = 0
            if is_random == true then
                if not isrand_sequence then -- Choose random can repeat 
                    list_idx = math.random(#list_sequence)
                else -- Choose random whitout repeating till start again
                    local rand_num = math.random(#list_sequence-(#list_sequence-#not_used))
                    list_idx = not_used[rand_num]
                    table.remove(not_used, rand_num) 
                    if #not_used == 0 then  --reset not_used list when full
                        for i = 1, #list_sequence do
                            not_used[i] = i
                        end
                    end
                end
            else
            -- Get item list idx
                if sequence_reverse == false then
                    list_idx = (counter%#list_sequence)+1
                else
                    list_idx = #list_sequence - (counter%#list_sequence)
                end
            end

            --  Copy 
            local paste_track = reaper.GetMediaItemTrack(list_sequence[list_idx])
            local pasted_item = CopyMediaItemToTrack(list_sequence[list_idx], paste_track, time )

            -- Set Volume Items 
            if Settings.Velocity == true then
                ChangeVolume(pasted_item, vel, Settings.Vel_OriginalVal,Settings.Vel_Min,Settings.Vel_Max)
            end
            
            -- Set Pitch 
            if Settings.Pitch == true then
                ChangePitch(pasted_item, pitch, Settings.Pitch_Original)
            end            
            

            -- Trim Item
            TrimItem(pasted_item, item, idx_note, notecnt, item_take, endppqpos )

            -- Set Ext State
            local  retval, stringNeedBig = reaper.GetSetMediaItemInfo_String( pasted_item, 'P_EXT:Sampler', 'pasted', true ) -- Set

            counter = counter + 1
            ::continue::
        end
    end

    --Reset Things back
    LoadSelectedItems(selected_items)
    LoadSelectedTracks(selected_tracks)

    --reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Item Sequencer: Place", -1)
end

------ Gui Func
function HSV(h, s, v, a)
    local r, g, b = reaper.ImGui_ColorConvertHSVtoRGB(h, s, v)
    return reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a or 1.0)
end

function ChangeColor(H,S,V,A)
    reaper.ImGui_PushID(ctx, 3)
    local button = HSV( H, S, V, A)
    local hover =  HSV( H, S , (V+0.4 < 1) and V+0.4 or 1 , A)
    local active = HSV( H, S, (V+0.2 < 1) and V+0.2 or 1 , A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),  button)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), hover)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  active)
end

function ChangeColorButton(H,S,V,A)
    local button = HSV( H, S, V, A)
    local hover =  HSV( H, S , (V+0.4 < 1) and V+0.4 or 1 , A)
    local active = HSV( H, S, (V+0.2 < 1) and V+0.2 or 1 , A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),  button)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), hover)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  active)
end

function ToolTip(text)
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_BeginTooltip(ctx)
        reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 35.0)
        reaper.ImGui_PushTextWrapPos(ctx, 200)
        reaper.ImGui_Text(ctx, text)
        reaper.ImGui_PopTextWrapPos(ctx)
        reaper.ImGui_EndTooltip(ctx)
    end
end

CounterStyle = 0 -- to undo Styles


function ResetStyleCount()
    reaper.ImGui_PopStyleColor(ctx,CounterStyle) -- Reset The Styles (NEED FOR IMGUI TO WORK)
    CounterStyle = 0
end

function ChangeColorTab(H,S,V,A)
    local button = HSV( H, S, V, A)
    local act_hover =  HSV( H, S , (V+0.4 < 1) and V+0.4 or 1 , A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Tab(),  button)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabHovered(), act_hover)
    reaper.ImGui_PushStyleColor(ctx,  reaper.ImGui_Col_TabActive(),  act_hover)
    CounterStyle = CounterStyle + 3
end


-- GUI init
function GuiInit()
    ctx = reaper.ImGui_CreateContext('Item Sequencer',reaper.ImGui_ConfigFlags_DockingEnable()) -- Add VERSION TODO
    FONT = reaper.ImGui_CreateFont('sans-serif', 15) -- Create the fonts you need
    reaper.ImGui_AttachFont(ctx, FONT)-- Attach the fonts you need
end

function loop()
    CheckProjChange()

    PushStyle()
    if not PreventPassKeys2 then -- Passthrough keys
        PassThorugh()
    end
    Ctrl, Shift, Alt = GetModKeys()

    local _
    local window_flags = reaper.ImGui_WindowFlags_MenuBar() 
    reaper.ImGui_SetNextWindowSize(ctx, 300, 700, reaper.ImGui_Cond_Once())-- Set the size of the windows.  Use in the 4th argument reaper.ImGui_Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2
    reaper.ImGui_PushFont(ctx, FONT)

    if SetDock then
        reaper.ImGui_SetNextWindowDockID(ctx, SetDock)
        if SetDock== 0 then
            reaper.ImGui_SetNextWindowSize(ctx, 300, 700)
        end
        SetDock = nil
    end

    local visible, open  = reaper.ImGui_Begin(ctx, 'Item Sampler ' ..version, true, window_flags)


    local gui_w , gui_h = reaper.ImGui_GetContentRegionAvail(ctx)
    local gui_x, gui_y = reaper.ImGui_GetWindowPos(ctx)

    --- GUI HERE

    if visible then

        MenuBar()
        

    -- Tab Bar
    if reaper.ImGui_BeginTabBar(ctx, 'Groups', reaper.ImGui_TabBarFlags_Reorderable() | reaper.ImGui_TabBarFlags_AutoSelectNewTabs() ) then

        for i,v in pairs(Groups) do -- Loop Tabs
            ChangeColorTab((0.05*i),1,0.4,1) -- Change Tab Colors
            local open, keep = reaper.ImGui_BeginTabItem(ctx, ('%s###tab%d'):format(Groups[i].name, i), true) -- Start each tab

            -- Popup to rename
            local is_popup_now = false
            if reaper.ImGui_BeginPopupContextItem(ctx) then 
                if reaper.ImGui_IsWindowAppearing(ctx) then
                    --IsPopUpOpen = {}
                    --IsPopUpOpen[i] = true
                    PreventPassKeys2 = CheckPreventPassThrough(true, 'rename'..i, PreventPassKeys2) 
                end
                is_popup_now = true
                reaper.ImGui_Text(ctx, 'Edit name:')
                _, Groups[i].name = reaper.ImGui_InputText(ctx, "###", Groups[i].name)
                -- Enter
                if reaper.ImGui_IsKeyDown(ctx, 13) then
                    PreventPassKeys2 = CheckPreventPassThrough(false, 'rename'..i, PreventPassKeys2)
                    reaper.ImGui_CloseCurrentPopup(ctx)
                end
                reaper.ImGui_EndPopup(ctx)
            end

            if PreventPassKeys2 and not is_popup_now then
                PreventPassKeys2 = CheckPreventPassThrough(false, 'rename'..i, PreventPassKeys2)
                IsPopUpOpen = nil
            end

            if open then -- Inside Each Tab
                
                --Do Things at this tab

                --Item Group
                        --------- Get Items sequence Buttons
                ChangeColorButton((0.05*i),1,0.4,1)
                if reaper.ImGui_Button(ctx, 'Get Item Sequence', -1) then
                    if not Shift and not Ctrl then
                        Groups[i].list_sequence = ListItems()
                    elseif Shift then
                        if Groups[i].list_sequence and #Groups[i].list_sequence > 1 then
                            reaper.Undo_BeginBlock()
                            reaper.PreventUIRefresh(1)
                            LoadSelectedItems(Groups[i].list_sequence)
                            reaper.UpdateArrange()
                            reaper.PreventUIRefresh(-1)
                            reaper.Undo_EndBlock2(0, 'Item Sampler: Select Item Sequence', -1)
                        else
                            print('No Item Sequence')
                        end
                    end
                end
                if Settings.Tips then ToolTip("Get the selected items as the sequence of items to be placed on the notes of the MIDI Item\nShift: Select the sequence of items in the project") end

                reaper.ImGui_PopStyleColor(ctx, 3)
                --local GUIIsMaxClicked
                --Range
                if reaper.ImGui_TreeNode(ctx, 'Range') then

                    reaper.ImGui_PushItemWidth( ctx,  -15)
                    reaper.ImGui_Text(ctx, 'Note Range')
                    local min_note, max_note  = NumberToNote(Groups[i].Settings.NoteRange.Min), NumberToNote(Groups[i].Settings.NoteRange.Max) 
                    _, Groups[i].Settings.NoteRange.Min, Groups[i].Settings.NoteRange.Max = reaper.ImGui_DragIntRange2(ctx, '###a', Groups[i].Settings.NoteRange.Min , Groups[i].Settings.NoteRange.Max, 0.03, 0, 127,  'Min: '..min_note, "Max: "..max_note)

                    --- Pop Up Open
                    -- Check if double clicked and open pop up
                    if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked( ctx, 0) then 
                        reaper.ImGui_OpenPopup(ctx, 'str_id')
                        PreventPassKeys2 = CheckPreventPassThrough(true, 'setnote', PreventPassKeys2)
                        local mouse_x = reaper.ImGui_GetMousePos( ctx)
                        GUIIsMaxClicked = mouse_x > (gui_x + (gui_w/2) + 10) 
                    end

                    -- Pop Up
                    local popup_setnote
                    if reaper.ImGui_BeginPopup(ctx, 'str_id') then
                        popup_setnote = true
                        if reaper.ImGui_IsWindowAppearing(ctx) then
                            reaper.ImGui_SetKeyboardFocusHere(ctx)
                        end
                        if GUIIsMaxClicked == true then -------- Max Value
                            reaper.ImGui_SetNextItemWidth( ctx,  60)                          
                            local bol, temp_note_name = reaper.ImGui_InputText(ctx, '###New Note', temp_note_name)
                            temp_note_name = MakeUpperCaseFirstLetter(temp_note_name)
                            if  IsStringNote(temp_note_name) then 
                                Groups[i].Settings.NoteRange.Max  = NoteToNumber(temp_note_name,4)
                            end
                        else ----------------------------------  Min Value
                            reaper.ImGui_SetNextItemWidth( ctx,  60)                            
                            local bol, temp_note_name = reaper.ImGui_InputText(ctx, '###New Note', temp_note_name)
                            temp_note_name = MakeUpperCaseFirstLetter(temp_note_name)
                            if  IsStringNote(temp_note_name) then 
                                Groups[i].Settings.NoteRange.Min  = NoteToNumber(temp_note_name,4)
                            end
                        end
                        if  reaper.ImGui_IsKeyPressed(ctx, 13) then
                            reaper.ImGui_CloseCurrentPopup(ctx)
                            PreventPassKeys2 = CheckPreventPassThrough(false, 'setnote', PreventPassKeys2)
                        end
                        --boolean retval, string buf = reaper.ImGui_InputText(ImGui_Context ctx, string label, string buf, number flags = nil)
                        reaper.ImGui_EndPopup(ctx)
                    end

                    if GetSourceKey('setnote', PreventPassKeys2) and not popup_setnote then
                        PreventPassKeys2 = CheckPreventPassThrough(false, 'setnote', PreventPassKeys2)
                    end

                    if Settings.Tips then ToolTip("Set a Note Range for the Group. Only paste if MIDI note in between these notes(included)") end

                    -----------------
                    reaper.ImGui_Text(ctx, 'Velocity Range')
                    _, Groups[i].Settings.VelocityRange.Min, Groups[i].Settings.VelocityRange.Max = reaper.ImGui_DragIntRange2(ctx, '###b', Groups[i].Settings.VelocityRange.Min, Groups[i].Settings.VelocityRange.Max, 0.03, 0, 127,  'Min: %d', "Max: %d")
                    reaper.ImGui_PopItemWidth(ctx)
                    if Settings.Tips then ToolTip("Set a Velocity Range for the Group. Only paste if MIDI note velocity is in between these values(included)") end
            
                reaper.ImGui_TreePop(ctx)
                end


                --Trim
                if reaper.ImGui_TreeNode(ctx, 'Trim', reaper.ImGui_TreeNodeFlags_DefaultOpen()) then

                    if reaper.ImGui_Checkbox(ctx, 'Clean Area Before Paste',Groups[i].Settings.Erase) then
                        Groups[i].Settings.Erase = not Groups[i].Settings.Erase
                    end
                    if Settings.Tips then ToolTip("Before pasting delete Any Item in the space of the Pasted Items") end
    
                    if reaper.ImGui_Checkbox(ctx, 'Trim Items Using MIDI Item End',Groups[i].Settings.Is_trim_ItemEnd) then
                        Groups[i].Settings.Is_trim_ItemEnd = not Groups[i].Settings.Is_trim_ItemEnd
                    end
                    if Settings.Tips then ToolTip("The pasted items will be trimmed at the end of the MIDI item") end
    
                    if reaper.ImGui_Checkbox(ctx, 'Trim Items Using Start Next Midi Note',Groups[i].Settings.Is_trim_StartNextNote) then
                        Groups[i].Settings.Is_trim_StartNextNote = not Groups[i].Settings.Is_trim_StartNextNote
                    end
                    if Settings.Tips then ToolTip("The pasted items will be trimmed at the start of the next MIDI note") end
    
                    if reaper.ImGui_Checkbox(ctx, 'Trim Items Using End MIDI Note',Groups[i].Settings.Is_trim_EndNote) then
                        Groups[i].Settings.Is_trim_EndNote = not Groups[i].Settings.Is_trim_EndNote
                    end
                    if Settings.Tips then ToolTip("The pasted items will be trimmed at the end of the MIDI note") end

                reaper.ImGui_TreePop(ctx)
                end

                --Velocity
                if reaper.ImGui_TreeNode(ctx, 'Velocity', reaper.ImGui_TreeNodeFlags_DefaultOpen()) then

                    if reaper.ImGui_Checkbox(ctx, 'Velocity Change Item dB',Groups[i].Settings.Velocity) then
                        Groups[i].Settings.Velocity = not Groups[i].Settings.Velocity
                    end
                    
                    reaper.ImGui_PushItemWidth( ctx,  -100)

                    local name = 'Max dB added'
                    _, Groups[i].Settings.Vel_Max = reaper.ImGui_InputInt(ctx,  name, Groups[i].Settings.Vel_Max)
                    local focus = reaper.ImGui_IsItemFocused(ctx)
                    PreventPassKeys2 = CheckPreventPassThrough(focus, name,PreventPassKeys2)

                    local name = 'Max dB reduce'
                    _, Groups[i].Settings.Vel_Min = reaper.ImGui_InputInt(ctx,  name, Groups[i].Settings.Vel_Min)
                    local focus = reaper.ImGui_IsItemFocused(ctx)
                    PreventPassKeys2 = CheckPreventPassThrough(focus, name,PreventPassKeys2)

                    reaper.ImGui_PopItemWidth(ctx)

                    reaper.ImGui_PushItemWidth( ctx,  -100)
                    _, Groups[i].Settings.Vel_OriginalVal = reaper.ImGui_SliderInt(ctx, 'Velocity to use\noriginal Item dB', Groups[i].Settings.Vel_OriginalVal, 0, 127)
                    reaper.ImGui_PopItemWidth(ctx)

                reaper.ImGui_TreePop(ctx)
                end

                --Pitch
                if reaper.ImGui_TreeNode(ctx, 'Pitch', reaper.ImGui_TreeNodeFlags_DefaultOpen()) then

                    if reaper.ImGui_Checkbox(ctx, 'MIDI Pitch Note Change Item Pitch',Groups[i].Settings.Pitch) then
                        Groups[i].Settings.Pitch = not Groups[i].Settings.Pitch
                    end
                    
                    reaper.ImGui_PushItemWidth( ctx,  -100)
                    _, Groups[i].Settings.Pitch_Original = reaper.ImGui_SliderInt(ctx, 'Original Pitch\nat MIDI Note', Groups[i].Settings.Pitch_Original, 0, 127, NumberToNote(Groups[i].Settings.Pitch_Original, true))
                    reaper.ImGui_PopItemWidth(ctx)

                reaper.ImGui_TreePop(ctx)
                end


                reaper.ImGui_EndTabItem(ctx)
            end
            
            if not keep then -- If Close
                table.remove(Groups,i) 
                --Groups[i] = nil
            end


        end

        if reaper.ImGui_TabItemButton(ctx, '+', reaper.ImGui_TabItemFlags_Trailing() | reaper.ImGui_TabItemFlags_NoTooltip()) then
            Groups[TableLen(Groups)+1] = BlankGroup:Create('G'..TableLen(Groups)+1)
        end
        reaper.ImGui_EndTabBar(ctx)
        
        ResetStyleCount()
    end


    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Separator(ctx)

        --------- Get MIDI button
        ChangeColor(0.4,1,0.4,1)
        reaper.ImGui_Button(ctx, 'Get MIDI Item', -2)
        if reaper.ImGui_IsItemClicked( ctx) then
            ListMidi = ListItems()
        end
        if Settings.Tips then ToolTip("Select the MIDI items with the notes where the items will be placed") end
        reaper.ImGui_PopStyleColor(ctx, 3); reaper.ImGui_PopID(ctx)




        --------Place Button

        ChangeColor(1,1,0.4,1)
        reaper.ImGui_Button(ctx, 'Place in Sequence', -2)
        if reaper.ImGui_IsItemClicked( ctx) then
            local is_reverse = Ctrl -- is ctrl down? 
            PlaceSequenceInGroups(false, is_reverse, false)
        end
        if Settings.Tips then ToolTip("Click: Paste the items sequence in order Ctrl+Click: Paste the sequence in reverse order") end
        reaper.ImGui_PopStyleColor(ctx, 3); reaper.ImGui_PopID(ctx)


        --------Place Random
        ChangeColor(0.15,1,0.4,1)
        reaper.ImGui_Button(ctx, 'Place Random', -2)
        if reaper.ImGui_IsItemClicked( ctx) then
            local is_rand_sequence = Ctrl -- is ctrl down?
            PlaceSequenceInGroups(true, false, is_rand_sequence) 
        end
        if Settings.Tips then ToolTip("Click: Paste the items sequence randomly Ctrl+Click: Paste the sequence randomly without repetitions") end
        reaper.ImGui_PopStyleColor(ctx, 3); reaper.ImGui_PopID(ctx)

        -------- List Box


        if reaper.ImGui_BeginListBox(ctx,  '###label',-1,-1) then
            for i, v in pairs(Groups) do
                reaper.ImGui_PushID(ctx, i)
                if reaper.ImGui_Selectable(ctx,  Groups[i].name, Groups[i].Selected) then
                    Groups[i].Selected = not Groups[i].Selected
                end
                reaper.ImGui_PopID(ctx)
            end
            reaper.ImGui_EndListBox(ctx)
        end

        ----
        reaper.ImGui_End(ctx)
    end        
    reaper.ImGui_PopFont(ctx)
    PopStyle()
    if open then
        reaper.defer(loop)
    else
        reaper.ImGui_DestroyContext(ctx)
    end
end

function salvar(proj) -- OFF Right now
    local proj = proj or 0
    --UserPresets.LS_Hide = Settings

    UserPresets.Groups = Groups
    UserPresets.Settings = Settings
    local save = CovertUserDataToGUIDRecursive(UserPresets)
    local save = table.save(save)
    reaper.SetProjExtState( proj, 'ItemSampler', 'Groups', save )
    --save_json(ProjectPath, 'Item Sampler configs', CovertUserDataToGUIDRecursive(Groups))
end


CheckRequirements()

ProjectPath = GetProjectPath()
LoadInitialPreseetGroups()

GuiInit()
loop()
reaper.atexit(salvar)
