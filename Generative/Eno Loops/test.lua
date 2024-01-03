local os_separator = package.config:sub(1,1)
function dofile_all(path)
    local i = 0
    while true do 
        local file = reaper.EnumerateFiles( path, i )
        i = i + 1
        if not file  then break end 
        dofile(path..os_separator..file)
    end
end

-- get script path
ScriptPath = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
-- dofile all files inside functions folder
dofile_all(ScriptPath..os_separator..'Functions')
---Crop Item position keeping elements on the same place
---@param item item
---@param new_start_pos number optional new start position in seconds
---@param new_end_pos number optional new end position in seconds
---@param start number optional original start position in seconds, if not provided function will get it, provide if you already have and save resources 
---@param length number optional original length position in seconds, if not provided function will get it, provide if you already have and save resources 
function CropItem(item, new_start_pos, new_end_pos, start, length)
    start = start or reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    length = length or reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    local fim = start + length
    if new_end_pos then
        local dif = new_end_pos - start
        reaper.SetMediaItemLength( item, dif, false )
        length = dif
    end
    if new_start_pos then
        local dif = new_start_pos - start
        reaper.SetMediaItemPosition(item, new_start_pos, false)
        reaper.SetMediaItemLength( item, length - dif, false )

        for take in enumTakes(item) do
            local offset = reaper.GetMediaItemTakeInfo_Value(take, 'D_STARTOFFS')            
            local rate = reaper.GetMediaItemTakeInfo_Value(take, 'D_PLAYRATE')            
            reaper.SetMediaItemTakeInfo_Value( take, 'D_STARTOFFS' , offset + (dif*rate) )
        end
    end    
end

local item = reaper.GetSelectedMediaItem(0, 0)
reaper.ShowConsoleMsg('a')
CropItem(item, 4)
reaper.UpdateArrange()

