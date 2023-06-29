-- @noindex
function CreateMap()
    local defaultab = {}
    defaultab.update_on_start = 1 -- Update Items on start of script
    
    defaultab.pref_keep_cuts = 0 -- Mode to keep items modfications 
    defaultab.track_order = 0 -- Mode to use MIDI/Tracks instead of MIDI Channels
    
    defaultab.color_item = 1 -- Color Items MIDI Transfer will update 
    defaultab.color = reaper.ColorToNative(218, 109, 140)|0x1000000  --retval, color = reaper.GR_SelectColor( hwnd ) give color in reaper number
    
    defaultab.delete_outside_track = 1  -- Delete Transfer Items That do not cross with the font on the same track
    defaultab.auto_delete_odd = 0 -- Delete Odds Items On the same tracks it is using
    defaultab.auto_delete_odds_project = 1 -- Delete Odd Items in every track

    defaultab.impCC  = 1 -- Delete CC
    defaultab.impProgram  = 1 -- delete Program changes / bank
    return defaultab
end
------------------------------
------------GUI + MAP:
------------------------------

function Validate(i)
    local val = true 
    if reaper.ValidatePtr(map[i].font_item, 'MediaItem*') == false then 
        local msg = 
        [[
        Error: Could not update! 
        Your Item Source Nº]]..i..[[ Is Missing ! 
        Set Another Source Nº]]..i..[[ 
        Midi Transfer Will keep Running :)
        ]]
        reaper.ShowMessageBox(msg, 'MIDI Transfer', 0)
        val = false
        return
    end 

    
    for k, v in pairs(map[i]) do
        if type(k) == 'number' then -- k is MIDIchannel/MIDItrack
            for k2, v2 in ipairs(map[i][k]) do --k2 index and v2 is track destination
                if reaper.ValidatePtr(v2, 'MediaTrack*') == false then 
                    local msg = 
                    [[
                    Error: Could not update! 
                    One Track is Missing on Source Nº]]..i..[[ Channel ]]..k..[[ 
                    Set Another Track to it!
                    Midi Transfer Will keep Running :)
                    ]]
                    reaper.ShowMessageBox(msg, 'MIDI Transfer', 0)
                    val = false
                    return
                end 
            end
        end
    end

    if map[i].track_order == 1 and map[i].source == "" then -- If user use a MIDI File embeded into reaper project
        local msg = 
        [[
        Error: Could not update! 
        Your Item Source Nº]]..i..[[ Don't have a .mid Source File
        Use MIDI CH Instead!
        Midi Transfer Will keep Running :)
        ]]
        reaper.ShowMessageBox(msg, 'MIDI Transfer', 0)
        val = false
        return
    end 

    return val  
end

function ValidateSelFont()
    local bol = true
    local count = reaper.CountSelectedMediaItems(0)
    if count == 0 then 
        reaper.ShowMessageBox('Please Select an Item As Source', 'MIDI Transfer', 0)
        bol = false
    end 
    return bol
end 

function ValidateStart()
    local val = true
    for i = 1, #map do
        ----- Validate If there are an Source selected
        if map[i].font_item == nil then 
            local msg = 
            [[
            Error: Could not Start! 
            Assign an Source Item at Source Nº]]..i
            reaper.ShowMessageBox(msg, 'MIDI Transfer', 0)
            val = false
            return
        end  
        ----- Validate If there are Destination selected
        for ch in pairs(map[i]) do
            if type(ch) == 'number' then 
                boll = true
            end
        end

        if not boll then 
            local msg = 
            [[
            Error: Could not Start! 
            Assign some Destination Track at Source Nº]]..i
            reaper.ShowMessageBox(msg, 'MIDI Transfer', 0)
            val = false
            return
        end    
        ----- Validate If the Source still exist
        if reaper.ValidatePtr(map[i].font_item, 'MediaItem*') == false then 
            local msg = 
            [[
                Error: Could not Start! 
                Your Item Source Nº]]..i..[[ Is Missing ! 
                Set Another Source Nº]]..i..[[ 
                ]]
            reaper.ShowMessageBox(msg, 'MIDI Transfer', 0)
            val = false
            return
        end 
         ----- Validate If the Dest still exist
        for k, v in pairs(map[i]) do
            if type(k) == 'number' then -- k is MIDIchannel/MIDItrack
                for k2, v2 in ipairs(map[i][k]) do --k2 index and v2 is track destination
                    if reaper.ValidatePtr(v2, 'MediaTrack*') == false then 
                        local msg = 
                        [[
                        Error: Could not Start! 
                        One Track is Missing on Source Nº]]..i..[[ Channel ]]..k..[[ 
                        Set Another Track to it!
                        ]]
                        reaper.ShowMessageBox(msg, 'MIDI Transfer', 0)
                        val = false
                        return
                    end 
                end
            end
        end
        -- Validate if not(Item is not a Mid File and is in MIDI Track mode)
        if map[i].track_order == 1 and map[i].source == "" then -- If user use a MIDI File embeded into reaper project
            local msg = 
            [[
            Error: Could not Start!  
            Your Item Source Nº]]..i..[[ Don't have a .mid Source File
            Use MIDI CH Instead!
            Midi Transfer Will keep Running :)
            ]]
            reaper.ShowMessageBox(msg, 'MIDI Transfer', 0)
            val = false
            return
        end 
    end
    
    return val
