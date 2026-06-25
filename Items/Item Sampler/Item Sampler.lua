-- @version 1.4.2b
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
--    + Added feature to select Tracks as sources
--    + New menu for displaying the Sources 
--    + Added feature for using a track as the MIDI input
--    + Added feature for selecting track(s) as targets for the new items
--    + New menu for Track Targets
--    + Remove the Presets function 
--    + Add option to copy/paste Groups settings with right click
--    + Updated ImGui to 0.10
--    + Review code


--TODOs
-- Update header require

local version = '1.4.2b'
local info = debug.getinfo(1, 'S');
local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]

package.path = package.path  .. ';' ..  reaper.ImGui_GetBuiltinPath() .. '/?.lua'
ImGui = require 'imgui' '0.10'
ctx = ImGui.CreateContext('daniellumertz_Item Sampler')


--- Loading
dofile(script_path .. 'General Functions.lua') -- General Functions needed
dofile(script_path .. 'GUI Functions.lua') -- General Functions needed
dofile(script_path .. 'groups.lua') -- General Functions needed
dofile(script_path .. 'presets.lua') -- General Functions needed
dofile(script_path .. 'REAPER Functions.lua') -- preset to work with Tables


if not CheckSWS() or not CheckReaImGUI() or not CheckJS() then return end
-- Imgui shims to 0.7.2 (added after the news at 0.8)
--dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.7.2')


function ListItems()
    local list = {}
    local count = reaper.CountSelectedMediaItems(0)
    for i = 0, count do
        local loop_item = reaper.GetSelectedMediaItem(0, i)
        table.insert(list, loop_item)
    end
    return list
end

