-- @version 1.0
-- @author Daniel Lumertz
-- @changelog
--    + Initial Release


local version = 1.0

function TrimEnd(item, amount, pos, is_pos)
    local start = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
    local len = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
    if is_pos == true then
        local start = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
        amount = (len + start) - pos
    end
    local take = reaper.GetMediaItemTake(item, 0)
    if reaper.TakeIsMIDI( take ) == true then
        reaper.MIDI_SetItemExtents( item,  reaper.TimeMap2_timeToQN( 0,start ),  reaper.TimeMap2_timeToQN( 0,start+len-amount) )
    else
        reaper.SetMediaItemInfo_Value( item, 'D_LENGTH' , len-amount )
    end
end

function TrimStart(item, amount, pos, is_pos)
    local len = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
    local start = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
    local take = reaper.GetMediaItemTake( item, 0 )
    local off = reaper.GetMediaItemTakeInfo_Value( take, 'D_STARTOFFS' )
    if is_pos == true then
        amount = pos - start
    end
    local take = reaper.GetMediaItemTake(item, 0)
    if reaper.TakeIsMIDI( take ) == true then
        reaper.MIDI_SetItemExtents( item,  reaper.TimeMap2_timeToQN( 0,start + amount ),  reaper.TimeMap2_timeToQN( 0,len + start) )
    else
        reaper.SetMediaItemInfo_Value( item, 'D_POSITION' , start + amount )
        reaper.SetMediaItemTakeInfo_Value( take, 'D_STARTOFFS', off + amount )
        reaper.SetMediaItemInfo_Value( item, 'D_LENGTH' , (len-amount) )
    end
end

function print(val)
    reaper.ShowConsoleMsg("\n"..tostring(val))    
end



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

function SaveSelectedItems()
    local list = {}
    local num = reaper.CountSelectedMediaItems(0)
    if num ~= 0 then
        for i= 0, num-1 do
            list[i+1] =  reaper.GetSelectedMediaItem( 0, i )
        end
    end
    reaper.Main_OnCommand(40289, 0)--Item: Unselect all items
    return list
end

function LoadSelectedItems(list)
    reaper.Main_OnCommand(40289, 0)--Item: Unselect all items
    if #list ~= 0 then 
        for i = 1, #list do 
            reaper.SetMediaItemSelected( list[i], true )
        end 
    end
end

function SaveSelectedTracks()
    local list = {}
    local num = reaper.CountSelectedTracks2(0, true)
    if num ~= 0 then
        for i= 0, num-1 do
            list[i+1] =  reaper.GetSelectedTrack2(0, i, true)
        end
    end
    reaper.Main_OnCommand(40297, 0)--Track: Unselect all tracks
    return list
end

function LoadSelectedTracks(list)
    reaper.Main_OnCommand(40297, 0)--Track: Unselect all tracks
    if #list ~= 0 then 
        for i = 1, #list do 
            reaper.SetTrackSelected( list[i], true )
        end 
    end
end

function SetTrackRazorEdit(track, areaStart, areaEnd, clearSelection)
    if clearSelection == nil then clearSelection = false end
    
    if clearSelection then
        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', '', false)
    
        --parse string, all this string stuff could probably be written better
        local str = {}
        for j in string.gmatch(area, "%S+") do
            table.insert(str, j)
        end
        
        --strip existing selections across the track
        local j = 1
        while j <= #str do
            local GUID = str[j+2]
            if GUID == '""' then 
                str[j] = ''
                str[j+1] = ''
                str[j+2] = ''
            end

            j = j + 3
        end

        --insert razor edit 
        local REstr = tostring(areaStart) .. ' ' .. tostring(areaEnd) .. ' ""'
        table.insert(str, REstr)

        local finalStr = ''
        for i = 1, #str do
            local space = i == 1 and '' or ' '
            finalStr = finalStr .. space .. str[i]
        end

        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', finalStr, true)
        return ret
    else         
        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', '', false)
        local str = area ~= nil and area .. ' ' or ''
        str = str .. tostring(areaStart) .. ' ' .. tostring(areaEnd) .. '  ""'
        
        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', str, true)
        return ret
    end
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
        for _,midi_item in ipairs(list_midi) do
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

function CopyMediaItemToTrack( item, track, position ) -- Thanks Amagalma s2
    local _, chunk = reaper.GetItemStateChunk( item, "", false )
    chunk = chunk:gsub("{.-}", "") -- Reaper auto-generates all GUIDs
    local new_item = reaper.AddMediaItemToTrack( track )
    reaper.SetItemStateChunk( new_item, chunk, false )
    reaper.SetMediaItemInfo_Value( new_item, "D_POSITION" , position )
    return new_item
end

