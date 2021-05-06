-- @noindex
function bfut_ResetAllChunkGuids(item_chunk, key) -- (I changed a little but it is from here: https://github.com/bfut/ReaScripts/blob/main/Items%20Editing/bfut_Replace%20item%20under%20mouse%20cursor%20with%20selected%20item.lua
    item_chunk = item_chunk:gsub('%s('..key..')%s+.-[\r]-[%\n]', "\ntemp%1 "..reaper.genGuid("").."\n", 1)
    return item_chunk:gsub('temp'..key, key), true
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

