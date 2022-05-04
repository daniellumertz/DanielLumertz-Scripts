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

function ResetTrackIndentifiers(track)
    local retval, chunk = reaper.GetTrackStateChunk(track, '', false)
    local new_chunk = ResetAllIndentifiers(chunk)
    reaper.SetTrackStateChunk(track, new_chunk, false)
end

function GetChunkVal(chunk,key)
    return string.match(chunk,key..' '..'(.-)\n')
end

function GetChunkLine(chunk,key,idx) -- Basically GetChunkVal but return with the key 
    return string.match(chunk,key..' '..'.-\n',idx)
end

function ChangeChunkVal(chunk, key, new_value) -- Thanks Sexan 🐱
    local chunk_tbl = split_by_line(chunk)
    for i = 1, #chunk_tbl do
        if chunk_tbl[i]:match(key) then
            chunk_tbl[i] = key .. " " .. new_value
        end
    end
    return table.concat(chunk_tbl,'\n')
end

function literalizepercent(str)
    return str:gsub(
      "[%%]",
      function(c)
        return "%" .. c
      end
    )
end

function ChangeChunkVal2(chunk, key, new_value) -- probably faster ?
    local new_value = literalizepercent(tostring(new_value))
    while chunk:match('%s('..key..')') do
      chunk = chunk:gsub('%s('..key..')%s+.-[\r]-[%\n]', "\ntemp%1 "..new_value.."\n", 1)
    end
    return chunk:gsub('temp'..key, key), true
end

function string.starts(String,Start)
    return string.sub(String,1,string.len(Start))==Start
end

function split_by_line(str)
    local t = {}
    for line in string.gmatch(str, "[^\r\n]+") do
        t[#t + 1] = line
    end
    return t
end

function literalize(str)
    return str:gsub(
      "[%(%)%.%%%+%-%*%?%[%]%^%$]",
      function(c)
        return "%" .. c
      end
    )
end

function ChunkTableGetSection(chunk_lines,key) -- Thanks BirdBird! 🦜
    --GET ITEM CHUNKS
    local section_chunks = {}
    local last_section_chunk = -1
    local current_scope = 0
    local i = 1
    while i <= #chunk_lines do
        local line = chunk_lines[i]
        
        --MANAGE SCOPE
        local scope_end = false
        if line == '<'..key then       
            last_section_chunk = i
            current_scope = current_scope + 1
        elseif string.starts(line, '<') then
            current_scope = current_scope + 1
        elseif string.starts(line, '>') then
            current_scope = current_scope - 1
            scope_end = true
        end
        
        --GRAB ITEM CHUNKS
        if current_scope == 1 and last_section_chunk ~= -1 and scope_end then
            local s = ''
            for j = last_section_chunk, i do
                s = s .. chunk_lines[j] .. '\n'
            end
            last_section_chunk = -1
            table.insert(section_chunks, s)
        end
        i = i + 1
    end
  
    return section_chunks
 end

function GetChunkSection(key, chunk)
    local chunk_lines = split_by_line(chunk)
    local table_Section = ChunkTableGetSection(chunk_lines,key)
    local chunk_section = table.concat(table_Section)
    return chunk_section
end
  
function RemoveChunkSection(key, chunk)
    local chunk_lines = split_by_line(chunk)
    local table_Section = ChunkTableGetSection(chunk_lines,key)
    local old_chunk_Section = table.concat(table_Section)
    local chunk_without_key_Section = string.gsub(chunk,literalize(old_chunk_Section),'') -- Check if is there
    return chunk_without_key_Section, old_chunk_Section -- new chunk, deleted part
end
  
function SwapChunkSection(key,chunk1,chunk2) -- Move Section (key) of chunk1 to chunk2  
    local new_section = GetChunkSection(key, chunk1)
    local new_chunk, _ = RemoveChunkSection(key, chunk2)
    if key == 'AUXVOLENV' or key == 'AUXPANENV' or key == 'AUXMUTEENV' then -- keys that need to be at a specific position
        new_chunk= AddSectionToChunkAfterKey('AUXRECV', new_chunk, new_section) -- Sends Envelope needs to be after Auxrecv 
    else
        new_chunk= AddSectionToChunk(new_chunk, new_section)
    end
    return new_chunk
end


function SwapChunkValue(key,chunk1,chunk2) -- Move a value (key) from chunk1 -> chunk2 
    local new_value = GetChunkVal(chunk1,key)
    return ChangeChunkVal2(chunk2, key, new_value) 
end

function AddSectionToChunk(chunk, section_chunk) -- Track Chunks
    return string.gsub(chunk, '<TRACK', '<TRACK\n'..section_chunk) -- I think I need to literalize this ? 
end

function AddSectionToChunkAfterKey(after_key, new_chunk, new_section) -- If after_key haves a < like <ITEM them input in the string. Just this function haves it
    local tab_chunk = split_by_line(new_chunk)
    local insert_point 
    for i, line in pairs(tab_chunk) do
        if string.starts(line, after_key) then
            insert_point = i
            break
        end  
    end

    local tab_new_section = split_by_line(new_section)
    for i, line in pairs(tab_new_section) do
        local index = insert_point+i
        table.insert(tab_chunk, index, line) 
    end

    return table.concat(tab_chunk,'\n')
end

function GetSendChunk(chunk, send_idx) -- send_idx can be nil to get all send chunks
    if not send_idx then 
        send_idx = ''
    end

    local chunk_table = {}
    local i = 0
    for send_chunk in string.gmatch(chunk,'AUXRECV '..send_idx..'.-\n') do
        while true do
            --local next_line = string.match(chunk,literalize(send_chunk)..'(.-\n)')
            local next_line = match_n(chunk, literalize(send_chunk)..'(.-\n)', i)
            if string.match(next_line,'<AUX') then
                --send_chunk = string.match(chunk, literalize(send_chunk)..literalize(next_line)..'.-\n>\n')
                send_chunk = match_n(chunk, literalize(send_chunk)..literalize(next_line)..'.-\n>\n', i)
            else 
                break
            end
        end
        table.insert(chunk_table, send_chunk)
        i = i + 1
    end
    return chunk_table
end