function TrimItem(pasted_item, item, idx_note, notecnt, item_take, endppqpos )
    if Is_trim_ItemEnd == true  or Is_trim_StartNextNote == true or Is_trim_EndNote == true then
        local pasted_start = reaper.GetMediaItemInfo_Value(pasted_item, "D_POSITION")
        local pasted_len = reaper.GetMediaItemInfo_Value(pasted_item, "D_LENGTH")
        local pasted_end = pasted_start + pasted_len

        local trim_values = {}
        
        if Is_trim_ItemEnd == true then 
            local midi_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local midi_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            local midi_end = midi_start + midi_len
            table.insert(trim_values, midi_end)
        end

        if Is_trim_StartNextNote == true and idx_note < notecnt-1 then -- Cant be the last note
            local _, _, _, startppqpos_next, _, _, _, _ = reaper.MIDI_GetNote( item_take, idx_note+1 )
            local quarter_next = reaper.MIDI_GetProjQNFromPPQPos( item_take, startppqpos_next )
            local time_next = reaper.TimeMap2_QNToTime( 0, quarter_next )
            table.insert(trim_values, time_next)
        end

        if Is_trim_EndNote == true then -- Cant be the last note
            local quarter_end = reaper.MIDI_GetProjQNFromPPQPos( item_take, endppqpos )
            local time_end = reaper.TimeMap2_QNToTime( 0, quarter_end )
            table.insert(trim_values, time_end)
        end

        table.sort(trim_values)
        local shortest_value = trim_values[1]

        if pasted_end > shortest_value then -- Always compare so it don't extend always reduce
            TrimEnd(pasted_item, 0, shortest_value, true)
        end

        --[[ if pasted_start < midi_start then -- Filter out note that start before the item or make this always happening
            TrimStart(pasted_item, 0, midi_start, true)
        end ]]
    end
end

function Check() -- Return false if fails tests; return true if pass all tests

    if not list_midi then 
        print("Select some MIDI!")
        return false
    end

    if not list_sequence then
        print("Select some Items Sequence!")
        return false
    end

    if #list_midi < 1 then
        print("Select some MIDI!")
        return false
    end

    if #list_sequence < 1  then
        print("Select some Items Sequence!")
        return false
    end

    for k,item in pairs(list_midi) do
        local bol = reaper.ValidatePtr( item, 'MediaItem*' )
        if bol == false then
            print('At least one MIDI item is missing')
            print('Please reselect your Midi Items')
            return false
        end
    end

    
    for k,item in pairs(list_sequence) do
        local bol = reaper.ValidatePtr( item, 'MediaItem*' )
        if bol == false then
            print('At least one item in your sequence is missing')
            print('Please reselect your Item Sequence')
            return false
        end
    end

    return true
end

function Check2() -- Return false if fails tests; return true if pass all tests

    for k,item in pairs(list_midi) do
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

function CleanArea2()
    local track_erase_list = {}
    -- Get list of tracks
    for k,item_loop in ipairs(list_sequence) do
        track_erase_list[reaper.GetMediaItemTrack(item_loop)] = 1
    end

    local edge = 0.01 -- A liitle time folga
    for track_loop,_ in pairs(track_erase_list) do
        for _,midi_item in ipairs(list_midi) do
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

function AddDBinLinear(valbefore, addval )
    local val_before_in_DB = 20 * math.log(valbefore,10) -- Linear to dB
    local dB_newval = val_before_in_DB + addval -- add to dB
    local new_linear = 10^(dB_newval/20) -- dB to Linear
    return new_linear
end

function scale(val,min1,max1,min2,max2)
    return (((max2 - min2)*(val - min1))/(max1 - min1))+min2
end

function ChangeVolume(pasted_item, vel, Vel_OriginalVal,Vel_Min,Vel_Max)
    local vol_before = reaper.GetMediaItemInfo_Value(pasted_item, 'D_VOL' )
    local delta
    if vel < Vel_OriginalVal then
        delta = scale(vel,1,Vel_OriginalVal,Vel_Min,0) -- Scale vel (1 to Vel_Original)"MIDI" to (delta Vel_Min, 0)
    elseif vel > Vel_OriginalVal then
        delta = scale(vel,Vel_OriginalVal,127,0,Vel_Max) -- Scale vel (Vel_Original to 127)"MIDI" to (delta Vel_Min, 0)
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