end 

function ValidadeOnline(i) -- Check if Item is online
    if not map[i].font_PCM and reaper.ValidatePtr2(0, map[i].font_take, 'MediaItem_Take*') then --tries to recover the PCM if needed
        map[i].font_PCM = reaper.GetMediaItemTake_Source(map[i].font_take )
    end
    local bol = reaper.CF_GetMediaSourceOnline( map[i].font_PCM )
    return bol
end

function SetseltoFonts() -- return a table with font info
    local list = {}
    if ValidateSelFont() == false then return end
    for i = 0, count-1 do
        list[i+1] = {}
        list[i+1].font_item = reaper.GetSelectedMediaItem(0, i)
        list[i+1].font_take = reaper.GetMediaItemTake(list[i+1].font_item, 0)
        list[i+1].font_PCM  = reaper.GetMediaItemTake_Source( list[i+1].font_take )
        list[i+1].source = reaper.GetMediaSourceFileName( list[i+1].font_PCM, '0' )
        retval, list[i+1].font_name = reaper.GetSetMediaItemTakeInfo_String( list[i+1].font_take, 'P_NAME', '', false )
        ------------ Renames Font 
        local init,_,_ = string.find( list[i+1].font_name,"!Font " )
        list[i+1].font_IGUID = reaper.BR_GetMediaItemGUID( list[i+1].font_item )
        if init then -- For renaming the Font Items to the order                                                                                  
            retval, list[i+1].font_name = reaper.GetSetMediaItemTakeInfo_String( list[i+1].font_take, 'P_NAME', string.gsub( list[i+1].font_name,'!IGUID %b{}', '!IGUID '..list[i+1].font_IGUID ), true )
        else 
            retval, list[i+1].font_name = reaper.GetSetMediaItemTakeInfo_String( list[i+1].font_take, 'P_NAME', '!Font '..list[i+1].font_name..' '..'!IGUID '..list[i+1].font_IGUID, true )
        end
        
        local retval, ignoreProjTempo, bpm, num, den = reaper.BR_GetMidiTakeTempoInfo( list[i+1].font_take )
        list[i+1].IG_TEMPO = {ignoreProjTempo = ignoreProjTempo, bpm=bpm, num = num, den = den}
    end  
    return list
end

function SetFonts(list) -- Set all fonts info. please insert map list
    if ValidateSelFont() == false then return false end

    list.font_item = reaper.GetSelectedMediaItem(0, 0)
    list.font_take = reaper.GetMediaItemTake(list.font_item, 0)
    list.font_PCM = reaper.GetMediaItemTake_Source( list.font_take )
    list.source = reaper.GetMediaSourceFileName( list.font_PCM, '0' )
    retval, list.font_name = reaper.GetSetMediaItemTakeInfo_String( list.font_take, 'P_NAME', '', false )
    ------------ Renames Font 
    local init,_,_ = string.find( list.font_name,"!Font " )
    list.font_IGUID = reaper.BR_GetMediaItemGUID( list.font_item )
    if init then -- For renaming the Font Items to the order                                                                                  
        retval, list.font_name = reaper.GetSetMediaItemTakeInfo_String( list.font_take, 'P_NAME', string.gsub( list.font_name,'!IGUID %b{}', '!IGUID '..list.font_IGUID ), true )
    else 
        retval, list.font_name = reaper.GetSetMediaItemTakeInfo_String( list.font_take, 'P_NAME', '!Font '..list.font_name..' '..'!IGUID '..list.font_IGUID, true )
    end

    local retval, ignoreProjTempo, bpm, num, den = reaper.BR_GetMidiTakeTempoInfo( list.font_take )
    list.IG_TEMPO = {ignoreProjTempo = ignoreProjTempo, bpm=bpm, num = num, den = den} 
    SaveMT() --Saves Midi transfer into project 
    return list
