--@noindex

----------
-- Rhythm
----------

---Generate the markov sequence using settings and start sequence.
---@param original_sequence table table contaning the settings of the current midi sequence. OPTIONAL
---@param markov_table table table contaning the markov table. to be used to generate the sequence
---@param len number number of how many new notes to generate
---@param param_settings table table contaning the user settings.
---@param keep_start boolean keep the start of the original_sequece? 
---@param weight_settings table weight_settings.take = postion take. weight_settings.w = weight value.  
---@return table table contaning the generated new sequence.
---@return table new_qn_pos_sequence table with all new qn position
function GenerateNewSequenceRhythm(original_sequence, markov_table, len, param_settings, keep_start, weight_settings, mute_symbol) -- feed it with (original_sequence, markov_table.rhythm, #original_sequence.rhythm_qn, rhythm_settings, rhythm_settings.keep_start)

    local start_sequence, new_qn_pos_sequence = GetStartSequence(keep_start, original_sequence,'rhythm_qn',param_settings)

    -- Create Weight list!!
    local weight_table = CreatePosWeight(weight_settings)
    --
    local sequence, new_qn_pos_sequence =  GenerateMarkovSequenceRhythmWeighted(markov_table, len, param_settings.order, start_sequence, true, false, new_qn_pos_sequence, weight_table, mute_symbol)
    return sequence, new_qn_pos_sequence
end

--- @param t_markov table --Markov table
--- @param len number -- length of the generated sequence. The generated sequence table will start with the same indexes as start table (or markov_order indexes of nothing symbol) then the generated sequence that the length will be  = len
--- @param order number -- set the order used in markov, if nil will use ###ordeer in t_markov
--- @param start table -- hardcode the start of the sequence. if set to nil or a blank table. it will create the start using nothing symbols 
--- @param filter_nothing boolean -- if on it will remove all occurances that generates nothing_symbol in t_markov
--- @param break_on_nothing boolean -- if sequence is generate a '*' it will stop the sequence
--- @param new_qn_pos_sequence table  talbe with all new qn position, already add the original values if keepstart, and the first value if not. = {qn1,qn2,qn3...}
--- @param weight_table table only if user selected a take for weightning rhythms by position. weight table to feed the apply markov! it have the values in qn_pos. weight_table = {w = weight_settings.w, max_distance = 127, w_values = {{val = qnval, w = weidth},{val = qnval, w = weidth} ...}}
--- @return table -- table with the sequece in the values
function GenerateMarkovSequenceRhythmWeighted(t_markov,len,order,start,filter_nothing,break_on_nothing ,new_qn_pos_sequence, weight_table, mute_symbol) -- TODO Filter nothing option add order. 
    local nothing = '*'
    local separetor = ';'
    if not order then order = #t_markov end
    local last_val = start
    -- If nothing is nil then fill last_val with nothing symbol order times.
    if not last_val or #last_val == 0 then 
        last_val = {}
        for i = 1, order do
            table.insert(last_val,nothing)
        end
    end
    -- Generate Sequence!!!
    local sequence = TableCopy(last_val)
    for i = 1, len do
        --- if weight_table Convert QN pos to rhythms from last note
        -- markov_table is for interval between events (like rhythms or intervals) and weight_table.w_values[i].val have fixed values (like qn_position,pitch, pitchclasses ) this will calculate the interval between last value and weight_table.w_values[i].val and create another table . 
        local weight_table_converted = ConvertWeightList_QNtoRhythm(weight_table,new_qn_pos_sequence)
        ---------------------------------------------------------------------------------------------------------------------
        --local result = ApplyMarkov(t_markov, last_val, true, false) -- old
        local result = ApplyMarkovWeighted(t_markov, last_val, true, weight_table_converted)
        -- for weight table
        local result_table = MidiParametersSeparate(result)
        local r_result, is_mute = ParameterStringToVals(result_table[1],mute_symbol)
        table.insert(new_qn_pos_sequence, new_qn_pos_sequence[#new_qn_pos_sequence] + r_result)
        -- for sequence
        table.insert(sequence,result)
        table.subs(last_val, result)
        if break_on_nothing and result == nothing then break end
    end
    return sequence, new_qn_pos_sequence
end


--- For PosWeight
function CreatePosWeight(weight_settings)
    -- Create Weight list!!
    local weight_table
    if TableCheckValues(weight_settings,'take') then
        if reaper.ValidatePtr2(0, weight_settings.take, 'MediaItem_Take*') then

            weight_table = {w = weight_settings.w, w_values = {}, linear = weight_settings.w}

            local pos_weight_param = CreateNotesTable(false,false,true,{weight_settings.take}) -- get notes from pos weight take 
            pos_weight_param = EventTogether(pos_weight_param, false, false) -- Event size dont matter here should be only a note per position and if not that is not a big problem
            pos_weight_param = CopyMIDIParametersFromEventList(pos_weight_param) -- wont mark muted notes!!

            local last_pos_qn
            local max_qn_dif = 0 -- saves the biggest rhythm (difference in qn between notes) uses this for getting max_distance
            for i = 1, #pos_weight_param.pos_qn do
                local pos_qn = tonumber(pos_weight_param.pos_qn[i][1]) -- always the first event
                local velocity = tonumber(pos_weight_param.vel[i][1]) -- always the first event
                local weight  = VelocityToWeight(velocity,weight_settings)
                local w_value = { val = pos_qn, w = weight}

                table.insert(weight_table.w_values, w_value)

                if last_pos_qn then
                    max_qn_dif = math.max(max_qn_dif, pos_qn - last_pos_qn)
                end
                last_pos_qn = pos_qn
            end
            weight_table.max_distance = max_qn_dif / 2 -- divided by 2 because the distance is between the notes and the biggest difference will be a note in the middle

        else 
            weight_settings = nil -- If the item is missing remove the table
        end
    end
    return weight_table
end

function ConvertWeightList_QNtoRhythm(weight_table,new_qn_pos_sequence)
    local weight_table_converted  
    if weight_table then
        weight_table_converted = TableDeepCopy(weight_table)
        for i = #weight_table.w_values, 1, - 1 do
            local w_value = weight_table.w_values[i]
            local fixed_value = w_value.val --qn rhythm
            local last_value = tonumber(new_qn_pos_sequence[#new_qn_pos_sequence])
            local interval = fixed_value - last_value -- substify for a interval/rhythm 
            if interval  <= 0 then -- remove at weight for the same position
                table.remove(weight_table_converted.w_values, i)
            else
                weight_table_converted.w_values[i].val = interval
            end
        end
        if #weight_table_converted.w_values == 0 then weight_table_converted = nil end -- if it haves no value inside it         
    end
    return weight_table_converted
end


----------
-- Measure Pos
----------

function GenerateNewSequenceMeasurePos(original_sequence, markov_table, len, param_settings, keep_start, weight_settings, mute_symbol)
    local start_sequence, new_qn_pos_sequence = GetStartSequence(keep_start, original_sequence,'measure_pos_qn',param_settings)

    -- Create Weight list!!
    local weight_table = CreateMeasurePosWeight(weight_settings)
    --
    local sequence, new_qn_pos_sequence =  GenerateMarkovSequenceMeasurePosWeighted(markov_table, len, param_settings.order, start_sequence, true, false, new_qn_pos_sequence, weight_table, mute_symbol)
    return sequence, new_qn_pos_sequence
end

--- @param t_markov table --Markov table
--- @param len number -- length of the generated sequence. The generated sequence table will start with the same indexes as start table (or markov_order indexes of nothing symbol) then the generated sequence that the length will be  = len
--- @param order number -- set the order used in markov, if nil will use ###ordeer in t_markov
--- @param start table -- hardcode the start of the sequence. if set to nil or a blank table. it will create the start using nothing symbols 
--- @param filter_nothing boolean -- if on it will remove all occurances that generates nothing_symbol in t_markov
--- @param break_on_nothing boolean -- if sequence is generate a '*' it will stop the sequence
--- @param new_qn_pos_sequence table  talbe with all new qn position, already add the original values if keepstart, and the first value if not. = {qn1,qn2,qn3...}
--- @param weight_table table only if user selected a take for weightning rhythms by position. weight table to feed the apply markov! it have the values in qn_pos. weight_table = {w = weight_settings.w, max_distance = 127, w_values = {{val = qnval, w = weidth},{val = qnval, w = weidth} ...}}
--- @return table -- table with the sequece in the values
function GenerateMarkovSequenceMeasurePosWeighted(t_markov,len,order,start,filter_nothing,break_on_nothing ,new_qn_pos_sequence, weight_table, mute_symbol) -- TODO Filter nothing option add order. 
    local function GetMeasureStartFromQN(qn)
        local retval, qnMeasureStart, qnMeasureEnd = reaper.TimeMap_QNToMeasures( 0, qn )
        return qnMeasureStart
    end

    local nothing = '*'
    local separetor = ';'
    if not order then order = #t_markov end
    local last_val = start
    -- If nothing is nil then fill last_val with nothing symbol order times.
    if not last_val or #last_val == 0 then 
        last_val = {}
        for i = 1, order do
            table.insert(last_val,nothing)
        end
    end
    -- Generate Sequence!!!
    local sequence = TableCopy(last_val)
    local last_measure_start = GetMeasureStartFromQN(new_qn_pos_sequence[#new_qn_pos_sequence])
    for i = 1, len do
        local result = ApplyMarkovWeighted(t_markov, last_val, true, weight_table)
        -- for weight tables
        local result_num = ParameterStringToVals(MidiParametersSeparate(result)[1], mute_symbol)
        local last = ParameterStringToVals(MidiParametersSeparate(last_val[#last_val])[1], mute_symbol) or 0
        if tonumber(last) and result_num < last then -- new measure, set last_measure_start
            local retval, qnMeasureStart, qnMeasureEnd = reaper.TimeMap_QNToMeasures( 0, last )
            last_measure_start = qnMeasureEnd
        end
        table.insert(new_qn_pos_sequence, last_measure_start + result_num)
        -- for sequences
        table.insert(sequence,result)
        table.subs(last_val, result)
        if break_on_nothing and result == nothing then break end
    end
    return sequence, new_qn_pos_sequence
end

--- For MeasurePosWeight
function CreateMeasurePosWeight(weight_settings)
    -- Create Weight list!!
    local weight_table
    if TableCheckValues(weight_settings,'take') then
        if reaper.ValidatePtr2(0, weight_settings.take, 'MediaItem_Take*') then

            weight_table = {w = weight_settings.w, w_values = {}, type = 'specific'}

            local pos_weight_param = CreateNotesTable(false,false,true,{weight_settings.take}) -- get notes from pos weight take 
            pos_weight_param = EventTogether(pos_weight_param, false, false) -- Event size dont matter here should be only a note per position and if not that is not a big problem
            pos_weight_param = CopyMIDIParametersFromEventList(pos_weight_param)

            local measure_positions = { } -- will save all velocity sum and not count per measure position. Ex:  measure_positions = {val1 = {note_count = 1, velocity_sum = 100}, val2 = {note_count = 2, velocity_sum = 200} }
            for i = 1, #pos_weight_param.measure_pos_qn do
                local m_pos = pos_weight_param.measure_pos_qn[i][1]
                if not measure_positions[m_pos] then  measure_positions[m_pos] = {note_count = 0, weight_sum = 0} end
                measure_positions[m_pos].note_count = measure_positions[m_pos].note_count + 1
                local weight = VelocityToWeight(tonumber(pos_weight_param.vel[i][1]),weight_settings)
                measure_positions[m_pos].weight_sum = measure_positions[m_pos].weight_sum + weight
            end

            for m_pos, count_table in pairs(measure_positions) do
                local avarage_weight = count_table.weight_sum/count_table.note_count
                local w_table = {val = m_pos, w = avarage_weight }
                table.insert(weight_table.w_values,w_table)
            end
        else 
            weight_settings = nil -- If the item is missing remove the table
        end
    end
    return weight_table
end

----------
-- Pitch --
---------- 


---comment
---@param original_sequence table table with the original notes parameters
---@param markov_table table table with markov config
---@param len number length of the generated sequence
---@param param_settings table table with the parameters settings
---@param keep_start boolean if true will keep the start of the original sequence
---@param pc_weight_settings table table with the pc weight settings. pc_weight_settings = {octavesize = i, w = 1,  w_values = {{val = pc, w = weidth},{val = pc, w = weidth} ...}}
---@param pitch_weight_settings any
---@param new_qn_pos_sequence any
---@return table
---@return any
function GenerateNewSequencePitch(original_sequence, t_markov, len, param_settings, keep_start, pc_weight_settings, pitch_weight_settings, new_qn_pos_sequence, pitch_settings)
    local start = GetStartSequence(keep_start, original_sequence,'pitch',param_settings)

    local nothing = '*'
    local separetor = ';'
    local order = param_settings.order
    local last_val = start
    -- If nothing is nil then fill last_val with nothing symbol order times.
    if not last_val or #last_val == 0 then 
        last_val = {}
        for i = 1, order do
            table.insert(last_val,nothing)
        end
    end
    -- Generate Sequence!!!
    local sequence = TableCopy(last_val)
    for i = 1, len do
        -- for weight tables
        local pc_weight_table, pitch_weight_table
        if pc_weight_settings then
            pc_weight_table = MakePCWeightTable(pc_weight_settings, new_qn_pos_sequence[i])
        end

        -- for intervals do the same as above an after convert all w_tables values from pitch and pc to intervals between the pitch/pc and last note pitch/pc  
        -------
        local result = ApplyMarkovWeighted(t_markov, last_val, true, pc_weight_table, pitch_weight_table)
        -- for sequences
        table.insert(sequence,result)
        table.subs(last_val, result)
    end

    --
    --local sequence, new_qn_pos_sequence =  GenerateMarkovSequenceMeasurePosWeighted(markov_table, len, param_settings.order, start_sequence, true, false, new_qn_pos_sequence, weight_table)
    return sequence, new_qn_pos_sequence
end

function MakePCWeightTable(pc_weight_settings,qn_pos)
    local mute_symbol = mute_symbol or 'M'
    qn_pos = ParameterStringToVals(MidiParametersSeparate((qn_pos))[1], mute_symbol)
    local weight_table
    if TableCheckValues(pc_weight_settings,'take') then
        if reaper.ValidatePtr2(0, pc_weight_settings.take, 'MediaItem_Take*') then

            weight_table = {w = pc_weight_settings.w, w_values = {}, type = 'specific'}
            
            local already_added_pc = {}
            local pc_item_notes = CreateNotesTable(false,false,true,{pc_weight_settings.take}) -- get notes from pos weight take 
            for note_idx, note_table in ipairs(pc_item_notes[1]) do -- iterate all note tables inside take table
                local pc = note_table.pitch%(pc_weight_settings.octave_size or 12)
                if (note_table.start_qn <= qn_pos) and( note_table.end_qn >= qn_pos) and not (already_added_pc[pc]) then -- qn_pos is in between this note. this note is a weight note, qn_pos is the note poisition receiving apply markov
                    local weight = VelocityToWeight(note_table.vel,pc_weight_settings)
                    for octave = 0, 11 do -- weight every octave of this pitch class\
                        local pitch = pc + (octave*(pc_weight_settings.octave_size or 12))
                        table.insert(weight_table.w_values, {val = pitch, w = weight})
                    end
                    already_added_pc[pc] = true
                end
            end

            if #weight_table.w_values == 0 then -- no notes at this position, no table
                weight_table = nil
            end
        
        else 
            pc_weight_settings = nil -- If the item is missing remove the table
        end
    end
    return weight_table 
end

function MakePitchWeightTable(pitch_weight_settings,qn_pos) -- Deprecated
    local mute_symbol = mute_symbol or 'M'
    qn_pos = ParameterStringToVals(qn_pos, mute_symbol)
    local weight_table
    if TableCheckValues(pitch_weight_settings,'take') then
        if reaper.ValidatePtr2(0, pitch_weight_settings.take, 'MediaItem_Take*') then

            weight_table = {w = pitch_weight_settings.w, w_values = {}, type = 'closest distance', max_distance = 127, linear = pitch_weight_settings.w  }
            
            local pc_item_notes = CreateNotesTable(false,false,true,{pitch_weight_settings.take}) -- get notes from pos weight take 
            for note_idx, note_table in ipairs(pc_item_notes[1]) do -- iterate all note tables inside take table
                if (note_table.start_qn <= qn_pos) and( note_table.end_qn >= qn_pos)  then -- qn_pos is in between this note. this note is a weight note, qn_pos is the note poisition receiving apply markov
                    local weight = VelocityToWeight(note_table.vel,pitch_weight_settings)
                    table.insert(weight_table.w_values, {val = note_table.pitch, w = weight})
                end
            end

            if #weight_table.w_values == 0 then -- no notes at this position, no table
                weight_table = nil
            end
        
        else 
            pitch_weight_settings = nil -- If the item is missing remove the table
        end
    end
    return weight_table 
end



--------
-- Interval
--------

---comment
---@param original_sequence table table with the original notes parameters
---@param markov_table table table with markov config
---@param len number length of the generated sequence
---@param param_settings table table with the parameters settings
---@param keep_start boolean if true will keep the start of the original sequence
---@param pc_weight_settings table table with the pc weight settings. pc_weight_settings = {octavesize = i, w = 1,  w_values = {{val = pc, w = weidth},{val = pc, w = weidth} ...}}
---@param pitch_weight_settings any
---@param new_qn_pos_sequence any
---@return table
---@return any
function GenerateNewSequenceInterval(original_sequence, t_markov, len, param_settings, keep_start, pc_weight_settings, pitch_weight_settings, new_qn_pos_sequence, pitch_settings)
    local start = GetStartSequence(keep_start, original_sequence,'interval',param_settings)

    local nothing = '*'
    local separetor = ';'
    local order = param_settings.order
    local last_val = start
    -- If nothing is nil then fill last_val with nothing symbol order times.
    if not last_val or #last_val == 0 then 
        last_val = {}
        for i = 1, order do
            table.insert(last_val,nothing)
        end
    end
    -- Generate Sequence!!!
    local sequence = TableCopy(last_val)
    for i = 1, len do
        -- for weight tables
        local pc_weight_table, pitch_weight_table
        if pc_weight_settings then
            pc_weight_table = MakePCWeightTable(pc_weight_settings, new_qn_pos_sequence[i])
            ConvertPCToIntervals(pc_weight_table, last_val, pitch_settings)
        end

        -- for intervals do the same as above an after convert all w_tables values from pitch and pc to intervals between the pitch/pc and last note pitch/pc  
        -------
        local result = ApplyMarkovWeighted(t_markov, last_val, true, pc_weight_table, pitch_weight_table)
        -- for sequences
        table.insert(sequence,result)
        table.subs(last_val, result)
    end

    --
    --local sequence, new_qn_pos_sequence =  GenerateMarkovSequenceMeasurePosWeighted(markov_table, len, param_settings.order, start_sequence, true, false, new_qn_pos_sequence, weight_table)
    return sequence, new_qn_pos_sequence
end

function ConvertPCToIntervals(pc_weight_table, last_val, pitch_settings)
    local mute_symbol = mute_symbol or 'M'
    if pc_weight_table then
        local last_pitch = last_val[#last_val]
        last_pitch = ParameterStringToVals(MidiParametersSeparate((last_pitch))[1], mute_symbol)
        if last_pitch then
            for j, w_table in ipairs(pc_weight_table.w_values) do
                w_table.val = w_table.val - last_pitch
            end
        end
    end    
end


------
-- General
------
-- Convert Velocity0-127 to Weight0-weight_settings.w
function VelocityToWeight(velocity,weight_settings)
    local weight
    if velocity < 64 then -- nerf chance
        weight = MapRange(velocity,0,64,0,1) -- from 0 to 1 
    else -- enchance chance
        weight = MapRange(velocity,64,127,1,weight_settings.w) -- from 0 to weight_settings.w . user set weight_settings.w. 
    end
    return weight
end

function GetStartSequence(keep_start, original_sequence, sequence_string, param_settings, mute_symbol)
    mute_symbol = mute_symbol or 'M' -- hardcoding
    local start_sequence = {}
    local new_qn_pos_sequence = {} -- Just used to weight the notes
    if keep_start then
        local lowest_idx = original_sequence[sequence_string][0] and 0 or 1
        for i = lowest_idx, param_settings.order do
            start_sequence[i] = original_sequence[sequence_string][i]
            -- change i for offset_count_qn, if lowest_idx = 0
            if lowest_idx == 0 then i = i + 1 end
            local pos_table = MidiParametersSeparate(original_sequence.pos_qn[i])
            local pos_table_number = ParameterStringToVals(pos_table[1], mute_symbol)
            new_qn_pos_sequence[i] = pos_table_number -- doesnt matter if is mute or not, just need the qn pos
        end
    else 
        local pos_table = MidiParametersSeparate(original_sequence.pos_qn[1])
        local pos_table_number = ParameterStringToVals(pos_table[1], mute_symbol)        
        new_qn_pos_sequence[1] = pos_table_number
    end    
    return start_sequence, new_qn_pos_sequence
end


----------
-- Link Unfinished. Very hard have to disamble the link calculate with the weights for the markov table, and then remake a weight table with the values and weights 
---------
function GenerateNewSequenceLinkWeight(original_sequence, markov_table, len, link_settings, keep_start, pos_weight_settings, pc_weight_settigs, pitch_weight_settings, vel_weight_settings, rhythm_settings, pitch_settings, vel_settings)
    local nothing = '*'
    local separetor = ';'

    local last_val, new_qn_pos_sequence = GetStartSequence(keep_start, original_sequence,'link',link_settings)

    -- Create Weight tables
    local pos_weight_table, measure_pos_weight_table
    if link_settings.rhythm and rhythm_settings.mode ~= 0 then -- make the weight tables if needed
        if rhythm_settings.mode == 1 then
            pos_weight_table = CreatePosWeight(pos_weight_settings)
        elseif  rhythm_settings.mode == 2 then
            measure_pos_weight_table = CreateMeasurePosWeight(pos_weight_settings)
        end
    end

    -- Get Start of original notes
    
    if not order then order = #t_markov end
    -- If nothing is nil then fill last_val with nothing symbol order times.
    if not last_val or #last_val == 0 then 
        last_val = {}
        for i = 1, order do
            table.insert(last_val,nothing)
        end
    end

    
    -- Generate Sequence!!!
    local sequence = TableCopy(last_val)
    for i = 1, len do
        --- if weight_table Convert QN pos to rhythms from last note
        -- markov_table is for interval between events (like rhythms or intervals) and weight_table.w_values[i].val have fixed values (like qn_position,pitch, pitchclasses ) this will calculate the interval between last value and weight_table.w_values[i].val and create another table . 
        local weight_table_converted = ConvertWeightList_QNtoRhythm(pos_weight_table,new_qn_pos_sequence)
        ---------------------------------------------------------------------------------------------------------------------
        --local result = ApplyMarkov(t_markov, last_val, true, false) -- old
        local result = ApplyMarkovWeighted(t_markov, last_val, true, weight_table_converted)
        -- for weight table
        local result_table = MidiParametersSeparate(result)
        table.insert(new_qn_pos_sequence, new_qn_pos_sequence[#new_qn_pos_sequence] + tonumber(result_table[1]))
        -- for sequence
        table.insert(sequence,result)
        table.subs(last_val, result)
        if break_on_nothing and result == nothing then break end
    end




    return new_link_sequence, new_qn_pos_sequence
end