function Place_Sequence(is_random,sequence_reverse,isrand_sequence)
    -- Check 
    if Check() == false then return end
    --Save Info
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    
    local selected_items = SaveSelectedItems()
    local selected_tracks = SaveSelectedTracks()

    -- Clean at MIDI item Not used for now Delete with time
    --[[ if Erase == true then
        CleanArea()
        if Check2() == false then
            reaper.Undo_EndBlock("Item Sequencer: Place", -1)
            reaper.Undo_DoUndo2(0)
            reaper.PreventUIRefresh(-1)
            return 
        end
    end ]]

    if Erase == true then
        CleanArea2(item)
    end

    -- Paste
    if is_random == true and isrand_sequence == true then
        not_used = {}
        for i = 1, #list_sequence do
            not_used[i] = i
        end
    end
    local counter = 0
    for i_midi = 1, #list_midi do
        local item = list_midi[i_midi]
        local item_take = reaper.GetMediaItemTake(item, 0)
        local retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(item_take)
        for idx_note = 0, notecnt-1 do
            local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( item_take, idx_note )
            local quarter = reaper.MIDI_GetProjQNFromPPQPos( item_take, startppqpos )
            local time = reaper.TimeMap2_QNToTime( 0, quarter )
            -- Filter if note start is out of item bounds (before and after)

            -- Choose Item
            local list_idx = 0
            if is_random == true then
                if isrand_sequence == false then -- Choose random can repeat 
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
            if Velocity == true then
                ChangeVolume(pasted_item, vel, Vel_OriginalVal,Vel_Min,Vel_Max)
            end
            
            -- Set Pitch 
            if Pitch == true then
                ChangePitch(pasted_item, pitch, Pitch_Original)
            end            
            

            -- Trim Item
            TrimItem(pasted_item, item, idx_note, notecnt, item_take, endppqpos )

            -- Set Ext State
            local  retval, stringNeedBig = reaper.GetSetMediaItemInfo_String( pasted_item, 'P_EXT:Sampler', 'pasted', true ) -- Set

            counter = counter + 1
        end
    end

    --Reset Things back
    LoadSelectedItems(selected_items)
    LoadSelectedTracks(selected_tracks)

    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Item Sequencer: Place", -1)
end

------ Gui Func
function ChangeColor(H,S,V,A)
    reaper.ImGui_PushID(ctx, 3)
    local button = reaper.ImGui_ColorConvertHSVtoRGB( H, S, V, A)
    local hover =  reaper.ImGui_ColorConvertHSVtoRGB( H, S , (V+0.4 < 1) and V+0.4 or 1 , A)
    local active = reaper.ImGui_ColorConvertHSVtoRGB( H, S, (V+0.2 < 1) and V+0.2 or 1 , A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),  button)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), hover)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  active)
end

function ToolTip(text)
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_BeginTooltip(ctx)
        reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 35.0)
        reaper.ImGui_Text(ctx, text)
        reaper.ImGui_PopTextWrapPos(ctx)
        reaper.ImGui_EndTooltip(ctx)
    end
end

-- GUI init
function GuiInit()
    ctx = reaper.ImGui_CreateContext('Item Sequencer') -- Add VERSION TODO
    FONT = reaper.ImGui_CreateFont('sans-serif', 15) -- Create the fonts you need
    reaper.ImGui_AttachFont(ctx, FONT)-- Attach the fonts you need
end