end

function SetSelDestination(list,font, ch) -- Add selected tracks to Destination to the list
    list[font][ch] = {}
    for i = 0, (reaper.CountSelectedTracks(0)-1) do
        local tr = reaper.GetSelectedTrack(0, i)
        list[font][ch][i+1] = tr
    end
    return list
end

function SetMapInfo(i, info, btn_name) -- For Updating map[i]
    local val = GUI.Val(btn_name)
    if info == 'track_order' then
        if val == 1 then val = 0 elseif val ==3 then val = 1 end
    else
        val = bool_to_number(val)
    end
    map[i][info] = val 
end

function SetMapTracks(y, t_tracks)
    ClearMapLines(y)
    for line in pairs(t_tracks) do
        map[y][line-1] = {}
        for k, track in pairs(t_tracks[line]) do
            if t_tracks[line][1] ~= '' then 
                map[y][line-1][k] = track
            else
                map[y][line-1] = nil
            end
        end
    end
    map[y].negative = NegativeList2(map[y])

    SaveMT()
end

function ClearMapLines(y)
    for k , v in pairs(map[y]) do
        if type(k) == 'number' then 
            map[y][k] = nil
        end
    end
    map[y].negative = nil
end

function UpdateDisplay(i)
    if map[i].font_name then 
        local diplay_name = string.gsub( map[i].font_name,'!Font','')
        local diplay_name = string.gsub( diplay_name ,'!IGUID %b{}','')
        GUI.Val('font_display', diplay_name)
    else
        GUI.Val('font_display', '')
    end
end

function UpdateTxtEditor(i)
    t_tracks = {}
    local big_k = GetHighKey(map[i])
    for line = 1 , big_k+1 do
        t_tracks[line] ={}
        if map[i][line-1] then
            for k, track in pairs(map[i][line-1]) do
                t_tracks[line][k] = track 
            end
        else 
            t_tracks[line][1] = ''
        end
    end
end

function UpdateConfig(i,info, btn_name) --For Updating GUI based on map[i]
    local val = map[i][info]
    if info == 'track_order' then -- The Radio needs 1 or 3 
        if val == 0 then val = 1 elseif val == 1 then val = 3 end
    else
        val = num_to_bool(val)
    end 
    GUI.Val(btn_name, val)
end

function UpdateMenuConfig(y)
    local options = {'delete_outside_track' ,'auto_delete_odd' , 'auto_delete_odds_project' , 'impCC', 'impProgram'}
    local menu_num = {2                     ,4                 ,5                           , 6      , 7 }
    for i = 1, #options do
        local val = map[y][options[i]]
        if val == 1 then 
            GUI.elms.Bar.menus[1].options[menu_num[i]][1] = '!'..gui_opts_menu[i]
        else
            GUI.elms.Bar.menus[1].options[menu_num[i]][1] = gui_opts_menu[i]
        end
    end
end

function SelectFontItem(i)
    if map[i].font_item then
            reaper.Undo_BeginBlock2(0)
            reaper.Main_OnCommand(40289, 0)--Item: Unselect all items
            reaper.SetMediaItemSelected(map[i].font_item, true)
            reaper.UpdateArrange()
            reaper.Undo_EndBlock2(0, 'MIDI Transfer: Change Item Selection', -1)
    end
end

function SelectAllFontItems(justlist)
    local item_list = {}
    for i = 1, #map do
        table.insert(item_list, map[i].font_item) 
    end
    if justlist == true then
        return item_list
    else
        reaper.Undo_BeginBlock2(0)
        LoadSelectedItems(item_list)
        reaper.UpdateArrange()
        reaper.Undo_EndBlock2(0, 'MIDI Transfer: Change Item Selection', -1)
    end
end

