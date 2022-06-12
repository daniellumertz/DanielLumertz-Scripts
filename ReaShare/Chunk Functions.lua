-- @noindex

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

function CreateTrackWithChunk(chunk,idx, new_guid)
    reaper.InsertTrackAtIndex( idx, false ) -- wantDefaults=TRUE for default envelopes/FX,otherwise no enabled fx/env
    local new_track = reaper.GetTrack(0, idx)
    if new_guid then  
        chunk = ResetAllIndentifiers(chunk)
    end

    reaper.SetTrackStateChunk(new_track, chunk, false)
    return new_track
end

function CreateMediaItemWithChunk2(chunk, track, position ) -- Modded from amagalma: https://forums.cockos.com/showpost.php?p=2456585&postcount=24
    chunk = ResetAllIndentifiers(chunk)
    local new_item = reaper.AddMediaItemToTrack( track )
    reaper.SetItemStateChunk( new_item, chunk, false )
    reaper.SetMediaItemInfo_Value( new_item, "D_POSITION" , position ) -- Alternative is to use the position inside the chunk for that just scrap this line. Or calculate the difference between the items and  position + edit cursor position
    return new_item
end

---Create Medias Items with chunk. Keep the distance between the items 
---@param chunk string string to create
---@param track track track to paste
---@param start_paste_pos number where it will start pasting
---@param pad_len number pad is the smallest chunk position from the items to be pasted
---@return unknown
function CreateMediaItemWithChunk(chunk, track, start_paste_pos, pad_len )
    chunk = ResetAllIndentifiers(chunk)
    local new_item = reaper.AddMediaItemToTrack( track )
    reaper.SetItemStateChunk( new_item, chunk, false )
    local chunk_pos = GetChunkVal(chunk,'POSITION')
    local new_pos = (start_paste_pos - pad_len) + chunk_pos 
    reaper.SetMediaItemInfo_Value( new_item, "D_POSITION" , new_pos ) -- Alternative is to use the position inside the chunk for that just scrap this line. Or calculate the difference between the items and  position + edit cursor position
    return new_item
end

function GetProjectChunk(proj,temp_filename)
    reaper.Main_SaveProjectEx( proj, temp_filename, 0 )
    local chunk = readAll(temp_filename)
    os.remove(temp_filename)
    return chunk
end

function GetChunkVal(chunk,key)
    return string.match(chunk,key..' '..'(.-)\n')
end