--@noindex
--version: 0.0

DL = DL or {}
DL.aitems = {}

function DL.aitems.UnselectAll(proj) -- maybe doing by chunks is faster!
    for track in DL.enum.Tracks(proj) do
        for env in DL.enum.TrackEnvelopes(track) do
            local cnt =  reaper.CountAutomationItems( env )
            for i = 0, cnt-1 do
                reaper.GetSetAutomationItemInfo( env, i, 'D_UISEL', 0, true )
            end
        end
    end
end

---Adds/removes from selection Automation items
---@param env TrackEnvelope envelope to look into
---@param start_range number beginning of the range (start point are includded in the range)
---@param fim_range number end of the range (end points are not includded in the range)
---@param only_start_in_range boolean only get items that start inside the range (if start at start_range it is includded)
---@param only_end_in_range boolean only get items that end inside the range (if end at the fim_range it is includded)
---@return number[] ai_items table with the ai idx
function DL.aitems.GetInRange(env, start_range,fim_range,only_start_in_range,only_end_in_range)
    local ai_items = {}
    local cnt = reaper.CountAutomationItems(env)
    for i = 0, cnt-1 do
        local pos = reaper.GetSetAutomationItemInfo(env, i, 'D_POSITION', 0, false)

        if only_start_in_range and pos < start_range then goto continue end -- filter if only_start_in_range 
        if pos >= fim_range then break end -- start after range. break

        local len = reaper.GetSetAutomationItemInfo(env, i, 'D_LENGTH', 0, false)
        local final_pos = len + pos
        if only_end_in_range and final_pos > fim_range then goto continue end -- filter if only_end_in_range

        if final_pos > start_range then
            ai_items[#ai_items+1] = i
        end

        ::continue::
    end
    return ai_items
end

---Adds/removes from selection Automation items from the entire project
---@param proj ReaProject|0|nil
---@param start_range number beginning of the range (start point are includded in the range)
---@param fim_range number end of the range (end points are not includded in the range)
---@param only_start_in_range boolean only get items that start inside the range (if start at start_range it is includded)
---@param only_end_in_range boolean only get items that end inside the range (if end at the fim_range it is includded)
---@param is_select boolean|1|0? true by default. if true will select if false will unselect
---@param env_list TrackEnvelope optional if nil will select AI from all tracks. can be a table with envelopes or the envelope itself
function DL.aitems.SelectInRange(proj,start_range,fim_range,only_start_in_range,only_end_in_range, is_select, env_list)
    is_select = (type(is_select) == "number" and is_select) or (is_select == nil and 1) or (is_select == true and 1) or 0 
    if not env_list then 
        env_list = {}
        for track in DL.enum.Tracks(proj) do
            for envelope_loop in DL.enum.TrackEnvelopes(track) do
                table.insert(env_list,envelope_loop)
            end
        end
    end
    if type(env_list) == 'userdata' then 
        env_list = {env_list}
    end

    for k, env_loop in ipairs(env_list) do
        local ai_list = DL.aitems.GetInRange(env_loop, start_range,fim_range,only_start_in_range,only_end_in_range)
        for k, idx in ipairs(ai_list) do
            reaper.GetSetAutomationItemInfo(env_loop, idx, 'D_UISEL', is_select, true)
        end
    end
end

---Adds/removes from selection Automation items from the entire project
---@param proj ReaProject|0|nil project
---@param start_range number beginning of the range (start point are includded in the range)
---@param fim_range number end of the range (end points are not includded in the range)
---@param only_start_in_range boolean only get items that start inside the range (if start at start_range it is includded)
---@param only_end_in_range boolean only get items that end inside the range (if end at the fim_range it is includded)
---@param env_list TrackEnvelope optional if nil will delete from all tracks. can be a table with envelopes or the envelope itself
function DL.aitems.DeleteInRange(proj,start_range,fim_range,only_start_in_range,only_end_in_range,env_list)
    if not env_list then 
        env_list = {}
        for track in DL.enum.Tracks(proj) do
            for envelope_loop in DL.enum.TrackEnvelopes(track) do
                table.insert(env_list,envelope_loop)
            end
        end
    end
    if type(env_list) == 'userdata' then 
        env_list = {env_list}
    end
    for k, env_loop in ipairs(env_list) do
        local delete_list = DL.aitems.GetInRange(env_loop, start_range,fim_range,only_start_in_range,only_end_in_range)
        DL.aitems.Delete(env_loop,delete_list)
    end        
end

---Crop Automation Item position keeping elements on the same place
---@param env any
---@param ai_id any
---@param new_start_pos number? optional new start position in seconds
---@param new_end_pos number? optional new end position in seconds
---@param start number? optional original start position in seconds, if not provided function will get it, provide if you already have and save resources 
---@param length number? optional original length position in seconds, if not provided function will get it, provide if you already have and save resources 
function DL.aitems.Crop(env, ai_id, new_start_pos, new_end_pos, start, length)
    start = start or reaper.GetSetAutomationItemInfo(env, ai_id, 'D_POSITION', 0, false)
    length = length or reaper.GetSetAutomationItemInfo(env, ai_id, 'D_LENGTH', 0, false)
    local fim = start + length
    if new_end_pos then
        local dif = fim - new_end_pos
        reaper.GetSetAutomationItemInfo(env, ai_id, 'D_LENGTH', length - dif, true)
        length = length - dif
    end
    if new_start_pos then
        local dif = new_start_pos - start
        local off_set = reaper.GetSetAutomationItemInfo(env, ai_id, 'D_STARTOFFS', 0, false) 
        local playrate = reaper.GetSetAutomationItemInfo(env, ai_id, 'D_PLAYRATE', 0, false)

        reaper.GetSetAutomationItemInfo(env, ai_id, 'D_POSITION', new_start_pos, true)
        reaper.GetSetAutomationItemInfo(env, ai_id, 'D_STARTOFFS', (dif*playrate)+off_set, true)
        reaper.GetSetAutomationItemInfo(env, ai_id, 'D_LENGTH', length-dif, true)
    end    
end

---Copy information values between ai from origem to destino, all info are strings in table string 
---@param env_origem TrackEnvelope envelope origin
---@param env_destino TrackEnvelope envelope destin
---@param ai_origem_idx number origem idx autometion item
---@param ai_destino_idx number destiny idx automation item
---@param table_strings table table with the strings value names. ex {'D_PLAYRATE', 'D_BASELINE', 'D_AMPLITUDE', 'D_LOOPSRC'}
function DL.aitems.CopyValues(env_origem, env_destino, ai_origem_idx,ai_destino_idx,table_strings)
    for index, info_string in ipairs(table_strings) do
        local ai_origem_value =  reaper.GetSetAutomationItemInfo(env_origem, ai_origem_idx, info_string, 0, false )
        reaper.GetSetAutomationItemInfo(env_destino, ai_destino_idx, info_string, ai_origem_value, true )
    end
end

---Delete Autometion item from envelope using ai_idx
---@param env TrackEnvelope
---@param ai_idx number|number[] automation item index, or table with indexes
function DL.aitems.Delete(env,ai_idx)
    if type(ai_idx) == 'number' then ai_idx = {ai_idx} end
    local ai_chunk_pattern = 'POOLEDENVINST' 
    local retval, chunk = reaper.GetEnvelopeStateChunk( env, '', false )
    local idx = 0

    for line in chunk:gmatch(ai_chunk_pattern..'.-\n') do
        if DL.t.HaveValue(ai_idx, idx, false) then
            chunk = chunk:gsub(line, '')
        end
        idx = idx + 1
    end
    reaper.SetEnvelopeStateChunk(env, chunk, false)
end