function SelectTRItems(i, justlist) -- justlist so I can use the same function to all maps in SelectAllTRItems()
    local item_list = {}
    if map[i].font_name then 
        if map[i].negative then
            local name = map[i].font_name
            for track , tb_ch in pairs(map[i].negative) do
                local num_items = reaper.CountTrackMediaItems( track )
                if num_items ~= 0 then 
                    for i_l =  0, num_items-1  do 
                        local item_loop = reaper.GetTrackMediaItem( track, i_l )
                        local item_loop_take = reaper.GetMediaItemTake( item_loop, 0 )
                        local _, item_loop_name = reaper.GetSetMediaItemTakeInfo_String( item_loop_take, 'P_NAME', "", false )
                        if Match(item_loop_name,"!MTr CH %d+ %- "..SubMagicChar(name)) == true then 
                            local ch_loop = string.match(item_loop_name, '%d+')
                            if IsChannelOnTrack(map[i].negative, track, tonumber(ch_loop)) == true then
                                table.insert( item_list, item_loop )
                            end
                        end
                    end
                end 
            end
            
            if justlist == true then
                return item_list 
            else
                reaper.Undo_BeginBlock2(0)
                LoadSelectedItems(item_list)
                reaper.UpdateArrange()
                reaper.Undo_EndBlock2(0, 'MIDI Transfer: Change Item Selection', -1)
            end
        end
    end
end

function SelectFontandTR(i)
    local list_items = SelectTRItems(i, true) 

    if list_items then 
        table.insert( list_items, map[i].font_item ) 

        reaper.Undo_BeginBlock2(0)
        LoadSelectedItems(list_items)
        reaper.UpdateArrange()
        reaper.Undo_EndBlock2(0, 'MIDI Transfer: Change Item Selection', -1)
    end
end

function SelectAllTRItems(justlist)
    local lista_item = {}
    for i = 1, #map do
        local list = SelectTRItems(i, true)
        if list then 
            TableConcat(lista_item,list)
        end
    end
    if justlist == true then 
        return lista_item
    else
        if #lista_item >= 1 then 
            reaper.Undo_BeginBlock2(0)
            LoadSelectedItems(lista_item)
            reaper.UpdateArrange()
            reaper.Undo_EndBlock2(0, 'MIDI Transfer: Change Item Selection', -1)
        end
    end
end

function SelectAll()
    local items_list = SelectAllTRItems(true)
    local font_list = SelectAllFontItems(true)
    if items_list and font_list then
        TableConcat(items_list,font_list)
    end

    if #items_list >= 1 then
        reaper.Undo_BeginBlock2(0)
        LoadSelectedItems(items_list)
        reaper.UpdateArrange()
        reaper.Undo_EndBlock2(0, 'MIDI Transfer: Change Item Selection', -1)
    end
end

function RemoveMap(i)
    table.remove( map, i )
end

function FindMTRItems()-- return a list with all item : list[map i] = {items} ( a list in a list ) (Important: It only gives Items that match one of the maps source name)
    local item_list = {}
    for i = 1, #map do 
        item_list[i] = {}
        if map[i].font_name then 
            local name = map[i].font_name
            local tracks_num = reaper.CountTracks(0)   
            for t_n = 0, tracks_num-1 do
                local track = reaper.GetTrack(0, t_n)
                local num_items = reaper.CountTrackMediaItems( track )
                if num_items ~= 0 then 
                    for i_l =  0, num_items-1  do 
                        local item_loop = reaper.GetTrackMediaItem( track, i_l )
                        local item_loop_take = reaper.GetMediaItemTake( item_loop, 0 )
                        local _, item_loop_name = reaper.GetSetMediaItemTakeInfo_String( item_loop_take, 'P_NAME', "", false )
                        if Match(item_loop_name,"!MTr CH %d+ %- "..SubMagicChar(name)) == true then 
                            --local ch_loop = string.match(item_loop_name, '%d+')
                            --if IsChannelOnTrack(map[i].negative, track, tonumber(ch_loop)) == true then
                            table.insert( item_list[i], item_loop )
                            --end
                        end
                    end
                end 
            end
        end 
    end
    return item_list
end

function FindAnyMTRItems()-- return a list with all item (Important: It will cover any item that start with !MTR and ends with IGUID{})
    local item_list = {}
    local tracks_num = reaper.CountTracks(0) 
    if tracks_num ~= 0 then
        for t_n = 0, tracks_num-1 do
            local track = reaper.GetTrack(0, t_n)
            local num_items = reaper.CountTrackMediaItems( track )
            if num_items ~= 0 then 
                for i_l =  0, num_items-1  do 
                    local item_loop = reaper.GetTrackMediaItem( track, i_l )
                    local item_loop_take = reaper.GetMediaItemTake( item_loop, 0 )
                    local _, item_loop_name = reaper.GetSetMediaItemTakeInfo_String( item_loop_take, 'P_NAME', "", false )
                    if string.find(item_loop_name,'^!MTr.+IGUID %b{}$') then 
                        table.insert( item_list, item_loop )
                    end
                end
            end 
        end
    end
    return item_list
