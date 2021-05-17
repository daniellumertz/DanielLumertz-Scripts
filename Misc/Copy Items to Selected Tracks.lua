-- @version 1.0
-- @author Daniel Lumertz
-- @changelog
--    + Initial Release

function print(...)
    for k,v in ipairs({...}) do
        reaper.ShowConsoleMsg(tostring(v))
    end
    reaper.ShowConsoleMsg("\n")
end

function bfut_ResetAllChunkGuids(item_chunk, key) -- (I changed a little but it is from here: https://github.com/bfut/ReaScripts/blob/main/Items%20Editing/bfut_Replace%20item%20under%20mouse%20cursor%20with%20selected%20item.lua
    item_chunk = item_chunk:gsub('%s('..key..')%s+.-[\r]-[%\n]', "\ntemp%1 "..reaper.genGuid("").."\n", 1)
    return item_chunk:gsub('temp'..key, key), true
end

function ChangeChunkPosition(item_chunk, newpos)
    local new_chunk = item_chunk:gsub("POSITION [%d%.]+","POSITION "..tostring(newpos))
    return new_chunk
end

function LoadSelectedItems(list) -- Not used it is here in case you need
    reaper.Main_OnCommand(40289, 0)--Item: Unselect all items
    if #list ~= 0 then 
        for i = 1, #list do 
            local bol = reaper.ValidatePtr( list[i] ,"MediaItem*" )
            if bol then
                reaper.SetMediaItemSelected( list[i], true )
            end
        end 
    end
end

function SaveSelectedItems() -- Not used it is here in case you need
    local list = {}
    local num = reaper.CountSelectedMediaItems(0)
    if num ~= 0 then
        for i= 0, num-1 do
            list[i+1] =  reaper.GetSelectedMediaItem( 0, i )
        end
    end
    --reaper.Main_OnCommand(40289, 0)--Item: Unselect all items
    return list
end

function CopyTakeInfo(take_copy, take_paste) -- Copy every info you can with  reaper.SetMediaItemTakeInfo_Value()
    local names = [[
    D_STARTOFFS
    D_VOL
    D_PAN
    D_PANLAW
    D_PLAYRATE
    D_PITCH
    B_PPITCH
    I_CHANMODE
    I_PITCHMODE
    I_CUSTOMCOLOR
    IP_TAKENUMBER
    ]] -- You can add or remove items from this list to be copied or not. Here is all of them
    local info = {}
    for info in string.gmatch(names,"%S+") do
        local val = reaper.GetMediaItemTakeInfo_Value(take_copy, info)
        reaper.SetMediaItemTakeInfo_Value(take_paste, info, val)
    end
end

function CopyMediaNotMIDI(item, track, position) -- Fork From Xraym https://github.com/ReaTeam/ReaScripts-Templates/blob/master/Items%20Creations/X-Raym_Copy%20media%20item.lua
	local new_item = reaper.AddMediaItemToTrack(track)
	local new_item_guid = reaper.BR_GetMediaItemGUID(new_item)
	local retval, item_chunk =  reaper.GetItemStateChunk(item, '')
    local new_item_chunk = bfut_ResetAllChunkGuids(item_chunk, "IGUID")
    local new_item_chunk = bfut_ResetAllChunkGuids(new_item_chunk, "GUID")
	reaper.SetItemStateChunk(new_item, new_item_chunk)
    -- Set some extra info  PUT THIS BAC
    local vol = reaper.GetMediaItemInfo_Value(item, "D_VOL")
	reaper.SetMediaItemInfo_Value(new_item, "D_VOL", vol)
    local off = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
	reaper.SetMediaItemInfo_Value(new_item, "D_SNAPOFFSET", off)
    CopyTakeInfo(reaper.GetMediaItemTake(item, 0), reaper.GetMediaItemTake(new_item, 0)) 
	reaper.SetMediaItemInfo_Value(new_item, "D_POSITION", position)
	return new_item
end

function CopyMIDI(item, track, position)-- Copy an MIDI Item to Track at position. Be awere that it will change the item selection to the new item so use SaveSelectedItems() before calling it and then LoadSelectedItems(items_list)
    local retval, chunk = reaper.GetItemStateChunk( item, "", false )
    local chunk = bfut_ResetAllChunkGuids(chunk, "IGUID")
    local chunk = bfut_ResetAllChunkGuids(chunk, "GUID")
    local chunk = bfut_ResetAllChunkGuids(chunk, "POOLEDEVTS")
    local chunk = ChangeChunkPosition(chunk, position)

    local new_item = reaper.CreateNewMIDIItemInProj( track, 3, 0.1 )
    reaper.SetItemStateChunk( new_item, chunk, false )
    return new_item
end

function CopyMediaItem(item, track, position, selectcopy) -- It will change your item selection to the new item if you don't want this use You can put the SaveSelectedItems() and LoadSelectedItems().
    local selectcopy = selectcopy or false -- when selectcopy is true the copied item will be selected
    local ismidi = reaper.TakeIsMIDI(reaper.GetMediaItemTake(item, 0))
    local new_item = nil
    if ismidi == true then
        new_item = CopyMIDI(item, track, position) 
    else 
        new_item = CopyMediaNotMIDI(item, track, position)
    end
    reaper.UpdateItemInProject(new_item)
    if selectcopy then 
        reaper.Main_OnCommand(40289, 0)--Item: Unselect all items
        reaper.SetMediaItemSelected( new_item, true )
    end
    return new_item
end

--Exemple Copy Items to Selected Track  
local count_sel_items = reaper.CountSelectedMediaItems(0)
local count_sel_tracks = reaper.CountSelectedTracks(0)
if count_sel_tracks > 0 and count_sel_items > 0 then
    --Saves some info
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh( 1 )
    --local items_list = SaveSelectedItems() 
    --The actual thing
    for items_i = 0,count_sel_items-1 do
        local item = reaper.GetSelectedMediaItem(0, items_i)
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        for i = 0, count_sel_tracks-1 do
            local track_loop = reaper.GetSelectedTrack(0, i)
            CopyMediaItem(item, track_loop, pos)
            reaper.UpdateArrange()
        end
        --LoadSelectedItems(items_list)
    end
    --Load things up
    reaper.PreventUIRefresh( -1 )
    reaper.Undo_EndBlock('Copy Items to Selected Tracks', -1)
end

