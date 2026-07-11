-- @noindex
local is = {}

---Applies a parameter to all other clouds
---@param value any The new value to be set for the property.
---@param ... any An array of keys that represent the path to the property to be updated.
function is.ApplyParameter(proj, sequencers, value, ...)
    reaper.Undo_BeginBlock2(proj)
    local address = {...}
    for index, sequencer in ipairs(sequencers) do
         local current = sequencer
        -- Navigate through the address path
        for i = 1, #address-1 do
            current = current[address[i]]
            if not current then
                print('Error: Couldnt save the path: ' .. table.concat(address).. '. Failed to add the following key: '.. address[i] )
                goto continue
            end
        end
        -- Set the final value
        current[address[#address]] = value
        is.SaveSequencer(sequencer.seq, sequencer, sequencer.is_item)
        ::continue::
    end
    reaper.UpdateArrange()
    reaper.Undo_EndBlock2(proj, 'Item Sampler: Update Sequencers Settings', -1)
end

function is.OpenaAllSelectedMediaAsSequencer(proj, is_item)
    local seqs = {}
    local func = (is_item and DL.enum.SelectedMediaItem(proj)) or DL.enum.SelectedTracks2(proj, false)
    for seq in func do 
        local st = is.OpenSequencer(proj, seq, is_item)
        if st then
            seqs[#seqs+1] = st
        end
    end
    seqs.focus = 1
    return seqs 
end

-- In case some undo was called! 
function is.ReopenSequencers(proj, sequencers)
    for k, sequencer in DL.t.ipairs_reverse(sequencers) do
        local stype = sequencer.is_item and 'MediaItem*' or 'MediaTrack*'
        if not reaper.ValidatePtr2(proj, sequencer.seq, stype) then
            table.remove(sequencers, k)
            goto continue
        end

        sequencers[k] = is.OpenSequencer(proj, sequencer.seq, sequencer.is_item)

        ::continue::
    end
    return sequencers
end

function is.OpenSequencer(proj, seq, is_item)
    local st = is.LoadSequencer(proj, seq, is_item)
    if not st then
        -- Check if item is not an pasted item
        if is_item then
            local _, s_guid = DL.item.GetExtState(seq, ExtStates.ext_name, ExtStates.pasted.seq_key)
            if s_guid ~= '' then
                print("Can't make an pasted item into a sequencer item!")
                return false
            end
        end
        -- Make it 
        st = is.MakeSequencer(proj, seq, is_item)
    end
    return st
end

function is.MakeSequencer(proj, seq, is_item)
    local st = {
        groups = {
            BlankGroup:Create('G1')
        },
        is_item = is_item,
        seq = seq
    }
    is.SaveSequencer(seq, st, is_item)
    return st
end

local ext_name = ExtStates.ext_name
local key = ExtStates.sequencers.key
function is.SaveSequencer(seq, st, is_item) -- sequencer item/track, sequencer table, is item
    local guided = is.UserDataToGuid(seq, st)
    local str = DL.serialize.tableToString(guided)
    if is_item then
        DL.item.SetExtState(seq, ext_name, key, str)
    else
        reaper.GetSetMediaTrackInfo_String(seq, string.format('P_EXT:%s : %s', ext_name, key), str, true)
    end
end

function is.LoadSequencer(proj, seq, is_item)
    local ext
    if is_item then
        _, ext = DL.item.GetExtState(seq, ext_name, key)
    else
        _, ext = reaper.GetSetMediaTrackInfo_String(seq, string.format('P_EXT:%s : %s', ext_name, key), '', false)
    end
    if ext then
        local st = DL.serialize.stringToTable(ext)
        if st then
            st = is.GuidToUserData(proj, seq, st)
            return st
        end
    end

    return false
end

function is.CheckSequencers(sequencers)
    for k, sequencer in DL.t.ipairs_reverse(sequencers) do
        -- Check sequencer. 
        local str = sequencer.is_item and 'MediaItem*' or 'MediaTrack*' 
        if not reaper.ValidatePtr(sequencer.seq, str) then
            table.remove(sequencers, k)
        end
    end
    return sequencers    
end

function is.GetSequencerName(st)
    local sequencer_name
    if st.is_item then
        local take = reaper.GetActiveTake(st.seq)
        _, sequencer_name = reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', '', false)
        if sequencer_name == '' then
            sequencer_name = 'Nameless MIDI Item'
        end
    else
        _, sequencer_name = reaper.GetSetMediaTrackInfo_String(st.seq, 'P_NAME', '', false)
        if sequencer_name == '' then
            local idx = reaper.GetMediaTrackInfo_Value(st.seq, 'IP_TRACKNUMBER')
            sequencer_name = '#'..string.format('%d', idx)
        end
        sequencer_name = 'Track: '..sequencer_name
    end
    return sequencer_name
end

------- UserData handlging to be saved

---Makes a deep copy of `t`. 
---@param t table
---@return table new_t
local function deep_copy(t)
    local t2 = {}
    for k,v in pairs(t) do
        if type(v) == "table" then
            t2[k] = DL.t.DeepCopy(v)
        else
            t2[k] = v
        end
    end
    return t2
end

function is.UserDataToGuid(seq, st)
    local new_st = deep_copy(st)
    local guid_func = (new_st.is_item and reaper.GetSetMediaItemInfo_String) or reaper.GetSetMediaTrackInfo_String
    -- Sequencer Item/Track
    new_st.seq = guid_func(seq, 'GUID', '', false) --[[disregarding the change of type]] ---@diagnostic disable-line: param-type-mismatch
    
    -- Groups
    for i, gt in ipairs(new_st.groups) do
        -- Source Item/Track
        do
            local remove_list = {}
            for k, source in ipairs(gt.list_sequence) do
                local is_item = reaper.ValidatePtr( source, 'MediaItem*' )
                local is_track =  reaper.ValidatePtr( source, 'MediaTrack*' )
                if not is_item and not is_track then
                    remove_list[#remove_list+1] = k
                else
                    local guid_f = (is_item and reaper.GetSetMediaItemInfo_String) or reaper.GetSetMediaTrackInfo_String
                    _, gt.list_sequence[k] = guid_f(source, 'GUID', '', false)
                end
            end
            for ri = #remove_list, 1, -1 do
                table.remove(gt.list_sequence, ri)
            end
        end
        -- Target Track
        do
            local remove_list = {}
            if gt.Settings.Targets then
                for k, track in ipairs(gt.Settings.Targets) do
                    local is_track =  reaper.ValidatePtr( track, 'MediaTrack*' )
                    if not is_track then
                        remove_list[#remove_list+1] = k
                    else
                        _, gt.Settings.Targets[k] = reaper.GetSetMediaTrackInfo_String(track, 'GUID', '', false)
                    end
                end
                for ri = #remove_list, 1, -1 do
                    table.remove(gt.Settings.Targets, ri)
                end
            end
        end
    end
    return new_st
end

function is.GuidToUserData(proj, seq, st)
    local proj = proj or 0 -- current project
    st.seq = seq 
    -- Groups
    for i, gt in ipairs(st.groups) do
        -- Source Item/Track
        do
            local remove_list = {}
            for k, guid in ipairs(gt.list_sequence) do
                -- Try item first, then track
                local ptr = reaper.BR_GetMediaItemByGUID(proj, guid)
                if not ptr or not reaper.ValidatePtr(ptr, 'MediaItem*') then
                    ptr = reaper.BR_GetMediaTrackByGUID(proj, guid)
                end
                if not ptr or (not reaper.ValidatePtr(ptr, 'MediaItem*') and not reaper.ValidatePtr(ptr, 'MediaTrack*')) then
                    remove_list[#remove_list+1] = k
                else
                    gt.list_sequence[k] = ptr
                end
            end
            for ri = #remove_list, 1, -1 do
                table.remove(gt.list_sequence, ri)
            end
        end
        -- Target Track
        if gt.Settings.Targets then
            local remove_list = {}
            for k, guid in ipairs(gt.Settings.Targets) do
                local ptr = reaper.BR_GetMediaTrackByGUID(proj, guid)
                if not ptr or not reaper.ValidatePtr(ptr, 'MediaTrack*') then
                    remove_list[#remove_list+1] = k
                else
                    gt.Settings.Targets[k] = ptr
                end
            end
            for ri = #remove_list, 1, -1 do
                table.remove(gt.Settings.Targets, ri)
            end
        end
    end
    return st
end

return is