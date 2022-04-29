-- @noindex
------------------------------
------------Functions:
------------------------------

function CheckCross(item_start,item_end,y)
    if (item_start < map[y].start and item_end <= map[y].start) or (item_start >= map[y].fim) then 
        check_if_old_cross = false 
    else
        check_if_old_cross = true
    end
    return check_if_old_cross
end

function DeleteOld(track, name, ch, y)
    local num_list = 0
    local list = {}
    local num_items = reaper.CountTrackMediaItems( track )
    if num_items ~= 0 then 
        for i =  num_items-1, 0, -1  do 
            local item_loop = reaper.GetTrackMediaItem( track, i )
            local item_loop_take = reaper.GetMediaItemTake( item_loop, 0 )
            local _, item_loop_name = reaper.GetSetMediaItemTakeInfo_String( item_loop_take, 'P_NAME', "", false )
            if Match(item_loop_name,"!MTr CH %d+ %- "..SubMagicChar(name)) == true then 
                if Match(item_loop_name,"!MTr CH "..ch.." %- "..SubMagicChar(name)) == true then -- Use this string for deleting all Match items: "!MEx CH %d+ %- "..SubMagicChar(name)
                    -----------Create a list That will be called latter restore the Items atributes Like mute vol Fade Lock
                    local item_start = reaper.GetMediaItemInfo_Value(item_loop, "D_POSITION")
                    local item_len = reaper.GetMediaItemInfo_Value(item_loop, "D_LENGTH")
                    local item_fim = item_start + item_len
                    cross = CheckCross(item_start, item_fim, y) -- Checks if Item cross with font
                    if  cross == true then 
                        num_list = num_list + 1
                        list[num_list] = {}
                        -----------Put in that list all you want
                        list[num_list].B_MUTE_ACTUAL = reaper.GetMediaItemInfo_Value(item_loop, "B_MUTE_ACTUAL")
                        list[num_list].C_LOCK = reaper.GetMediaItemInfo_Value(item_loop, "C_LOCK")
                        list[num_list].B_LOOPSRC  = reaper.GetMediaItemInfo_Value(item_loop, "B_LOOPSRC") -- Loop
                        list[num_list].D_VOL    = reaper.GetMediaItemInfo_Value(item_loop, "D_VOL") 
                        list[num_list].D_FADEINLEN   = reaper.GetMediaItemInfo_Value(item_loop, "D_FADEINLEN") 
                        list[num_list].D_FADEINDIR   = reaper.GetMediaItemInfo_Value(item_loop, "D_FADEINDIR") 
                        list[num_list].C_FADEINSHAPE = reaper.GetMediaItemInfo_Value(item_loop, "C_FADEINSHAPE") 
                        list[num_list].D_FADEOUTLEN   = reaper.GetMediaItemInfo_Value(item_loop, "D_FADEOUTLEN") 
                        list[num_list].D_FADEOUTDIR   = reaper.GetMediaItemInfo_Value(item_loop, "D_FADEOUTDIR") 
                        list[num_list].B_UISEL  = reaper.GetMediaItemInfo_Value(item_loop, "B_UISEL") 
                        list[num_list].I_GROUPID  = reaper.GetMediaItemInfo_Value(item_loop, "I_GROUPID") 
                        list[num_list].I_LASTY  = reaper.GetMediaItemInfo_Value(item_loop, "I_LASTY") 
                        list[num_list].I_LASTH  = reaper.GetMediaItemInfo_Value(item_loop, "I_LASTH") 
                        list[num_list].F_FREEMODE_Y  = reaper.GetMediaItemInfo_Value(item_loop, "F_FREEMODE_Y") 
                        list[num_list].F_FREEMODE_H  = reaper.GetMediaItemInfo_Value(item_loop, "F_FREEMODE_H") 
                        list[num_list].IS_POOLID, list[num_list].POOLID = reaper.BR_GetMidiTakePoolGUID( item_loop_take )
                        if map[y].pref_keep_cuts == 1 then 
                            list[num_list][0] = item_start
                            list[num_list][1] = item_len
                            list[num_list][2] = item_fim
                        end
                    end
                    if cross == false and map[y].delete_outside_track == 0 then
                    else
                        reaper.DeleteTrackMediaItem(track, item_loop)
                    end
                else
                    if map[y].auto_delete_odd == 1 then
                        local ch_loop = string.match(item_loop_name, '%d+')
                        if IsChannelOnTrack(map[y].negative, track, tonumber(ch_loop)) == false then
                            reaper.DeleteTrackMediaItem(track, item_loop) -- Delete this odd
                        else
                            -- Do nothing This Item Is From the same Font, but 1) Should be there
                        end
                    else
                        -- Do nothing This Item Is From the same Font, but auto delete odds is off
                    end
                end
            end
        end
    end
    return list
