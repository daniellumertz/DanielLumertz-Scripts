-- @noindex
---Create Items using a Chunk Sequence
---@param pasted_chunk string Items Chunks
---@param item_pattern string Pattern That start Item Chunks
---@param insert_track MediaTrack Track to paste items
---@param paste_time number Time to paste items
function PasteItemChunksAtTimeAtTrack(pasted_chunk,item_pattern,insert_track,paste_time)
	pasted_chunk = '\n'..pasted_chunk..'\n'..item_pattern -- To put first and last chunk in a pattern.

    for item_chunk in SubString(pasted_chunk,'\n(<ITEM.-)\n<ITEM') do
        local item
        item, paste_time = CreateMediaItemWithChunk(item_chunk, insert_track, paste_time) 
    end

end

---Create Medias Items with chunk. Keep the distance between the items 
---@param chunk string string to create
---@param track MediaTrack track to paste
---@param start_paste_pos number where it will start pasting
---@param pad_len number pad is the smallest chunk position from the items to be pasted
---@return MediaItem new_item
---@return number new_item_end
function CreateMediaItemWithChunk(chunk, track, paste_pos )
    chunk = ResetAllIndentifiers(chunk)
    local new_item = reaper.AddMediaItemToTrack( track )
    reaper.SetItemStateChunk( new_item, chunk, false )
    reaper.SetMediaItemInfo_Value( new_item, "D_POSITION" , paste_pos ) -- Alternative is to use the position inside the chunk for that just scrap this line. Or calculate the difference between the items and  position + edit cursor position
    -- get the length of the item and the length of the source. trim the item and get the new end value.
    local new_take = reaper.GetActiveTake(new_item)
    local new_source = reaper.GetMediaItemTake_Source( new_take )
    local source_length, lengthIsQN = reaper.GetMediaSourceLength( new_source )
    if lengthIsQN then
        -- get the length in seconds
        source_length = reaper.TimeMap2_QNToTime( 0, source_length )
    end
    local new_item_end = paste_pos + source_length
    
    reaper.SetMediaItemInfo_Value( new_item, "D_LENGTH", source_length)
    --local new_item_end = paste_pos + new_item_len
    return new_item, new_item_end
end

function GetChunkVal(chunk,key)
    return string.match(chunk,key..' '..'(.-)\n')
end

function bfut_ResetAllChunkGuids(item_chunk, key)
    while item_chunk:match('%s('..key..')') do
        item_chunk = item_chunk:gsub('%s('..key..')%s+.-[\r]-[%\n]', "\ntemp%1 "..reaper.genGuid("").."\n", 1)
    end
    return item_chunk:gsub('temp'..key, key), true
end

function SubMagicChar(string)
    local string = string.gsub(string, '[%[%]%(%)%+%-%*%?%^%$%%]', '%%%1')
    return string
end
  
function ResetChunkIndentifier(chunk, key)
    for line in chunk:gmatch( '(.-)\n+') do
        if line:match(key) then
            local new_line = line:gsub(key.."%s+{.+}",key..' '..reaper.genGuid(""))
            line = SubMagicChar(line)
            chunk=string.gsub(chunk,line,new_line)
        end
    end
    return chunk
end

function ResetAllIndentifiers(chunk) -- Tested in Tracks. 
    -- Track
    chunk = ResetChunkIndentifier(chunk, 'TRACKID')
    chunk = ResetChunkIndentifier(chunk, 'FXID')
    -- Items
    chunk = ResetChunkIndentifier(chunk, 'GUID')
    chunk = ResetChunkIndentifier(chunk, 'IGUID')
    chunk = ResetChunkIndentifier(chunk, 'POOLEDEVTS')
    -- Envelopes
    chunk = ResetChunkIndentifier(chunk, 'EGUID')
    return chunk
end