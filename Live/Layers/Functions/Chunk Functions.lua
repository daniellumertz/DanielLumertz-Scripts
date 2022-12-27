--@noindex

------
-- Get
------
---Return the value of a key in the chunk. Return the Firt Key Match.
---@param chunk string chunk
---@param key string key like is written in the chunk ex: 'EGUID' 
---@return string value return all the value that is after the key. (Not return the space in between key and value)
function GetChunkVal(chunk,key)
    return string.match(chunk,key..' '..'(.-)\n')
end

---Return the value of a key in the chunk. Return the Firt Key Match.
---@param chunk string chunk
---@param key string key like is written in the chunk ex: 'EGUID' 
---@return string value return all the key line
function GetChunkLine(chunk,key,idx) -- Basically GetChunkVal but return with the key 
    return string.match(chunk,key..' '..'.-\n',idx)
end