end

function CopyMIDI(item, track)-- Copy an Item to Track
        local retval, chunk = reaper.GetItemStateChunk( item, "", false )
        --local chunk = ResetAllIndentifiers(chunk)
        local chunk = bfut_ResetAllChunkGuids(chunk, "IGUID")
        local chunk = bfut_ResetAllChunkGuids(chunk, "GUID")
        --local chunk = bfut_ResetAllChunkGuids(chunk, "POOLEDEVTS")
        local new_item = reaper.CreateNewMIDIItemInProj( track, 3, 0.1 )
        reaper.SetItemStateChunk( new_item, chunk, false )
            
        local items_list = SaveSelectedItems()
    
        reaper.SetMediaItemSelected( new_item, true )
        reaper.Main_OnCommand(40684, 0) -- Convert active take MIDI to in-project MIDI source data
        reaper.Main_OnCommand(41613, 0) -- Item: Remove active take from MIDI source data pool (AKA un-pool, un-ghost, make unique) 
        LoadSelectedItems(items_list) 
    return new_item
end

function CopyMediaItem(y, track, ch, first_new , last_new, n_tracks_imported ) -- Copy Item to track and leave only channel ch/MIDI track. Also reset GUID. IGUID to copies
    local rename = "!MTr CH "..ch..' - '..map[y].font_name   
    
    local old_list = DeleteOld(track, map[y].font_name, ch, y) -- Create A list of the '!MTr CH %d+ -' Items with their proprieties, positions and if cross with font. And delete them.
    local new_item = {}

    if map[y].track_order == 0 or (map[y].track_order == 1 and ch == 0) then 
        local items_list = SaveSelectedItems()--- Save Selected Item to load latter, as the CopyMIDI() will change selection
        new_item[1] = CopyMIDI(map[y].font_item, track)
        new_take = reaper.GetMediaItemTake( new_item[1], 0 )
        SoloChannel(new_take, ch) 
        reaper.GetSetMediaItemTakeInfo_String(new_take, "P_NAME", rename, true)
        LoadSelectedItems(items_list)
    elseif map[y].track_order == 1 and ch ~= 0 then
        local imp_track_n = first_new + ch - 1
        local imp_tracks = reaper.GetTrack(0, imp_track_n-1)
        local imp_item = reaper.GetTrackMediaItem( imp_tracks, 0 )
        new_item[1] = CopyMIDI(imp_item, track)
        new_take = reaper.GetMediaItemTake( new_item[1], 0 )
        SetFromMap(new_item[1],new_take, y) 
        reaper.GetSetMediaItemTakeInfo_String(new_take, "P_NAME", rename, true)
    end

    --Delete CC/Texts/PC options 
    if map[y].impCC == 0 then DeleteCC(new_take) end
    if map[y].impProgram == 0 then DeleteProgramChange(new_take) end

    ---Reset Track Propieties ( and cut if keepcuts == 1)
    if map[y].color_item == 1 then 
        reaper.SetMediaItemInfo_Value(new_item[1], 'I_CUSTOMCOLOR', map[y].color)
    end

    if map[y].pref_keep_cuts == 0 then  -- As splitting an MIDI Item with it turned on might bug (?) https://forum.cockos.com/showthread.php?t=247402
        reaper.BR_SetMidiTakeTempoInfo( new_take , map[y].IG_TEMPO.ignoreProjTempo, map[y].IG_TEMPO.bpm, map[y].IG_TEMPO.num, map[y].IG_TEMPO.den )
    end

    if #old_list > 0 then--Restore some configs from the old Items
        if map[y].pref_keep_cuts == 1 then      -- Delete parts of the new item using old items 
            if old_list[#old_list][0] > map[y].start then  -- trim first item if need
                TrimStartMIDI(new_item[1], 0, old_list[#old_list][0], true)
            end
            local counter_old = #old_list
            for i = #old_list-1, 1, -1  do -- split item and trim right 
                new_item[#new_item+1] = reaper.SplitMediaItem(new_item[#new_item], old_list[i+1][2]) 
                TrimStartMIDI(new_item[#new_item], 0, old_list[i][0], true)
            end
            if old_list[1][2] < map[y].fim then-- split and delete right item if need
                TrimEndMIDI(new_item[#new_item], 0, old_list[1][2], true) 
            end
        end
        if map[y].pref_keep_cuts == 0 then
            for k, v in pairs(old_list[#old_list]) do
                if type(k) == 'string' then
                    if  k == 'POOLID' and old_list[#old_list].IS_POOLID == true then 
                        local  _, str = reaper.GetItemStateChunk( new_item[1], '', false )
                        local str = string.gsub( str,'POOLEDEVTS %b{}','POOLEDEVTS '..v, 1 )
                        reaper.SetItemStateChunk(new_item[1], str, false)
                    elseif k ~= 'IS_POOLID' and k ~= 'POOLID' then
                        reaper.SetMediaItemInfo_Value(new_item[1], k, v) 
                    end   
                end
            end 
        else
            for i = #old_list, 1, -1 do
                for k, v in pairs(old_list[i]) do
                    if type(k) == 'string' then
                        if  k == 'POOLID' and old_list[i].IS_POOLID == true then 
                            local  _, str = reaper.GetItemStateChunk( new_item[(i*(-1))+(#old_list+1)], '', false )
                            local str = string.gsub( str,'POOLEDEVTS %b{}','POOLEDEVTS '..v, 1 )
                            reaper.SetItemStateChunk(new_item[(i*(-1))+(#old_list+1)], str, false)
                        elseif k ~= 'IS_POOLID' and k ~= 'POOLID' then
                            reaper.SetMediaItemInfo_Value(new_item[(i*(-1))+(#old_list+1)], k, v) -- I needed to put this on the table index to reverse the order of it, basically making it negative then it rises each for loop and then add it to goes from 1 to #old_list
                        end   
                    end
                end
            end  
        end
    end
end

function SoloChannel(take, ch) 
    if ch ~= 0 then -- ch 0 is omni
        local retval, MIDIstring = reaper.MIDI_GetAllEvts(take, "") 
        local MIDIlen = MIDIstring:len()
        local tableEvents = {}
        local stringPos = 1
        --local pos=0 
        while stringPos < MIDIlen do 
            offset, flags, ms, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos) -- Unpack the MIDI[stringPos] event 
            --pos=pos+offset -- For keeping track of the Postion of the notes in Ticks
            if ms:len() == 3 then -- if ms:len == 3 means it have 3 messages(Notes, CC,Poly Aftertouch, Pitchbend )  (ms:byte(1)>>4 == 9 or ms:byte(1)>>4 == 8) note on or off
                local channel = ms:byte(1)&0x0F -- 0x0F = 0000 1111 in binary . ms is decimal. & is an and bitwise operation "have to have 1 in both to be 1". Will return channel as a decimal number
                if channel ~= ch-1 then ms="" end 
            end 
            table.insert(tableEvents, string.pack("i4Bs4", offset, flags, ms))
        end 
        reaper.MIDI_SetAllEvts(take, table.concat(tableEvents)) 
    end
end 

function DeleteCC(take) 
    local retval, MIDIstring = reaper.MIDI_GetAllEvts(take, "") 
    local MIDIlen = MIDIstring:len()
    local tableEvents = {}
    local stringPos = 1
    --local pos=0 
    while stringPos < MIDIlen do 
        offset, flags, ms, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos) -- Unpack the MIDI[stringPos] event 
        --pos=pos+offset -- For keeping track of the Postion of the notes in Ticks
        if ms:len() == 3 and ms:byte(1)>>4 == 11 and ms:byte(2) <= 120 then -- if ms:len == 3 means it have 3 messages(Notes, CC,Poly Aftertouch, Pitchbend ) ms:byte(1)>>4 == 11 see if the 4 first digits are 1011 (CC)
            ms=""
        end 
        table.insert(tableEvents, string.pack("i4Bs4", offset, flags, ms))
    end 
    reaper.MIDI_SetAllEvts(take, table.concat(tableEvents)) 
end 

function DeleteProgramChange(take) 
    local retval, MIDIstring = reaper.MIDI_GetAllEvts(take, "") 
    local MIDIlen = MIDIstring:len()
    local tableEvents = {}
    local stringPos = 1
    --local pos=0 
    while stringPos < MIDIlen do 
        offset, flags, ms, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos) -- Unpack the MIDI[stringPos] event 
        --pos=pos+offset -- For keeping track of the Postion of the notes in Ticks
        if ms:len() == 2 and ms:byte(1)>>4 == 12 then -- if ms:len == 3 means it have 3 messages(Notes, CC,Poly Aftertouch, Pitchbend ) ms:byte(1)>>4 == 11 see if the 4 first digits are 1011 (CC)
            ms=""
        end 
        table.insert(tableEvents, string.pack("i4Bs4", offset, flags, ms))
    end 
    reaper.MIDI_SetAllEvts(take, table.concat(tableEvents)) 
end 

function ImportMIDI(path, start)
    --------------Get Info That Will be changed
    local items_fold = SaveSelectedItems()
    local tracks_fold = SaveSelectedTracks()
    local last_cursor =  reaper.GetCursorPosition()
    local last = reaper.GetLastTouchedTrack() 
    if not last then 
        last_num = reaper.CountTracks(0)
    else 
        last_num = reaper.GetMediaTrackInfo_Value(last, 'IP_TRACKNUMBER') 
        if last_num == -1 then last_num = reaper.CountTracks(0) end
    end
    --------------Import and Get Info
    reaper.SetEditCurPos( start, false, false )

    reaper.InsertMedia(path, 1) -- Insert Item to copy
    
    local new_last = reaper.GetLastTouchedTrack() 
    local new_last_num = reaper.GetMediaTrackInfo_Value(new_last, 'IP_TRACKNUMBER') 
    local n_tracks_imported = new_last_num - last_num 
    
    --------------Reset Info
    -----Set Last touched
    if last then reaper.SetOnlyTrackSelected(last) end
    reaper.Main_OnCommand(40914, 0)-- Track: Set first selected track as last touched track 40914
    -----
    reaper.SetEditCurPos( last_cursor, false, false )
    LoadSelectedItems(items_fold)
    LoadSelectedTracks(tracks_fold)
    return last_num+1, new_last_num, n_tracks_imported -- First Track with the new Midi Items, Last Track with the new MIDI Items, N of tracks
end

function main_tr()
    for i = 1, #map do 
        if map[i].track_order == 0 or map[i].track_order == 1 and ValidadeOnline(i) then -- If in MIDI Ch mode just go without waiting get online to track order check it first.
            local _, _, _, lastmod, _, _, _, _, _, _, _, _ = reaper.JS_File_Stat(map[i].source)
            if lastmod ~= map[i].old or manual_up == true then -- just execute if the file was mod
                if map[i].update_on_start == 1 or map[i].old  then  -- If update on start is on It doesn't matter if there is old or not If it is off It just matter if map[i].old is not nil
                    if Validate(i) == true then  -- Validates if it is ok to run (Must still have fonts, and tracks set)
                        reaper.Undo_BeginBlock2(0)
                        reaper.PreventUIRefresh(1)
                        GetMapTime(i)
                        if map[i].track_order == 1 then -- Set to MIDI Tracks
                            first_new, last_new, n_tracks_imported = ImportMIDI(map[i].source, map[i].start)
                        end
                        for k, v in pairs(map[i]) do-- Do for all Channels/MIDI Tracks set in map
                            if type(k) == 'number' then -- If k == number this means is refering to a channel 
                                for map_tr = 1, #map[i][k] do -- Do for all Reaper Tracks inside the table of channel. map_tr == The n order of tracks set in the table 
                                    CopyMediaItem(i, map[i][k][map_tr], k, first_new , last_new, n_tracks_imported )
                                end
                            end
                        end
                        if map[i].track_order == 1 then -- Delete the tracks added Importing
                            for i = last_new, first_new, - 1 do
                                local imp_track = reaper.GetTrack(0, i-1)
                                reaper.DeleteTrack( imp_track )
                            end
                        end
                        if map[i].auto_delete_odds_project == 1 then 
                            DeleteOddAllTracks(i)
                        else
                            -- Do nothing This Item Is From the same Font, but auto delete odds is off
                        end
                        reaper.PreventUIRefresh(-1)
                        reaper.Undo_EndBlock2(0, "MIDI Transfer: Update", -1)
                        reaper.UpdateArrange()
                    end
                end
            end
            map[i].old = lastmod
        end
    end
    if manual_up == true then manual_up = false end -- To execute just one time the manual update

    if defer == true then
        reaper.defer(main_tr) 
    else
        for i = 1, #map do -- Reset old when user stop the script (Need for the option 'Update on Start')
            map[i].old = nil
        end
    end
end

function DeleteOddAllTracks(y)
    local n_tracks = reaper.CountTracks(0)
    if n_tracks  ~= 0 then 
        for i = 0, n_tracks-1 do
            local track_loop = reaper.GetTrack(0, i)
            local num_items = reaper.CountTrackMediaItems( track_loop )
            if num_items ~= 0 then 
                for i =  num_items-1, 0, -1  do 
                    local item_loop = reaper.GetTrackMediaItem( track_loop, i )
                    local item_loop_take = reaper.GetMediaItemTake( item_loop, 0 )
                    local _, item_loop_name = reaper.GetSetMediaItemTakeInfo_String( item_loop_take, 'P_NAME', "", false )
                    if Match(item_loop_name,"!MTr CH %d+ %- "..SubMagicChar(map[y].font_name)) == true then 
                        local ch_loop = string.match(item_loop_name, '%d+')
                        if IsChannelOnTrack(map[y].negative, track_loop, tonumber(ch_loop)) == false then
                            reaper.DeleteTrackMediaItem(track_loop, item_loop) -- Delete this odd
                        else
                            -- Do nothing This Item Is From the same Font, but 1) Should be there
                        end
                    end 
                end
            end           
        end
    end
end

function GetMapTime(i)
    map[i].start = reaper.GetMediaItemInfo_Value(map[i].font_item, "D_POSITION")
    map[i].len =  reaper.GetMediaItemInfo_Value(map[i].font_item, "D_LENGTH")
    map[i].fim = map[i].start + map[i].len 
    map[i].off =  reaper.GetMediaItemTakeInfo_Value(map[i].font_take, "D_STARTOFFS")
    map[i].rates =  reaper.GetMediaItemTakeInfo_Value(map[i].font_take, "D_PLAYRATE")
end

function SetFromMap(item, takes, y) -- Set To the Copies the same parameters as the master 
    local list = SaveSelectedItems()
    reaper.SetMediaItemInfo_Value(item, 'D_POSITION', map[y].start )
    reaper.MIDI_SetItemExtents( item,  reaper.TimeMap2_timeToQN( 0,map[y].start ),  reaper.TimeMap2_timeToQN( 0,map[y].fim ) )
    reaper.SetMediaItemTakeInfo_Value(takes, "D_PLAYRATE", map[y].rates )
    reaper.SetMediaItemTakeInfo_Value(takes, "D_STARTOFFS", map[y].off)
    LoadSelectedItems(list)
end


--reaper.atexit(function() Msg("You Ended the Code. Congrats!") end)
