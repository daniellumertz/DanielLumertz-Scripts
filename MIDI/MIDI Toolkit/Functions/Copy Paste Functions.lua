--@noindex

function CopyParam(event_size,is_event)
    local original_notes = CreateNotesTable(true,false,true)
    local original_notes = EventTogether(original_notes,event_size,is_event)
    local param_list = CopyMIDIParametersFromEventList(original_notes, false,false,false,false, false, 'M')

    return param_list    
end

function PasteParam(param,new_param_seq,interpolate,event_size,is_event,complete)
    if not new_param_seq or #new_param_seq <= 0 then return end

    if param == 'groove' then
        new_param_seq = MakeGrooveTable(new_param_seq)
    end
    -- Set settings
    local pitch_sequence, pos_sequence,vel_sequence,len_sequence
    if param == 'pitch' then
        pitch_sequence = {sequence = new_param_seq, type = 'pitch', complete = true,  use_mutesymbol = false, interpolate = interpolate, complete = complete}
    elseif param == 'interval' then
        pitch_sequence = {sequence = new_param_seq, type = 'interval', complete = true,  use_mutesymbol = false, loop = false, interpolate = interpolate, complete = complete}
    elseif param == 'rhythm_qn' then
        pos_sequence = {sequence = new_param_seq, type = 'rhythm', delta = true, use_mutesymbol = false, unit = 'QN', interpolate = interpolate}
    elseif param == 'measure_pos_qn' then
        pos_sequence = {sequence = new_param_seq, type = 'measure_pos', delta = true, use_mutesymbol = false, unit = 'QN', interpolate = interpolate}
    elseif param == 'groove' then
        pos_sequence = {sequence = new_param_seq, type = 'quantize_measure', delta = true, use_mutesymbol = false, unit = 'QN', interpolate = interpolate}
    elseif param == 'len_qn' then
        len_sequence = {sequence = new_param_seq, use_mutesymbol = false, unit = 'QN', interpolate = interpolate}
    elseif param == 'vel' then
        vel_sequence = {sequence = new_param_seq, use_mutesymbol = false, interpolate = interpolate}
    end

    ApplyParameterSequenceToNotesMultipleTakes(event_size,true,is_event,pitch_sequence,pos_sequence,vel_sequence,len_sequence,mute_sequence,channel_sequence,'M',false)

    reaper.Undo_OnStateChange2(0, ScriptName..' '..'Paste')   
    
end

---Get the measure position parameter table and return a table for using in quantize_measure at ApplyParameterSequenceToNotesMultipleTakes. The table is organized by Table[measure][event_idx][paramter_idx] 
---@param param_measure_pos_qn any
function MakeGrooveTable(param_measure_pos_qn)
    if #param_measure_pos_qn <= 0 then return end
    local groove_table = {} 
    local last_measure_position
    for event_idx, event_table in ipairs(param_measure_pos_qn) do
        local measure_position = event_table[1] -- just use the first value
        if not last_measure_position or measure_position <= last_measure_position then -- if start at the same time or earlier then start a new measure
            table.insert(groove_table,{})
        end
        local measure_table = groove_table[#groove_table]
        table.insert(measure_table, event_table)

        last_measure_position = measure_position
    end
    return groove_table
end