end

function DelItems(i) -- Selected Map
    local item_list = FindMTRItems()
    if #item_list[i] > 0 then
        reaper.Undo_BeginBlock2(0)
        DeleteItemsList(item_list[i])
        reaper.UpdateArrange()
        reaper.Undo_EndBlock2(0, 'MIDI Transfer: Delete Items', -1)
    end
end

function DelAllItems() -- All Maps
    local item_list = FindMTRItems()
    if #item_list > 0 then 
        reaper.Undo_BeginBlock2(0)
        for i = 1, #item_list do
            if #item_list[i] > 0 then
                DeleteItemsList(item_list[i])
            end
        end
        reaper.UpdateArrange()
        reaper.Undo_EndBlock2(0, 'MIDI Transfer: Delete All Items', -1)
    end
end

function DelAnyItems(i)  -- Any item starting with !MTR and ending with IGUID %b{}
    local item_list = FindAnyMTRItems()
    if #item_list > 0 then
        reaper.Undo_BeginBlock2(0)
        DeleteItemsList(item_list)
        reaper.UpdateArrange()
        reaper.Undo_EndBlock2(0, 'MIDI Transfer: Delete Items', -1)
    end
end

function DeleteOddAllTracksManual(i) -- Deletes All odds In All Tracks for this Source Item
    reaper.Undo_BeginBlock2(0)
    DeleteOddAllTracks(i)-- Shift 
    reaper.UpdateArrange()
    reaper.Undo_EndBlock2(0, 'MIDI Transfer: Delete Odd Items All Tracks for Select Source', -1)
end

function DeleteOddAllTracksAllManual() -- Deletes All odds In All Tracks for all sources
    reaper.Undo_BeginBlock2(0)
    for i = 1, #map do
        DeleteOddAllTracks(i)-- Shift 
    end
    reaper.UpdateArrange()
    reaper.Undo_EndBlock2(0, 'MIDI Transfer: Delete Odd Items All Tracks for All Source', -1)
end

function SaveMapToMap(save)
    map = {}
    for i , _ in pairs(save) do 
        map[i] = {}
        for ch, val in pairs(save[i]) do
            if type(ch) == 'number' then 
                map[i][ch] = {}
                for k, tr in pairs(save[i][ch]) do
                    track = reaper.BR_GetMediaTrackByGUID( 0, tr )
                    table.insert( map[i][ch], track )
                end
            else
                if     ch == 'negative' then
                    map[i][ch] = {}
                    for tr, chanal_list in pairs(save[i].negative) do
                        track = reaper.BR_GetMediaTrackByGUID( 0, tr )
                        if track then
                            map[i][ch][track] = {}
                            map[i][ch][track] = chanal_list
                        end
                    end
                elseif ch == 'font_item' then
                    item = reaper.BR_GetMediaItemByGUID( 0, save[i].font_item )
                    map[i][ch] = item
                elseif ch == 'font_take' then
                    take = reaper.GetMediaItemTakeByGUID( 0, save[i].font_take  )
                    map[i][ch] = take
                else
                    map[i][ch] = val
                end
            end
        end
    end
    return map
end

function MapToSaveMap(map) 
    local save = {}
    for i , _ in pairs(map) do
        save[i] = {}
        for ch, val in pairs(map[i]) do
            if type(ch) == 'number' then 
                save[i][ch] = {}
                for k, tr in pairs(map[i][ch]) do
                    local guid = reaper.GetTrackGUID( tr )
                    table.insert( save[i][ch], guid )
                end
            else
                if     ch == 'negative' then
                    save[i][ch] = {}
                    for tr, chanal_list in pairs(map[i].negative) do
                        local guid = reaper.GetTrackGUID( tr )
                        save[i][ch][guid] = {}
                        save[i][ch][guid] = chanal_list
                    end
                elseif ch == 'font_item' then
                    local guid = reaper.BR_GetMediaItemGUID(map[i].font_item)
                    save[i][ch] = guid
                elseif ch == 'font_take' then
                    local guid = reaper.BR_GetMediaItemTakeGUID( map[i].font_take )
                    save[i][ch] = guid
                else
                    save[i][ch] = val
                end
            end
        end
    end
    return save
end

function SaveMT() --Saves MIDI Transfer into the project
    local save = MapToSaveMap(map)
    local save = table.save(save)
    reaper.SetProjExtState( 0, 'MTr', 'Map', save)
    reaper.SetProjExtState( 0, 'MTr', 'Page', GUI.Val('Font_box'))
end
