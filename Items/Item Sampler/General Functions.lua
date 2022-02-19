-- @noindex
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

function CopyMediaItemToTrack( item, track, position ) -- Thanks Amagalma s2
    local _, chunk = reaper.GetItemStateChunk( item, "", false )
    chunk = chunk:gsub("{.-}", "") -- Reaper auto-generates all GUIDs
    local new_item = reaper.AddMediaItemToTrack( track )
    reaper.SetItemStateChunk( new_item, chunk, false )
    reaper.SetMediaItemInfo_Value( new_item, "D_POSITION" , position )
    return new_item
end



function TrimItem(pasted_item, item, idx_note, notecnt, item_take, endppqpos )
    if Settings.Is_trim_ItemEnd == true  or Settings.Is_trim_StartNextNote == true or Settings.Is_trim_EndNote == true then
        local pasted_start = reaper.GetMediaItemInfo_Value(pasted_item, "D_POSITION")
        local pasted_len = reaper.GetMediaItemInfo_Value(pasted_item, "D_LENGTH")
        local pasted_end = pasted_start + pasted_len

        local trim_values = {}
        
        if Settings.Is_trim_ItemEnd == true then 
            local midi_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local midi_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            local midi_end = midi_start + midi_len
            table.insert(trim_values, midi_end)
        end

        if Settings.Is_trim_StartNextNote == true and idx_note < notecnt-1 then -- Cant be the last note
            local _, _, _, startppqpos_next, _, _, _, _ = reaper.MIDI_GetNote( item_take, idx_note+1 )
            local quarter_next = reaper.MIDI_GetProjQNFromPPQPos( item_take, startppqpos_next )
            local time_next = reaper.TimeMap2_QNToTime( 0, quarter_next )
            table.insert(trim_values, time_next)
        end

        if Settings.Is_trim_EndNote == true then -- Cant be the last note
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

function AddDBinLinear(valbefore, addval )
    local val_before_in_DB = 20 * math.log(valbefore,10) -- Linear to dB
    local dB_newval = val_before_in_DB + addval -- add to dB
    local new_linear = 10^(dB_newval/20) -- dB to Linear
    return new_linear
end

function scale(val,min1,max1,min2,max2)
    return (((max2 - min2)*(val - min1))/(max1 - min1))+min2
end