function ListTracks(proj)
    local t = {}
    local count = reaper.CountSelectedTracks2(proj, false)
    for i = 0, count -1 do
        local track = reaper.GetSelectedTrack2(proj, i, false)
        t[#t+1] = track
    end
    return t
end

function CheckGroups() -- Return false if fails tests; return list similar to groups if pass all tests and make track sources into items

    if not ListMidi then 
        print("Select some MIDI!")
        return false
    end

    if #ListMidi < 1 then
        print("Select some MIDI!")
        return false
    end

    local new_lists = {}
    for i, value in pairs(Groups) do
        new_lists[i] = {Selected = Groups[i].Selected}
        if Groups[i].Selected == true and (not Groups[i].list_sequence or #Groups[i].list_sequence < 1) then
            print("Select some Items Sequence!")
            print("In Group "..Groups[i].name)
            return false
        elseif Groups[i].Selected == true then
            new_lists[i].list_sequence = {}
            local remove_list = {}
            for k,thing in pairs(Groups[i].list_sequence) do
                local is_item = reaper.ValidatePtr( thing, 'MediaItem*' )
                local is_track =  reaper.ValidatePtr( thing, 'MediaTrack*' )

                if is_item then
                    table.insert(new_lists[i].list_sequence, thing)
                elseif is_track then -- Transform tracks in items
                    local track = thing
                    local i_cnt = reaper.CountTrackMediaItems(track)
                    for i_idx = 0, i_cnt -1 do
                        local item = reaper.GetTrackMediaItem(track, i_idx)
                        local  retval, string = reaper.GetSetMediaItemInfo_String( item, 'P_EXT:Sampler', '', false ) -- Get Ext
                        -- Items cant be created from Item Sampler
                        if string ~= 'pasted' then 
                            table.insert(new_lists[i].list_sequence, item)
                        end
                    end 
                else
                    print('The Source #'..k..', from the group #' ..i..', was not found on your project.')
                    print('Removing this Source!')
                    remove_list[#remove_list+1] = k
                end
            end

            -- Remove not found sources
            for k, idx in ipairs(remove_list) do
                table.remove(Groups[i].list_sequence, idx)
            end
            
            -- Check if any valid sequence
            if #new_lists[i].list_sequence == 0 then
                print('No Valid Source at Group #'..i)
                return false
            end

            -- Check for Targets Tracks
            if Groups[i].Targets then
                for idx = #Groups[i].Targets, 1, -1 do
                    local track = Groups[i].Targets[idx]
                    if not reaper.ValidatePtr(track, 'MediaTrack*') then
                        table.remove(Groups[i].Targets, idx)
                    end
                end
                if #Groups[i].Targets == 0 then
                    Groups[i].Targets = nil
                end
            end
        end
    end

    -- Check ListMidi and make tracks a set of its MIDI items
    local new_midi_list = {}
    for k,thing in pairs(ListMidi) do
        local is_item = reaper.ValidatePtr( thing, 'MediaItem*' )
        local is_track = reaper.ValidatePtr( thing, 'MediaTrack*' )

        if is_track then
            local cnt_item = reaper.CountTrackMediaItems(thing) 
            for idx = 0, cnt_item - 1 do
                local item = reaper.GetTrackMediaItem(thing, idx)
                local take = reaper.GetActiveTake(item)
                local is_midi = reaper.BR_IsTakeMidi(take)
                if is_midi then
                    new_midi_list[#new_midi_list+1] = item
                end
            end
        elseif is_item then
            new_midi_list[#new_midi_list+1] = thing
        elseif not is_item and not is_track then
            print('At least one MIDI item is missing')
            print('Please reselect your Midi Items')
            return false
        end
    end

    return new_lists, new_midi_list
end

function CleanArea2(list_sequence, target_tracks, new_midi_list)
    -- Get list of tracks
    local track_erase_list = {}
    if not target_tracks or #target_tracks == 0 then
        for k,thing in ipairs(list_sequence) do
            if reaper.ValidatePtr(thing, 'MediaItem*') then
                track_erase_list[reaper.GetMediaItemTrack(thing)] = 1
            elseif  reaper.ValidatePtr(thing, 'MediaTrack*') then 
                track_erase_list[thing] = 1
            end 
        end
    else 
        for k, v in ipairs(target_tracks) do
            track_erase_list[v] = 1
        end
    end

    local edge = 0.01 -- A liitle time folga
    for track_loop,_ in pairs(track_erase_list) do
        for _,midi_item in ipairs(new_midi_list) do
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

function TryCleanArea(new_midi_list)
    for i, value in pairs(Groups) do      
        if Groups[i].Settings.Erase == true and Groups[i].Selected == true then
            CleanArea2(Groups[i].list_sequence, Groups[i].Settings.Targets, new_midi_list)
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
    local new_list, new_midi_list = CheckGroups()
    if not new_list then return end
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()

    
    TryCleanArea(new_midi_list)
    for i, v in pairs(Groups) do
        if Groups[i].Selected == true then 
            Settings = Groups[i].Settings
            --Settings.ListMidi=ListMidi
            Place_Sequence(is_random,sequence_reverse,isrand_sequence,new_midi_list, new_list[i].list_sequence) -- (is_random,sequence_reverse,isrand_sequence)
        end
    end
    reaper.Undo_EndBlock2(0, 'Item Sampler: Place Sequence', -1)
    reaper.PreventUIRefresh(-1)
    
end



function Place_Sequence(is_random,sequence_reverse,isrand_sequence,midi_items,list_sequence)
    

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

    for i_midi = 1, #midi_items do
        local item = midi_items[i_midi]
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
            local paste_track 
            if not Settings.Targets or #Settings.Targets == 0 then
                paste_track = reaper.GetMediaItemTrack(list_sequence[list_idx])
            else
                paste_track = Settings.Targets[math.random(#Settings.Targets)]
            end
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
    local r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
    return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1.0)
end

function ChangeColor(H,S,V,A)
    --ImGui.PushID(ctx, '')
    local button = HSV( H, S, V, A)
    local hover =  HSV( H, S , (V+0.4 < 1) and V+0.4 or 1 , A)
    local active = HSV( H, S, (V+0.2 < 1) and V+0.2 or 1 , A)
    ImGui.PushStyleColor(ctx, ImGui.Col_Button,  button)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, hover)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive,  active)
end

function ChangeColorButton(H,S,V,A)
    local button = HSV( H, S, V, A)
    local hover =  HSV( H, S , (V+0.4 < 1) and V+0.4 or 1 , A)
    local active = HSV( H, S, (V+0.2 < 1) and V+0.2 or 1 , A)
    ImGui.PushStyleColor(ctx, ImGui.Col_Button,  button)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, hover)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive,  active)
end

function ToolTip(text)
    if ImGui.IsItemHovered(ctx) then
        if ImGui.BeginTooltip(ctx) then
            ImGui.PushTextWrapPos(ctx, ImGui.GetFontSize(ctx) * 35.0)
            ImGui.PushTextWrapPos(ctx, 200)
            ImGui.Text(ctx, text)
            ImGui.PopTextWrapPos(ctx)
            ImGui.EndTooltip(ctx)
        end
    end
end

CounterStyle = 0 -- to undo Styles


function ResetStyleCount()
    ImGui.PopStyleColor(ctx,CounterStyle) -- Reset The Styles (NEED FOR IMGUI TO WORK)
    CounterStyle = 0
end

function ChangeColorTab(H,S,V,A)
    local button = HSV( H, S, V, A)
    local act_hover =  HSV( H, S , (V+0.4 < 1) and V+0.4 or 1 , A)
    ImGui.PushStyleColor(ctx, ImGui.Col_Tab,  button)
    ImGui.PushStyleColor(ctx, ImGui.Col_TabHovered, act_hover)
    ImGui.PushStyleColor(ctx,  ImGui.Col_TabSelected,  act_hover)
    CounterStyle = CounterStyle + 3
end


-- GUI init
function GuiInit()
    ctx = ImGui.CreateContext('Item Sequencer',ImGui.ConfigFlags_DockingEnable) -- Add VERSION TODO
    FONT = ImGui.CreateFont('sans-serif', 15) -- Create the fonts you need
    --ImGui.AttachFont(ctx, FONT)-- Attach the fonts you need
end

function loop()
    CheckProjChange()

    PushStyle()
    if not PreventPassKeys2 then -- Passthrough keys
        DL.imgui.SWSPassKeys(ctx, false)
    end
    Ctrl, Shift, Alt = GetModKeys()

    local _
    local window_flags = ImGui.WindowFlags_MenuBar 
    ImGui.SetNextWindowSize(ctx, 350, 800, ImGui.Cond_Once)-- Set the size of the windows.  Use in the 4th argument ImGui.Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2
    ImGui.PushFont(ctx, FONT, 15)

    if SetDock then
        ImGui.SetNextWindowDockID(ctx, SetDock)
        if SetDock== 0 then
            ImGui.SetNextWindowSize(ctx, 300, 700)
        end
        SetDock = nil
    end

    local visible, open  = ImGui.Begin(ctx, 'Item Sampler ' ..version, true, window_flags)


    local gui_w , gui_h = ImGui.GetContentRegionAvail(ctx)
    local gui_x, gui_y = ImGui.GetWindowPos(ctx)

    --- GUI HERE

    if visible then

        MenuBar()
        

    -- Tab Bar
    if ImGui.BeginTabBar(ctx, 'Groups', ImGui.TabBarFlags_Reorderable | ImGui.TabBarFlags_AutoSelectNewTabs ) then

        for i,v in pairs(Groups) do -- Loop Tabs
            ChangeColorTab((0.05*i),1,0.4,1) -- Change Tab Colors
            local open, keep = ImGui.BeginTabItem(ctx, ('%s###tab%d'):format(Groups[i].name, i), true) -- Start each tab

            -- Popup to rename
            local is_popup_now = false
            if ImGui.BeginPopupContextItem(ctx) then 
                if ImGui.IsWindowAppearing(ctx) then
                    --IsPopUpOpen = {}
                    --IsPopUpOpen[i] = true
                    PreventPassKeys2 = CheckPreventPassThrough(true, 'rename'..i, PreventPassKeys2) 
                end
                is_popup_now = true
                if ImGui.Button(ctx, 'Copy Settings', -1) then
                    CopyGroupSettings = table_copy(Groups[i])
                end

                if ImGui.Button(ctx, 'Paste Settings', -1) then
                    local old_name = Groups[i].name 
                    Groups[i] = table_copy(CopyGroupSettings)
                    Groups[i].name = old_name
                end

                ImGui.Separator(ctx)
                ImGui.Text(ctx, 'Edit name:')
                _, Groups[i].name = ImGui.InputText(ctx, "###", Groups[i].name)
                -- Enter
                if ImGui.IsKeyDown(ctx, ImGui.Key_Enter) then
                    PreventPassKeys2 = CheckPreventPassThrough(false, 'rename'..i, PreventPassKeys2)
                    ImGui.CloseCurrentPopup(ctx)
                end
                ImGui.EndPopup(ctx)
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
                local label = Alt and 'Get Track Sources' or 'Get Item Sources'
                if ImGui.Button(ctx, label, -1) then
                    if not Shift and not Ctrl and not Alt then -- Get Items
                        Groups[i].list_sequence = ListItems()
                    elseif Alt and not Shift and not Ctrl then -- Get Tracks
                        Groups[i].list_sequence = ListTracks(0)                        
                    elseif Shift then -- Select Sources
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
                if Settings.Tips then ToolTip("Get the selected items as the sequence of items to be placed on the notes of the MIDI Item\nShift: Select the sequence of items in the project. Hold Alt to select a track as source(s).") end

                ImGui.PopStyleColor(ctx, 3)
                --local GUIIsMaxClicked

                --Sources
                if ImGui.TreeNode(ctx, 'Sources') then
                    if ImGui.BeginListBox(ctx,  '###sourceslist',-1,150) then
                        if not Groups[i].list_sequence or #Groups[i].list_sequence == 0 then 
                            ImGui.Text(ctx, '--- No Sources Selected! ---')
                        else
                            local remove_list = {}
                            for idx, v in pairs(Groups[i].list_sequence) do
                                local is_item = reaper.ValidatePtr(v, 'MediaItem*')
                                local is_track = reaper.ValidatePtr(v, 'MediaTrack*')
                                -- Shource deleted
                                if not is_item and not is_track then
                                    remove_list[#remove_list+1] = idx
                                    goto continue
                                end
                                -- Draw Source Selectable
                                local name
                                if is_item then
                                    local take = reaper.GetActiveTake(v)
                                    local _, i_name = reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', '', false)
                                    name = 'Item: '..i_name
                                else -- Assumes is a track
                                    local _, t_name = reaper.GetSetMediaTrackInfo_String(v, 'P_NAME', '', false)
                                    if t_name == '' then
                                        local t_name_str = reaper.GetMediaTrackInfo_Value(v, 'IP_TRACKNUMBER')
                                        t_name = string.format('%d', t_name_str)
                                    end
                                    name = 'Track: '..t_name
                                end
                                if ImGui.Selectable(ctx,  name..'##Source'..idx, false) then
                                    reaper.Undo_BeginBlock()
                                    if is_item then
                                        if not Ctrl then
                                            reaper.SelectAllMediaItems(0, false)
                                        end
                                        reaper.SetMediaItemSelected(v, true)
                                    else
                                        if not Ctrl then
                                            reaper.SetOnlyTrackSelected(v)
                                        else
                                            reaper.SetTrackSelected(v, true)
                                        end
                                    end
                                    reaper.Undo_EndBlock2(0, 'Item Sampler: Select Source', -1)
                                    reaper.UpdateArrange()
                                end
                                -- Right Click
                                if ImGui.BeginPopupContextItem(ctx, name..'##ContextSource'..idx) then
                                    if ImGui.Selectable(ctx,  'Remove'..'##Source'..idx, false) then
                                        remove_list[#remove_list+1] = idx
                                    end
                                    ImGui.EndPopup(ctx)
                                end
                                ::continue::
                            end
                            -- Remove Sources
                            for r_idx = #remove_list, 1, -1 do
                                local idx = remove_list[r_idx]
                                table.remove(Groups[i].list_sequence, idx)
                            end
                        end
                        
                        ImGui.EndListBox(ctx)
                    end
                    ImGui.TreePop(ctx)
                end
                --Range
                if ImGui.TreeNode(ctx, 'Range') then

                    ImGui.PushItemWidth( ctx,  -15)
                    ImGui.Text(ctx, 'Note Range')
                    local min_note, max_note  = NumberToNote(Groups[i].Settings.NoteRange.Min), NumberToNote(Groups[i].Settings.NoteRange.Max) 
                    _, Groups[i].Settings.NoteRange.Min, Groups[i].Settings.NoteRange.Max = ImGui.DragIntRange2(ctx, '###a', Groups[i].Settings.NoteRange.Min , Groups[i].Settings.NoteRange.Max, 0.03, 0, 127,  'Min: '..min_note, "Max: "..max_note)

                    --- Pop Up Open
                    -- Check if double clicked and open pop up
                    if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked( ctx, 0) then 
                        ImGui.OpenPopup(ctx, 'str_id')
                        PreventPassKeys2 = CheckPreventPassThrough(true, 'setnote', PreventPassKeys2)
                        local mouse_x = ImGui.GetMousePos( ctx)
                        GUIIsMaxClicked = mouse_x > (gui_x + (gui_w/2) + 10) 
                    end

                    -- Pop Up
                    local popup_setnote
                    if ImGui.BeginPopup(ctx, 'str_id') then
                        popup_setnote = true
                        if ImGui.IsWindowAppearing(ctx) then
                            ImGui.SetKeyboardFocusHere(ctx)
                        end
                        if GUIIsMaxClicked == true then -------- Max Value
                            ImGui.SetNextItemWidth( ctx,  60)      
                            local max_text = NumberToNote(Groups[i].Settings.NoteRange.Max)
                            local bol, max_text = ImGui.InputText(ctx, '###New Notemax', max_text)
                            if bol then
                                max_text = MakeUpperCaseFirstLetter(max_text)
                                if  IsStringNote(max_text) then 
                                    Groups[i].Settings.NoteRange.Max  = NoteToNumber(max_text,4)
                                end
                            end
                        else ----------------------------------  Min Value
                            ImGui.SetNextItemWidth( ctx,  60) 
                            local min_text = NumberToNote(Groups[i].Settings.NoteRange.Min)
                            local bol, min_text = ImGui.InputText(ctx, '###New Notemin', min_text)
                            if bol then
                                min_text = MakeUpperCaseFirstLetter(min_text)
                                if  IsStringNote(min_text) then 
                                    Groups[i].Settings.NoteRange.Min  = NoteToNumber(min_text,4)
                                end
                            end
                        end
                        if  ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
                            ImGui.CloseCurrentPopup(ctx)
                            PreventPassKeys2 = CheckPreventPassThrough(false, 'setnote', PreventPassKeys2)
                        end
                        --boolean retval, string buf = ImGui.InputText(ImGui_Context ctx, string label, string buf, number flags = nil)
                        ImGui.EndPopup(ctx)
                    end

                    if GetSourceKey('setnote', PreventPassKeys2) and not popup_setnote then
                        PreventPassKeys2 = CheckPreventPassThrough(false, 'setnote', PreventPassKeys2)
                    end

                    if Settings.Tips then ToolTip("Set a Note Range for the Group. Only paste if MIDI note in between these notes(included)") end

                    -----------------
                    ImGui.Text(ctx, 'Velocity Range')
                    _, Groups[i].Settings.VelocityRange.Min, Groups[i].Settings.VelocityRange.Max = ImGui.DragIntRange2(ctx, '###b', Groups[i].Settings.VelocityRange.Min, Groups[i].Settings.VelocityRange.Max, 0.03, 0, 127,  'Min: %d', "Max: %d")
                    ImGui.PopItemWidth(ctx)
                    if Settings.Tips then ToolTip("Set a Velocity Range for the Group. Only paste if MIDI note velocity is in between these values(included)") end
            
                ImGui.TreePop(ctx)
                end


                --Trim
                if ImGui.TreeNode(ctx, 'Trim') then

                    if ImGui.Checkbox(ctx, 'Clean Area Before Paste',Groups[i].Settings.Erase) then
                        Groups[i].Settings.Erase = not Groups[i].Settings.Erase
                    end
                    if Settings.Tips then ToolTip("Before pasting delete Any Item in the space of the Pasted Items") end
    
                    if ImGui.Checkbox(ctx, 'Trim Items Using MIDI Item End',Groups[i].Settings.Is_trim_ItemEnd) then
                        Groups[i].Settings.Is_trim_ItemEnd = not Groups[i].Settings.Is_trim_ItemEnd
                    end
                    if Settings.Tips then ToolTip("The pasted items will be trimmed at the end of the MIDI item") end
    
                    if ImGui.Checkbox(ctx, 'Trim Items Using Start Next Midi Note',Groups[i].Settings.Is_trim_StartNextNote) then
                        Groups[i].Settings.Is_trim_StartNextNote = not Groups[i].Settings.Is_trim_StartNextNote
                    end
                    if Settings.Tips then ToolTip("The pasted items will be trimmed at the start of the next MIDI note") end
    
                    if ImGui.Checkbox(ctx, 'Trim Items Using End MIDI Note',Groups[i].Settings.Is_trim_EndNote) then
                        Groups[i].Settings.Is_trim_EndNote = not Groups[i].Settings.Is_trim_EndNote
                    end
                    if Settings.Tips then ToolTip("The pasted items will be trimmed at the end of the MIDI note") end

                ImGui.TreePop(ctx)
                end

                --Velocity
                if ImGui.TreeNode(ctx, 'Velocity') then

                    if ImGui.Checkbox(ctx, 'Velocity Change Item dB',Groups[i].Settings.Velocity) then
                        Groups[i].Settings.Velocity = not Groups[i].Settings.Velocity
                    end
                    
                    ImGui.PushItemWidth( ctx,  -120)

                    local name = 'Max dB added'
                    _, Groups[i].Settings.Vel_Max = ImGui.InputInt(ctx,  name, Groups[i].Settings.Vel_Max)
                    local focus = ImGui.IsItemFocused(ctx)
                    PreventPassKeys2 = CheckPreventPassThrough(focus, name,PreventPassKeys2)

                    local name = 'Max dB reduce'
                    _, Groups[i].Settings.Vel_Min = ImGui.InputInt(ctx,  name, Groups[i].Settings.Vel_Min)
                    local focus = ImGui.IsItemFocused(ctx)
                    PreventPassKeys2 = CheckPreventPassThrough(focus, name,PreventPassKeys2)

                    ImGui.PopItemWidth(ctx)

                    ImGui.PushItemWidth( ctx,  -120)
                    _, Groups[i].Settings.Vel_OriginalVal = ImGui.SliderInt(ctx, 'Velocity to use\noriginal Item dB', Groups[i].Settings.Vel_OriginalVal, 0, 127)
                    ImGui.PopItemWidth(ctx)

                ImGui.TreePop(ctx)
                end

                --Pitch
                if ImGui.TreeNode(ctx, 'Pitch') then

                    if ImGui.Checkbox(ctx, 'MIDI Pitch Note Change Item Pitch',Groups[i].Settings.Pitch) then
                        Groups[i].Settings.Pitch = not Groups[i].Settings.Pitch
                    end
                    
                    ImGui.PushItemWidth( ctx,  -100)
                    _, Groups[i].Settings.Pitch_Original = ImGui.SliderInt(ctx, 'Original Pitch\nat MIDI Note', Groups[i].Settings.Pitch_Original, 0, 127, NumberToNote(Groups[i].Settings.Pitch_Original, true))
                    ImGui.PopItemWidth(ctx)

                ImGui.TreePop(ctx)
                end

                --Track Target
                if ImGui.TreeNode(ctx, 'Track Target') then
                    if ImGui.Button(ctx, 'Get Selected Tracks') then
                        Groups[i].Settings.Targets = ListTracks(0)
                    end
                    if Settings.Tips then ToolTip("Select the tracks where the created items will be placed. If multiple tracks are selected, it will randomly choose one per item.") end

                    if ImGui.BeginListBox(ctx,  '###targetlist',-1,150) then
                        if Groups[i].Settings.Targets and #Groups[i].Settings.Targets > 0 then
                            local remove = {}
                            for k, v in ipairs(Groups[i].Settings.Targets) do 
                                -- Check if source is deleted
                                local is_track = reaper.ValidatePtr(v, 'MediaTrack*')
                                if not is_track then
                                    remove[#remove+1] = k
                                    goto continue
                                end
                                -- Name
                                local _, t_name = reaper.GetSetMediaTrackInfo_String(v, 'P_NAME', '', false)
                                if t_name == '' then
                                    local _
                                    local t_val = reaper.GetMediaTrackInfo_Value(v, 'IP_TRACKNUMBER')
                                    t_name = string.format('%d', t_val)
                                end
                                t_name = 'Track: '..t_name
                                -- Selectable
                                if ImGui.Selectable(ctx, t_name..'##TargetTrack'..k) then
                                    if not Ctrl then
                                        reaper.SetOnlyTrackSelected(v)
                                    else
                                        reaper.SetTrackSelected(v, true)
                                    end
                                end
                                -- Right Click
                                if ImGui.BeginPopupContextItem(ctx, t_name..'##ContextSource'..k) then
                                    if ImGui.Selectable(ctx,  'Remove'..'##Source'..k, false) then
                                        remove[#remove+1] = k
                                    end
                                    ImGui.EndPopup(ctx)
                                end
                                ::continue::
                            end
                            if #remove > 0 then
                                for idx = #remove, 1, -1 do
                                    table.remove(Groups[i].Settings.Targets, remove[idx])
                                end
                            end
                        end
                        ImGui.EndListBox(ctx)
                    end
                    ImGui.TreePop(ctx)
                end


                ImGui.EndTabItem(ctx)
            end
            
            
            if not keep then -- If Close
                table.remove(Groups,i) 
                --Groups[i] = nil
            end


        end

        if ImGui.TabItemButton(ctx, '+', ImGui.TabItemFlags_Trailing | ImGui.TabItemFlags_NoTooltip) then
            Groups[TableLen(Groups)+1] = BlankGroup:Create('G'..TableLen(Groups)+1)
        end
        ImGui.EndTabBar(ctx)
        
        ResetStyleCount()
    end


    ImGui.Separator(ctx)
    ImGui.Separator(ctx)

        --------- Get MIDI button
        ChangeColor(0.4,1,0.4,1)
        local label = Alt and 'Get MIDI Track' or 'Get MIDI Item'
        ImGui.Button(ctx, label, -2)
        if ImGui.IsItemClicked( ctx) then
            if Alt then
                ListMidi = ListTracks(0)
            else
                ListMidi = ListItems()
            end
        end
        
        if Settings.Tips then ToolTip("Select the MIDI items with the notes where the items will be placed. Hold Alt to select a tracks instead of items.") end
        ImGui.PopStyleColor(ctx, 3); 

        --------Place Button
        ChangeColor(1,1,0.4,1)
        ImGui.Button(ctx, 'Place in Sequence', -2)
        if ImGui.IsItemClicked( ctx) then
            local is_reverse = Ctrl -- is ctrl down? 
            PlaceSequenceInGroups(false, is_reverse, false)
        end
        if Settings.Tips then ToolTip("Click: Paste the items sequence in order Ctrl+Click: Paste the sequence in reverse order") end
        ImGui.PopStyleColor(ctx, 3); 


        --------Place Random
        ChangeColor(0.15,1,0.4,1)
        ImGui.Button(ctx, 'Place Random', -2)
        if ImGui.IsItemClicked( ctx) then
            local is_rand_sequence = Ctrl -- is ctrl down?
            PlaceSequenceInGroups(true, false, is_rand_sequence) 
        end
        if Settings.Tips then ToolTip("Click: Paste the items sequence randomly Ctrl+Click: Paste the sequence randomly without repetitions") end
        ImGui.PopStyleColor(ctx, 3);
        -------- List Box


        if ImGui.BeginListBox(ctx,  '###label',-1,-1) then
            for i, v in pairs(Groups) do
                ImGui.PushID(ctx, i)
                if ImGui.Selectable(ctx,  Groups[i].name, Groups[i].Selected) then
                    Groups[i].Selected = not Groups[i].Selected
                end
                ImGui.PopID(ctx)
            end
            ImGui.EndListBox(ctx)
        end

        ----
        ImGui.End(ctx)
    end        
    ImGui.PopFont(ctx)
    PopStyle()
    if open then
        reaper.defer(loop)
    end
end

function salvar(proj) -- OFF Right now
    local proj = proj or 0
    --UserPresets.LS_Hide = Settings

    UserPresets.Groups = Groups
    UserPresets.Settings = Settings
    local save = CovertUserDataToGUIDRecursive(UserPresets)
    local save = table.save(save)
    reaper.SetProjExtState( proj, 'ItemSampler', 'Groups', tostring(save) )
    --save_json(ProjectPath, 'Item Sampler configs', CovertUserDataToGUIDRecursive(Groups))
end


CheckRequirements()

ProjectPath = GetProjectPath()
LoadInitialPreseetGroups()

GuiInit()
loop()
reaper.atexit(salvar)
