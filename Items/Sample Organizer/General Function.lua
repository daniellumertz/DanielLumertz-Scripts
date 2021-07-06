-- @noindex
function msg(val) 
    reaper.ShowConsoleMsg('\n'..tostring(val))
end

function bfut_ResetAllChunkGuids(item_chunk, key) -- (I changed a little but it is from here: https://github.com/bfut/ReaScripts/blob/main/Items%20Editing/bfut_Replace%20item%20under%20mouse%20cursor%20with%20selected%20item.lua
    item_chunk = item_chunk:gsub('%s('..key..')%s+.-[\r]-[%\n]', "\ntemp%1 "..reaper.genGuid("").."\n", 1)
    return item_chunk:gsub('temp'..key, key), true
end


function CopyMIDI(item, track)-- Copy an Item to Track
    local retval, chunk = reaper.GetItemStateChunk( item, "", false )
    local chunk = bfut_ResetAllChunkGuids(chunk, "IGUID")
    local chunk = bfut_ResetAllChunkGuids(chunk, "GUID")

    local new_item = reaper.CreateNewMIDIItemInProj( track, 3, 0.1 )
    reaper.SetItemStateChunk( new_item, chunk, false )

    local items_list = SaveSelectedItems()

    reaper.SetMediaItemSelected( new_item, true )
    reaper.Main_OnCommand(41613, 0) -- Item: Remove active take from MIDI source data pool (AKA un-pool, un-ghost, make unique) 
    LoadSelectedItems(items_list)
    return new_item
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
            print(list[i])
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

function sleep (a) 
    local sec = tonumber(os.clock() + a); 
    while (os.clock() < sec) do 
    end 
end



---- RE

function literalize(str)
    return str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", function(c) return "%" .. c end)
end

function GetGUIDFromEnvelope(envelope)
    local ret2, envelopeChunk = reaper.GetEnvelopeStateChunk(envelope, "")
    local GUID = "{" ..  string.match(envelopeChunk, "GUID {(%S+)}") .. "}"
    return GUID
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



