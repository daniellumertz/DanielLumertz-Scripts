--@noindex
--version: 0.1

DL = DL or {}
DL.chunk = {}

---Reset all `key` identifiers in a chunk 
---@param chunk string item/track/envelope chunk
---@param key string identifier key Items:(GUID, IGUID, POOLEDEVTS, FXID) Tracks:(TRACKID, FXID) Envelopes:(EGUID)
---@param new_guid string?  optional. Default value is reaper.genGuid(''). If just '' the guid will be the current guid or if no current guid for that Identifier it will generate one.  If just '{}' the guid will be {00000000-0000-0000-0000-000000000000}. 
---@return string chunk return chunk with new guids
function DL.chunk.ResetIndentifiers(chunk, key, new_guid)
    local pattern = '\n'..key..'%s?{.-}\n'
    for sub in chunk:gmatch(pattern) do -- Need to run gsub in a loop for a new reaper.genGuid('') for every occurance. 
        local guid_line = '\n'..key..' '..(new_guid or reaper.genGuid())..'\n'
        local sub_pattern = DL.str.literalize(sub)
        chunk = chunk:gsub(sub_pattern,guid_line, 1) -- Need to be sure gsub is working in the actual line matched at gmatch, just using a gsub with the current GUID could result changing stored information at extstates
    end
    return chunk
end

---@param chunk string
---@param key string
---@return string?
function DL.chunk.GetVal(chunk,key)
    return string.match(chunk,'\n'..key..' '..'(.-)\n')
end

