local VSDEBUG = dofile("c:/Users/danie/.vscode/extensions/antoinebalaine.reascript-docs-0.1.16/debugger/LoadDebug.lua")
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

-- Main Tables
local ProjTable = {
}
ExtStates = {
    ext_name = 'daniellumertz_Item Sampler',
    sequencers = {
        key = 'SequencerSettings'
    },
    pasted = {
        seq_key = 'PastedSequencer', -- value is the Sequencer item/track GUID  
        group_key = 'PastedGroup'-- value is the group GUID  
    }
}
UserSettings = {
    tips = true
}
GUI = {
    groups_popup = {
        was_open = false
    },
    is_save = setmetatable({}, { -- if is_save[1] then save end
        __newindex = function(tbl, key, value)
            if value then
                rawset(tbl, 1, true)
            end
            -- if value is false, do nothing at all
        end
    }),
    sequencers = {
        draw_active = true,
        draw_window = {
            flags = 
                ImGui.WindowFlags_NoBackground      |
                ImGui.WindowFlags_NoTitleBar        |
                ImGui.WindowFlags_NoResize          |
                ImGui.WindowFlags_NoMove            |
                ImGui.WindowFlags_NoScrollbar       |
                ImGui.WindowFlags_NoScrollWithMouse |
                ImGui.WindowFlags_NoCollapse        |
                ImGui.WindowFlags_NoSavedSettings   |
                ImGui.WindowFlags_NoFocusOnAppearing|
                ImGui.WindowFlags_NoNav             |
                ImGui.WindowFlags_NoDecoration      |
                ImGui.WindowFlags_NoInputs -- mouse clicks pass through
        }
    }
}

--- Loading
dofile(script_path .. 'General Functions.lua') -- General Functions needed
dofile(script_path .. 'GUI Functions.lua') -- General Functions needed
dofile(script_path .. 'groups.lua') -- General Functions needed
dofile(script_path .. 'presets.lua') -- General Functions needed
dofile(script_path .. 'REAPER Functions.lua') -- preset to work with Tables
require('DL Functions.Serialize')
require('DL Functions.REAPER Items')
require('DL Functions.REAPER Enumerate')
require('DL Functions.General Table')
local is = require('Sequencer Item')


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

function IsItemPastedFromSequencer(item)
    -- Set Ext State
    local  retval, chunk = DL.item.GetExtState(item, ExtStates.ext_name, ExtStates.pasted.seq_key)
    return not (chunk == ''), chunk    
end