function loop()

    local window_flags = reaper.ImGui_WindowFlags_MenuBar() 
    reaper.ImGui_SetNextWindowSize(ctx, 250, 300, reaper.ImGui_Cond_Once())-- Set the size of the windows.  Use in the 4th argument reaper.ImGui_Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2
    reaper.ImGui_PushFont(ctx, FONT)

    local visible, open  = reaper.ImGui_Begin(ctx, 'Item Sampler ' ..version, true, window_flags)


    local gui_w , gui_h = reaper.ImGui_GetContentRegionAvail( ctx)
    gui_w = gui_w -- 15
    gui_h = gui_h - 15
    --- GUI HERE
    n_lines = 4

    if visible then
        if reaper.ImGui_BeginMenuBar(ctx) then
            if reaper.ImGui_BeginMenu(ctx, 'Trim') then

                if reaper.ImGui_MenuItem(ctx, 'Clean Area Before Paste',"",Erase) then
                    Erase = not Erase
                end
                if Tips then ToolTip("Before pasting delete Any Item\nin the space of the Pasted Items") end

                if reaper.ImGui_MenuItem(ctx, 'Trim Items Using MIDI Item End',"",Is_trim_ItemEnd) then
                    Is_trim_ItemEnd = not Is_trim_ItemEnd
                end
                if Tips then ToolTip("The pasted items will be trimmed\nat the end of the MIDI item") end

                if reaper.ImGui_MenuItem(ctx, 'Trim Items Using Start Next Midi Note',"",Is_trim_StartNextNote) then
                    Is_trim_StartNextNote = not Is_trim_StartNextNote
                end
                if Tips then ToolTip("The pasted items will be trimmed\nat the start of the next MIDI note") end

                if reaper.ImGui_MenuItem(ctx, 'Trim Items Using End MIDI Note',"",Is_trim_EndNote) then
                    Is_trim_EndNote = not Is_trim_EndNote
                end
                if Tips then ToolTip("The pasted items will be trimmed\nat the end of the MIDI note") end


                
                
                reaper.ImGui_EndMenu(ctx)
            end
            reaper.ImGui_EndMenuBar(ctx)
        end

        if reaper.ImGui_BeginMenuBar(ctx) then
            if reaper.ImGui_BeginMenu(ctx, 'Velocity') then

                if reaper.ImGui_MenuItem(ctx, 'Velocity Change Item dB',"",Velocity) then
                    Velocity = not Velocity
                end
                local _

                _, Vel_Max = reaper.ImGui_InputInt(ctx,  'Max dB added', Vel_Max)
                _, Vel_Min = reaper.ImGui_InputInt(ctx,  'Max dB reduce', Vel_Min)
                _, Vel_OriginalVal = reaper.ImGui_SliderInt(ctx, 'Velocity to use original Item dB', Vel_OriginalVal, 0, 127)
                

                reaper.ImGui_EndMenu(ctx)

            end
            reaper.ImGui_EndMenuBar(ctx)
        end
        
        if reaper.ImGui_BeginMenuBar(ctx) then
            if reaper.ImGui_BeginMenu(ctx, 'Pitch') then

                if reaper.ImGui_MenuItem(ctx, 'MIDI Pitch Note Change Item Pitch',"",Pitch) then
                    Pitch = not Pitch
                end
                local _

                _, Pitch_Original = reaper.ImGui_SliderInt(ctx, 'Original Pitch at MIDI Note', Pitch_Original, 0, 127)
                

                reaper.ImGui_EndMenu(ctx)

            end
            reaper.ImGui_EndMenuBar(ctx)
        end

        if reaper.ImGui_BeginMenuBar(ctx) then
            if reaper.ImGui_BeginMenu(ctx, 'Extra') then

                if reaper.ImGui_MenuItem(ctx, 'Show Tool Tips',"",Tips) then
                    Tips = not Tips
                end

                reaper.ImGui_EndMenu(ctx)

            end
            reaper.ImGui_EndMenuBar(ctx)
        end
        --------- Get MIDI button
        ChangeColor(0.4,1,0.4,1)
        reaper.ImGui_Button(ctx, 'Get MIDI Item', gui_w, gui_h/n_lines)
        if reaper.ImGui_IsItemClicked( ctx) then
            list_midi = ListItems()
        end
        if Tips then ToolTip("Select the MIDI items with the notes\nwhere the items will be placed") end
        reaper.ImGui_PopStyleColor(ctx, 3); reaper.ImGui_PopID(ctx)

        --------- Get Items sequence Buttons
        reaper.ImGui_Button(ctx, 'Get Item Sequence', gui_w, gui_h/n_lines)
        if reaper.ImGui_IsItemClicked( ctx) then
            list_sequence = ListItems()
        end
        if Tips then ToolTip("Select a sequence of items to be placed\non the notes of the MIDI objects") end


        --------Place Button
        ChangeColor(1,1,0.4,1)
        reaper.ImGui_Button(ctx, 'Place in Sequence', gui_w, gui_h/n_lines)
        if reaper.ImGui_IsItemClicked( ctx) then
            local is_reverse = reaper.ImGui_IsKeyDown( ctx, 17 ) -- is ctrl down? 
            Place_Sequence(false, is_reverse, false) -- (is_random,sequence_reverse,isrand_sequence)
        end
        if Tips then ToolTip("Click: Paste the items sequence in order\nCtrl+Click: Paste the sequence in reverse order") end
        reaper.ImGui_PopStyleColor(ctx, 3); reaper.ImGui_PopID(ctx)
        --------Place Random
        ChangeColor(0.15,1,0.4,1)
        reaper.ImGui_Button(ctx, 'Place Random', gui_w, gui_h/n_lines)
        if reaper.ImGui_IsItemClicked( ctx) then
            local is_rand_sequence = reaper.ImGui_IsKeyDown( ctx, 17 ) -- is ctrl down? 
            Place_Sequence(true, false, is_rand_sequence)   --isrand_sequence     
        end
        if Tips then ToolTip("Click: Paste the items sequence randomly\nCtrl+Click: Paste the sequence randomly without repetitions") end
        reaper.ImGui_PopStyleColor(ctx, 3); reaper.ImGui_PopID(ctx)

        --------
        reaper.ImGui_End(ctx)
    end        
    reaper.ImGui_PopFont(ctx)

        
    if open then
        reaper.defer(loop)
    else
        reaper.ImGui_DestroyContext(ctx)
    end
end

Erase = true
Is_trim_ItemEnd = true
Is_trim_StartNextNote = true
Is_trim_EndNote = true
Tips = true
Velocity = false
Vel_OriginalVal = 64
Vel_Min = -6
Vel_Max = 6
Pitch = true
Pitch_Original = 60
GuiInit()
loop()