function CheckGroups(sequencers) -- Return false if fails tests; return list similar to groups if pass all tests and make track sources into items
    for k, sequencer in DL.t.ipairs_reverse(sequencers) do
        local proceed = false
        -- Main Sequencer 
        if not sequencer.seq then -- Probably wont happen as I am checking for the sequencer item/track every loop before this function 
            print('Sequencer Item/Track Missing!')
            table.remove(sequencers, k)
            return false
        end
        -- Solve the sequencer (will remove after pasting)
        sequencer.sequencers_solved = {}
        if sequencer.is_item then
            sequencer.sequencers_solved[#sequencer.sequencers_solved+1] = sequencer.seq
        else
            for item in DL.enum.TrackMediaItem(sequencer.seq) do
                if not IsItemPastedFromSequencer(item) then
                    local take = reaper.GetActiveTake(item)
                    if reaper.BR_IsTakeMidi(take) then
                        sequencer.sequencers_solved[#sequencer.sequencers_solved+1] = item
                    end
                end
            end

            if #sequencer.sequencers_solved == 0 then
                print('No sequencer item found!')
                return false
            end
        end

        -- Add Temporary seq guid to the sequencer table (used when cleaning items and when pasting with ext state of the guid)
        local f = (sequencer.is_item and reaper.GetSetMediaItemInfo_String) or reaper.GetSetMediaTrackInfo_String
        local _, s_guid = f(sequencer.seq, 'GUID', '', false)
        sequencer.s_guid = s_guid 
        
        -- Groups
        local groups = sequencer.groups
        for i, group in ipairs(groups) do
            group.Check = true -- true unless it fails a check
            -- Is Selected?
            if group.Selected == false then 
                goto continue
            end

            -- List Sequence
            if not group.list_sequence or #group.list_sequence == 0 then
                group.Check = false
                print('No Sources at Group '..group.name)
                goto continue
            end
            -- Make a temporary copy of List Sequence (substitute all tracks by its items)
            group.list_sources_solved = {}
            for si, source in DL.t.ipairs_reverse(group.list_sequence) do -- list_sequence are the sources 
                local is_item = reaper.ValidatePtr(source, 'MediaItem*')
                local is_track =  reaper.ValidatePtr(source, 'MediaTrack*')

                if is_item then
                    table.insert(group.list_sources_solved , source)
                elseif is_track then -- Transform tracks in items
                    local track = source
                    for item in DL.enum.TrackMediaItem(track) do
                        -- Sources cant be created from Item Sampler
                        if not IsItemPastedFromSequencer(item) then 
                            table.insert(group.list_sources_solved, item)
                        end
                    end
                else
                    print('The Source #'..si..', from the group #' ..group.name..', was not found on your project.')
                    print('Removing this Source!')
                    table.remove(group.list_sequence, si)
                end
            end

            -- Check if any valid sequence
            if #group.list_sources_solved == 0 then
                group.Check = false
                print('No Valid Source at Group '..group.name)
            end

            -- Check for Targets Tracks
            if group.Targets then
                for ti, target in DL.t.ipairs_reverse(group.Targets) do
                    if not reaper.ValidatePtr(target, 'MediaTrack*') then
                        print('At group '..group.name..' target track #'..ti..'was not found! Removing target track!')
                        table.remove(group[i].Targets, ti)
                    end
                end

                if #group.Targets == 0 then
                    group.Targets = nil
                end
            end
            proceed = true -- someone passed, something will be pasted
            ::continue::
        end
        sequencer.proceed = proceed
    end
    return true
end


-- If the pasted item found is in an open sequencer:
    -- If it is from a deleted group
        -- deleted
    -- if it is from an active/disabled(indiferent) group and their Settings.Erase = true
        -- deleted
    -- else keep it
function CleanAreas(proj, sequencers)
    local sequencers_guided = {} -- to save resources make a similar table organized by guid 
    for si, sequencer in ipairs(sequencers) do
        local s_guid = sequencer.s_guid
        sequencers_guided[s_guid] = {}
        for gi, group in ipairs(sequencer.groups) do
            local g_guid = group.Settings.GUID 
            sequencers_guided[s_guid][g_guid] = group.Settings.Erase and  group.Selected
        end
    end
    for track in DL.enum.Tracks(proj) do
        local cnt = reaper.CountTrackMediaItems(track)
        for iidx = cnt-1, 0, -1 do
            local item = reaper.GetTrackMediaItem(track, iidx)
            local _, s_guid = DL.item.GetExtState(item, ExtStates.ext_name, ExtStates.pasted.seq_key)
            if s_guid ~= '' and sequencers_guided[s_guid] then -- found a pasted item from an active sequencer
                local _, g_guid = DL.item.GetExtState(item, ExtStates.ext_name, ExtStates.pasted.group_key)
                if (sequencers_guided[s_guid][g_guid] == nil) or (sequencers_guided[s_guid][g_guid]) then -- from an deleted group or from an Settings.Erase group 
                    reaper.DeleteTrackMediaItem(track, item)
                end
            end
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

function PlaceSequenceInGroups(proj, sequencers, is_random,sequence_reverse,isrand_sequence)
    -- Check 
    local proceed = CheckGroups(sequencers)
    if not proceed then 
        print('Nothing to be pasted!')
        return false 
    end
    -- Paste
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()
        --Save Info
    local selected_items = SaveSelectedItems()
    local selected_tracks = SaveSelectedTracks()

    CleanAreas(proj, sequencers) 
    for si, sequencer in ipairs(sequencers) do
        if sequencer.proceed then
            local groups = sequencer.groups
            for gi, group in pairs(groups) do
                if group.Selected then 
                    Place_Sequence(group, sequencer, is_random,sequence_reverse,isrand_sequence) -- (is_random,sequence_reverse,isrand_sequence)
                end
            end
        end
        sequencer.proceed = nil
        sequencer.sequencers_solved = nil
    end 

    --Reset Things back
    LoadSelectedItems(selected_items)
    LoadSelectedTracks(selected_tracks)

    reaper.Undo_EndBlock2(0, 'Item Sampler: Place Sequence', -1)
    reaper.PreventUIRefresh(-1)
    
end



function Place_Sequence(group, sequencer, is_random,sequence_reverse,isrand_sequence)
    local Settings = group.Settings
    --- Use the solved tables
    local seq_items = sequencer.sequencers_solved
    local list_sequence = group.list_sources_solved
    group.list_sources_solved = nil -- not necessary to keep it after this function

    -- Paste
    local not_used
    if is_random == true and isrand_sequence == true then
        not_used = {}
        for i = 1, #list_sequence do
            not_used[i] = i
        end
    end
    local counter = 0
    for k, seq in ipairs(seq_items) do
        local item_take = reaper.GetMediaItemTake(seq, 0)
        local seq_start = reaper.GetMediaItemInfo_Value(seq, 'D_POSITION')
        local seq_len = reaper.GetMediaItemInfo_Value(seq, 'D_LENGTH')
        local seq_fim = seq_start + seq_len
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
            local note_start = reaper.MIDI_GetProjTimeFromPPQPos(item_take, startppqpos)
            local note_end = reaper.MIDI_GetProjTimeFromPPQPos(item_take, endppqpos)
            if seq_start > note_start and seq_start >= note_end then
                goto continue
            elseif seq_start > note_start then -- note before and after start of item
                note_start = seq_start
            elseif note_start < seq_fim and note_end > seq_fim then
                note_end = seq_fim
            elseif note_start > seq_fim then
                goto continue
            end 

            -- Choose Item
            local list_idx = 0
            if is_random then
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
            local pasted_item = CopyMediaItemToTrack(list_sequence[list_idx], paste_track, note_start )

            -- Set Volume Items 
            if Settings.Velocity == true then
                ChangeVolume(pasted_item, vel, Settings.Vel_OriginalVal,Settings.Vel_Min,Settings.Vel_Max)
            end
            
            -- Set Pitch 
            if Settings.Pitch == true then
                ChangePitch(pasted_item, pitch, Settings.Pitch_Original)
            end            
            

            -- Trim Item
            TrimItem(Settings, pasted_item, seq, idx_note, notecnt, item_take, endppqpos )

            -- Set Ext State
            DL.item.SetExtState(pasted_item, ExtStates.ext_name, ExtStates.pasted.group_key, group.Settings.GUID)
            DL.item.SetExtState(pasted_item, ExtStates.ext_name, ExtStates.pasted.seq_key, sequencer.s_guid)

            counter = counter + 1
            ::continue::
        end
    end
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
end

function CheckProjChange(ProjTable) 
    local current_proj = reaper.EnumProjects(-1)
    if (not OldProj) or (OldProj ~= current_proj)  then  -- Not First run or project changed
        ProjTable[current_proj] = ProjTable[current_proj] or {}
    end 

    local cnt = reaper.GetProjectStateChangeCount(current_proj)
    if ProjTable[current_proj].change_cnt ~= cnt then
        local action = reaper.Undo_CanRedo2( current_proj )
        if ProjTable[current_proj].Sequencers and action and string.match(action, 'Item Sampler:') then
            is.ReopenSequencers(current_proj, ProjTable[current_proj].Sequencers)
        end
        ProjTable[current_proj].change_cnt = cnt
    end
    OldProj = current_proj    
    return current_proj, ProjTable
end

function loop()
    local proj = CheckProjChange(ProjTable)
    PushStyle(ctx)
    if not PreventPassKeys2 then -- Passthrough keys
        DL.imgui.SWSPassKeys(ctx, false)
    end
    Ctrl, Shift, Alt = GetModKeys()

    local _
    local window_flags = ImGui.WindowFlags_MenuBar | ImGui.WindowFlags_NoNav
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
        
        
        --------- Get MIDI button
        ChangeColor(0.4,1,0.4,1)
        local label = Alt and 'Get Sequencer Track' or 'Get Sequencer Item'
        ImGui.Button(ctx, label, -2)
        if ImGui.IsItemClicked(ctx) then
            ProjTable[proj].Sequencers = is.OpenaAllSelectedMediaAsSequencer(0, not Alt)
        end
        
        if UserSettings.Tips then ToolTip("Select the MIDI items with the notes where the items will be placed. Hold Alt to select a tracks instead of items.") end
        ImGui.PopStyleColor(ctx, 3); 

        -- Check sequencers
        if ProjTable[proj].Sequencers then
            is.CheckSequencers(ProjTable[proj].Sequencers)
        end
            -- Tab Bar
        if ProjTable[proj].Sequencers and #ProjTable[proj].Sequencers > 0 then
            local sequencers = ProjTable[proj].Sequencers -- hotline
            local sequencer = sequencers[sequencers.focus]
            local groups = sequencer.groups

            -- Sequencer dropdown
            local sequencer_name = is.GetSequencerName(sequencer)
            ImGui.SetNextItemWidth(ctx, -1)
            if ImGui.BeginCombo(ctx, '##SequencersCombo', sequencer_name) then
                for k, v in ipairs(sequencers) do
                    local loop_sname = is.GetSequencerName(v)
                    if ImGui.Selectable(ctx, loop_sname..'##sequencers'..k, k == sequencers.focus) then
                        sequencers.focus = k
                    end
                end

                ImGui.EndCombo(ctx)
            end 

            ImGui.Separator(ctx)
            ImGui.Separator(ctx)
            if ImGui.BeginTabBar(ctx, 'Groups', ImGui.TabBarFlags_Reorderable | ImGui.TabBarFlags_AutoSelectNewTabs ) then
                for i,v in pairs(groups) do -- Loop Tabs
                    ChangeColorTab((0.05*i),1,0.4,1) -- Change Tab Colors
                    local open, keep = ImGui.BeginTabItem(ctx, ('%s###tab%d'):format(groups[i].name, i), true) -- Start each tab

                    -- Popup to rename
                    local is_popup_now = false
                    if ImGui.BeginPopupContextItem(ctx) then 
                        if ImGui.IsWindowAppearing(ctx) then
                            PreventPassKeys2 = CheckPreventPassThrough(true, 'rename'..i, PreventPassKeys2) 
                        end
                        is_popup_now = true
                        if ImGui.Button(ctx, 'Copy Settings', -1) then
                            CopyGroupSettings = table_copy(groups[i])
                        end

                        if ImGui.Button(ctx, 'Paste Settings', -1) then
                            local old_name = groups[i].name 
                            groups[i] = table_copy(CopyGroupSettings)
                            groups[i].name = old_name
                            GUI.is_save.check = true
                        end

                        ImGui.Separator(ctx)
                        ImGui.Text(ctx, 'Edit name:')
                        _, groups[i].name = ImGui.InputText(ctx, "###nameinput", groups[i].name)
                        -- Enter
                        if ImGui.IsKeyDown(ctx, ImGui.Key_Enter) then
                            PreventPassKeys2 = CheckPreventPassThrough(false, 'rename'..i, PreventPassKeys2)
                            ImGui.CloseCurrentPopup(ctx)
                        end

                        GUI.groups_popup.was_open = true
                        ImGui.EndPopup(ctx)
                    end

                    if GUI.groups_popup.was_open and not is_popup_now then
                        GUI.is_save.check = true
                        PreventPassKeys2 = CheckPreventPassThrough(false, 'rename'..i, PreventPassKeys2)
                        GUI.groups_popup.was_open = false
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
                                groups[i].list_sequence = ListItems()
                            elseif Alt and not Shift and not Ctrl then -- Get Tracks
                                groups[i].list_sequence = ListTracks(0)                        
                            elseif Shift then -- Select Sources
                                if groups[i].list_sequence and #groups[i].list_sequence > 1 then
                                    reaper.Undo_BeginBlock()
                                    reaper.PreventUIRefresh(1)
                                    LoadSelectedItems(groups[i].list_sequence)
                                    reaper.UpdateArrange()
                                    reaper.PreventUIRefresh(-1)
                                    reaper.Undo_EndBlock2(0, 'Item Sampler: Select Item Sequence', -1)
                                else
                                    print('No Item Sequence')
                                end
                            end

                            if not Shift then
                                GUI.is_save.check = true
                            end
                        end
                        if UserSettings.Tips then ToolTip("Get the selected items as the sequence of items to be placed on the notes of the MIDI Item\nShift: Select the sequence of items in the project. Hold Alt to select a track as source(s).") end

                        ImGui.PopStyleColor(ctx, 3)
                        --local GUIIsMaxClicked

                        --Sources
                        if ImGui.TreeNode(ctx, 'Sources') then
                            if ImGui.BeginListBox(ctx,  '###sourceslist',-1,150) then
                                if not groups[i].list_sequence or #groups[i].list_sequence == 0 then 
                                    ImGui.Text(ctx, '--- No Sources Selected! ---')
                                else
                                    local remove_list = {}
                                    for idx, v in pairs(groups[i].list_sequence) do
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
                                    if #remove_list > 0 then
                                        for r_idx = #remove_list, 1, -1 do
                                            local idx = remove_list[r_idx]
                                            table.remove(groups[i].list_sequence, idx)
                                        end
                                        GUI.is_save.check = true
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
                            local min_note, max_note  = NumberToNote(groups[i].Settings.NoteRange.Min), NumberToNote(groups[i].Settings.NoteRange.Max) 
                            GUI.is_save.check, groups[i].Settings.NoteRange.Min, groups[i].Settings.NoteRange.Max = ImGui.DragIntRange2(ctx, '###a', groups[i].Settings.NoteRange.Min , groups[i].Settings.NoteRange.Max, 0.03, 0, 127,  'Min: '..min_note, "Max: "..max_note)

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
                                    local max_text = NumberToNote(groups[i].Settings.NoteRange.Max)
                                    local bol, max_text = ImGui.InputText(ctx, '###New Notemax', max_text)
                                    if bol then
                                        max_text = MakeUpperCaseFirstLetter(max_text)
                                        if  IsStringNote(max_text) then 
                                            groups[i].Settings.NoteRange.Max  = NoteToNumber(max_text,4)
                                        end
                                        GUI.is_save.check = true
                                    end
                                else ----------------------------------  Min Value
                                    ImGui.SetNextItemWidth( ctx,  60) 
                                    local min_text = NumberToNote(groups[i].Settings.NoteRange.Min)
                                    local bol, min_text = ImGui.InputText(ctx, '###New Notemin', min_text)
                                    if bol then
                                        min_text = MakeUpperCaseFirstLetter(min_text)
                                        if  IsStringNote(min_text) then 
                                            groups[i].Settings.NoteRange.Min  = NoteToNumber(min_text,4)
                                        end
                                        GUI.is_save.check = true
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

                            if UserSettings.Tips then ToolTip("Set a Note Range for the Group. Only paste if MIDI note in between these notes(included)") end

                            -----------------
                            ImGui.Text(ctx, 'Velocity Range')
                            GUI.is_save.check, groups[i].Settings.VelocityRange.Min, groups[i].Settings.VelocityRange.Max = ImGui.DragIntRange2(ctx, '###b', groups[i].Settings.VelocityRange.Min, groups[i].Settings.VelocityRange.Max, 0.03, 0, 127,  'Min: %d', "Max: %d")
                            ImGui.PopItemWidth(ctx)
                            if UserSettings.Tips then ToolTip("Set a Velocity Range for the Group. Only paste if MIDI note velocity is in between these values(included)") end

                            ImGui.TreePop(ctx)
                        end


                        --Trim
                        if ImGui.TreeNode(ctx, 'Trim') then
                            if ImGui.Checkbox(ctx, 'Clean Area Before Paste',groups[i].Settings.Erase) then
                                groups[i].Settings.Erase = not groups[i].Settings.Erase
                                GUI.is_save.check = true
                            end
                            if UserSettings.Tips then ToolTip("Before pasting delete Any Item in the space of the Pasted Items") end
            
                            if ImGui.Checkbox(ctx, 'Trim Items Using MIDI Item End',groups[i].Settings.Is_trim_ItemEnd) then
                                groups[i].Settings.Is_trim_ItemEnd = not groups[i].Settings.Is_trim_ItemEnd
                                GUI.is_save.check = true
                            end
                            if UserSettings.Tips then ToolTip("The pasted items will be trimmed at the end of the MIDI item") end
            
                            if ImGui.Checkbox(ctx, 'Trim Items Using Start Next Midi Note',groups[i].Settings.Is_trim_StartNextNote) then
                                groups[i].Settings.Is_trim_StartNextNote = not groups[i].Settings.Is_trim_StartNextNote
                                GUI.is_save.check = true
                            end
                            if UserSettings.Tips then ToolTip("The pasted items will be trimmed at the start of the next MIDI note") end
            
                            if ImGui.Checkbox(ctx, 'Trim Items Using End MIDI Note',groups[i].Settings.Is_trim_EndNote) then
                                groups[i].Settings.Is_trim_EndNote = not groups[i].Settings.Is_trim_EndNote
                                GUI.is_save.check = true
                            end
                            if UserSettings.Tips then ToolTip("The pasted items will be trimmed at the end of the MIDI note") end

                            ImGui.TreePop(ctx)
                        end

                        --Velocity
                        if ImGui.TreeNode(ctx, 'Velocity') then

                            if ImGui.Checkbox(ctx, 'Velocity Change Item dB',groups[i].Settings.Velocity) then
                                groups[i].Settings.Velocity = not groups[i].Settings.Velocity
                                GUI.is_save.check = true
                            end
                            
                            ImGui.PushItemWidth( ctx,  -120)

                            local name = 'Max dB added'
                            GUI.is_save.check, groups[i].Settings.Vel_Max = ImGui.InputInt(ctx,  name, groups[i].Settings.Vel_Max)
                            local focus = ImGui.IsItemFocused(ctx)
                            PreventPassKeys2 = CheckPreventPassThrough(focus, name,PreventPassKeys2)

                            local name = 'Max dB reduce'
                            GUI.is_save.check, groups[i].Settings.Vel_Min = ImGui.InputInt(ctx,  name, groups[i].Settings.Vel_Min)
                            local focus = ImGui.IsItemFocused(ctx)
                            PreventPassKeys2 = CheckPreventPassThrough(focus, name,PreventPassKeys2)

                            ImGui.PopItemWidth(ctx)

                            ImGui.PushItemWidth( ctx,  -120)
                            GUI.is_save.check, groups[i].Settings.Vel_OriginalVal = ImGui.SliderInt(ctx, 'Velocity to use\noriginal Item dB', groups[i].Settings.Vel_OriginalVal, 0, 127)
                            ImGui.PopItemWidth(ctx)

                        ImGui.TreePop(ctx)
                        end

                        --Pitch
                        if ImGui.TreeNode(ctx, 'Pitch') then

                            if ImGui.Checkbox(ctx, 'MIDI Pitch Note Change Item Pitch',groups[i].Settings.Pitch) then
                                groups[i].Settings.Pitch = not groups[i].Settings.Pitch
                                GUI.is_save.check = true
                            end
                            
                            ImGui.PushItemWidth( ctx,  -100)
                            GUI.is_save.check, groups[i].Settings.Pitch_Original = ImGui.SliderInt(ctx, 'Original Pitch\nat MIDI Note', groups[i].Settings.Pitch_Original, 0, 127, NumberToNote(groups[i].Settings.Pitch_Original, true))
                            ImGui.PopItemWidth(ctx)

                        ImGui.TreePop(ctx)
                        end

                        --Track Target
                        if ImGui.TreeNode(ctx, 'Track Target') then
                            if ImGui.Button(ctx, 'Get Selected Tracks') then
                                groups[i].Settings.Targets = ListTracks(0)
                                GUI.is_save.check = true
                            end
                            if UserSettings.Tips then ToolTip("Select the tracks where the created items will be placed. If multiple tracks are selected, it will randomly choose one per item.") end

                            if ImGui.BeginListBox(ctx,  '###targetlist',-1,150) then
                                if groups[i].Settings.Targets and #groups[i].Settings.Targets > 0 then
                                    local remove = {}
                                    for k, v in ipairs(groups[i].Settings.Targets) do 
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
                                            table.remove(groups[i].Settings.Targets, remove[idx])
                                        end
                                        GUI.is_save.check = true
                                    end
                                end
                                ImGui.EndListBox(ctx)
                            end
                            ImGui.TreePop(ctx)
                        end


                        ImGui.EndTabItem(ctx)
                    end
                    
                    
                    if not keep then -- If Close
                        table.remove(groups,i) 
                        --Groups[i] = nil
                    end


                end

                if ImGui.TabItemButton(ctx, '+', ImGui.TabItemFlags_Trailing | ImGui.TabItemFlags_NoTooltip) then
                    groups[TableLen(groups)+1] = BlankGroup:Create('G'..TableLen(groups)+1)
                    GUI.is_save.check = true
                end
                ImGui.EndTabBar(ctx)
                
                ResetStyleCount()
            end


            ImGui.Separator(ctx)
            ImGui.Separator(ctx)


            --------Place Button
            ChangeColor(1,1,0.4,1)
            ImGui.Button(ctx, 'Place in Sequence', -2)
            if ImGui.IsItemClicked( ctx) then
                local is_reverse = Ctrl -- is ctrl down? 
                PlaceSequenceInGroups(proj, sequencers, false, is_reverse, false)
            end
            if UserSettings.Tips then ToolTip("Click: Paste the items sequence in order Ctrl+Click: Paste the sequence in reverse order") end
            ImGui.PopStyleColor(ctx, 3); 


            --------Place Random
            ChangeColor(0.15,1,0.4,1)
            ImGui.Button(ctx, 'Place Random', -2)
            if ImGui.IsItemClicked( ctx) then
                local is_rand_sequence = Ctrl -- is ctrl down?
                PlaceSequenceInGroups(proj, sequencers, true, false, is_rand_sequence) 
            end
            if UserSettings.Tips then ToolTip("Click: Paste the items sequence randomly Ctrl+Click: Paste the sequence randomly without repetitions") end
            ImGui.PopStyleColor(ctx, 3);
            -------- List Box


            if ImGui.BeginListBox(ctx,  '###label',-1,-1) then
                for i, v in pairs(groups) do
                    ImGui.PushID(ctx, i)
                    if ImGui.Selectable(ctx,  groups[i].name, groups[i].Selected) then
                        groups[i].Selected = not groups[i].Selected
                    end
                    ImGui.PopID(ctx)
                end
                ImGui.EndListBox(ctx)
            end

            if GUI.is_save[1] then
                is.SaveSequencer(sequencer.seq, sequencer, sequencer.is_item)
                GUI.is_save[1] = nil
            end
        end

        ----
        ImGui.End(ctx)
    end        

    --- Invisible Window
    ImGui.PopFont(ctx)
    PopStyle()

    if ImGui.Begin(ctx, 'Item Sampler: Draw Window', true, GUI.sequencers.draw_window.flags) then
        ImGui.End(ctx)
    end

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


GuiInit()
loop()
--reaper.atexit(salvar)
