--@noindex

---comment
---@param param strings pitch, interval, rhythm_qn, measure_pos_qn, vel
---@param is_left boolean permutate left? else right
---@param event_size boolean group events?
---@param is_event number event size
function Permutate(param,is_left,event_size,is_event)
    local original_notes = CreateNotesTable(true,false,true,take_list)
    local original_notes = EventTogether(original_notes,event_size,is_event)
    local param_list = CopyMIDIParametersFromEventList(original_notes, false,false,false,false, false, mute_mark)

    -- permutate
    local new_param_seq = TableDeepCopy(param_list[param])
    if is_left then
        for i = 1, #param_list[param] do
            new_param_seq[i] = param_list[param][((i) % #param_list[param])+1]
        end
    else
        for i = 1, #param_list[param] do
            new_param_seq[i] = param_list[param][((i - 2) % #param_list[param])+1]
        end
    end
    if #new_param_seq <= 0 then return end
    -- Set settings
    local pitch_sequence, pos_sequence,vel_sequence
    if param == 'pitch' then
        pitch_sequence = {sequence = new_param_seq, type = 'pitch', complete = true,  use_mutesymbol = false}
    elseif param == 'interval' then
        pitch_sequence = {sequence = new_param_seq, type = 'interval', complete = true,  use_mutesymbol = false, loop = false }
    elseif param == 'rhythm_qn' then
        pos_sequence = {sequence = new_param_seq, type = 'rhythm', delta = true, use_mutesymbol = false, unit = 'QN'}
    elseif param == 'measure_pos_qn' then
        pos_sequence = {sequence = new_param_seq, type = 'measure_pos', delta = true, use_mutesymbol = false, unit = 'QN'}
    elseif param == 'vel' then
        vel_sequence = {sequence = new_param_seq, use_mutesymbol = false}
    end

    ApplyParameterSequenceToNotesMultipleTakes(event_size,true,is_event,pitch_sequence,pos_sequence,vel_sequence,len_sequence,mute_sequence,channel_sequence,'M',false)

    local direction = is_left and 'left' or 'right' 
    reaper.Undo_OnStateChange2(0, ScriptName..' '..'Permutate selected notes '..direction)   
end

---comment
---@param param strings pitch, interval, rhythm_qn, measure_pos_qn, vel
---@param is_left boolean permutate left? else right
---@param event_size boolean group events?
---@param is_event number event size
function PermutateVertical(param,is_up,event_size,is_event)
    local original_notes = CreateNotesTable(true,false,true,take_list)
    local original_notes = EventTogether(original_notes,event_size,is_event)
    local param_list = CopyMIDIParametersFromEventList(original_notes, false,false,false,false, false, mute_mark)
    -- Make list of possible parameters
    local possible_param = {}
    for event_idx, event_table in ipairs(param_list[param]) do
        for param_idx, parameter in ipairs(event_table) do
            if not TableHaveValue(possible_param,tonumber(parameter)) then
                table.insert(possible_param,tonumber(parameter))
            end
        end
    end
    table.sort(possible_param)

    -- permutate
    local new_param_seq = TableDeepCopy(param_list[param])
    
    for event_idx, event_table in ipairs(param_list[param]) do
        if param == 'measure_pos_qn' or param == 'rhythm_qn' then -- just get the first value
            event_table = {param_list[param][event_idx][1]}
        end
        for parameter_idx, parameter in ipairs(event_table) do
            local retval, param_idx = TableHaveValue(possible_param, tonumber(parameter))
                
            if is_up then
                param_idx = ((param_idx)%#possible_param)+1
            else
                param_idx = ((param_idx-2)%#possible_param)+1
            end

            if not new_param_seq[event_idx]  then new_param_seq[event_idx] = {} end
            new_param_seq[event_idx][parameter_idx] = possible_param[param_idx]
        end
    end
    
    if #new_param_seq <= 0 then return end
    -- Set settings
    local pitch_sequence, pos_sequence,vel_sequence
    if param == 'pitch' then
        pitch_sequence = {sequence = new_param_seq, type = 'pitch', complete = true,  use_mutesymbol = false}
    elseif param == 'interval' then
        pitch_sequence = {sequence = new_param_seq, type = 'interval', complete = true,  use_mutesymbol = false, loop = false }
    elseif param == 'rhythm_qn' then
        pos_sequence = {sequence = new_param_seq, type = 'rhythm', delta = true, use_mutesymbol = false, unit = 'QN'}
    elseif param == 'measure_pos_qn' then
        pos_sequence = {sequence = new_param_seq, type = 'measure_pos', delta = true, use_mutesymbol = false, unit = 'QN'}
    elseif param == 'vel' then
        vel_sequence = {sequence = new_param_seq, use_mutesymbol = false}
    end

    ApplyParameterSequenceToNotesMultipleTakes(event_size,true,is_event,pitch_sequence,pos_sequence,vel_sequence,len_sequence,mute_sequence,channel_sequence,'M',false)

    local direction = is_up and 'up' or 'down' 
    reaper.Undo_OnStateChange2(0, ScriptName..' '..' Permutate selected notes '..direction)   
end

function GetParamsReorder(event_size,is_event,reorder_table)
    local original_notes = CreateNotesTable(true,false,true,take_list)
    local original_notes = EventTogether(original_notes,event_size,is_event)
    local param_list = CopyMIDIParametersFromEventList(original_notes, false,false,false,false, false, mute_mark)

    local stringfy_param_table = MidiTableParametersEventTogether(param_list)

    reorder_table['Pitch'] = stringfy_param_table['pitch'] 
    reorder_table['Interval'] = stringfy_param_table['interval']
    reorder_table['Rhythm'] = stringfy_param_table['rhythm_qn']
    reorder_table['Measure Pos'] = stringfy_param_table['measure_pos_qn']
    reorder_table['Velocity'] = stringfy_param_table['vel']
end

---Set The reorder_table to selected notes. param is which param to apply
---@param event_size any
---@param is_event any
---@param reorder_table any
---@param param any
function SetParamsReorder(event_size,is_event,reorder_table,param)
    local apply_table = MidiTableSeparateParameters(reorder_table)
    
    -- Set settings
    local pitch_sequence, pos_sequence,vel_sequence
    if param == 'Pitch' and #apply_table['Pitch'] > 0 then
        pitch_sequence = {sequence = apply_table['Pitch'], type = 'pitch', complete = true,  use_mutesymbol = false}
    elseif param == 'Interval' and #apply_table['Interval'] > 0 then
        pitch_sequence = {sequence = apply_table['Interval'], type = 'interval', complete = true,  use_mutesymbol = false, loop = false }
    elseif param == 'Rhythm' and #apply_table['Rhythm'] > 0 then
        pos_sequence = {sequence = apply_table['Rhythm'], type = 'rhythm', delta = true, use_mutesymbol = false, unit = 'QN'}
    elseif param == 'Measure Pos' and #apply_table['Measure Pos'] > 0 then
        pos_sequence = {sequence = apply_table['Measure Pos'], type = 'measure_pos', delta = true, use_mutesymbol = false, unit = 'QN'}
    elseif param == 'Velocity' and #apply_table['Velocity'] > 0 then
        vel_sequence = {sequence = apply_table['Velocity'], use_mutesymbol = false}
    end


    ApplyParameterSequenceToNotesMultipleTakes(event_size,true,is_event,pitch_sequence,pos_sequence,vel_sequence,len_sequence,mute_sequence,channel_sequence,'M',false)

    reaper.Undo_OnStateChange2(0, ScriptName..' '..param..' Reorder ')     
end

function RandomizeParamsReorder(reorder_table_parameter)
    local new_table = {}
    local options = TableDeepCopy(reorder_table_parameter)
    local events_count = #reorder_table_parameter
    for i = 1, events_count do
        local random_index = math.random(1,events_count-(events_count-#options))
        new_table[i] = options[random_index]
        table.remove(options,random_index)
    end
    return new_table
end

function ChangeParamReorder(user_input,i)
    local user_sep = ';'
    local internal_sep = '&' -- for iterpolating multiple values in a single string.

    local function check_user_new_val(user_input)
        local new_value = {}
        -- Loop each value in the string 
        for value in user_input:gmatch('[^'..user_sep..']+') do
            local value = value:gsub('%s+', '') -- remove spaces
            -- if pitch make it as a number
            --[[ if MapperSettings.is_pitch_class and param == 'Pitch' then
                value = NoteToNumber(value) or value -- if not a valid note name value should be a number
            end ]]
            
            -- Try to execute and see if it return a number
            local function error() end
            TempUserInput = ''
            local set_user_val, retval
            if SelectedParam == 'Pitch' and not tonumber(value) then -- User input using note names
                TempUserInput = value
                retval = true
            else
                set_user_val = load('TempUserInput = '..value) -- if user_input have math expression, it will be executed. or just get the number
                retval = xpcall(set_user_val,error)
            end
            if retval and TempUserInput then -- successful input (else return false)
                table.insert(new_value,TempUserInput)
            else
                return false
            end
            TempUserInput = nil -- removes this variable
        end

        return new_value
    end

    local new_value = check_user_new_val(user_input)
    if new_value then
        -- Convert all pitch notes names to numbers
        if SelectedParam == 'Pitch' then
            for key,value in ipairs(new_value) do
                if not tonumber(value) then
                    local note = NoteToNumber(value)
                    if note then
                        new_value[key] = note
                    else
                        return false
                    end
                end
            end
        end
        -- Table concat to stringfy it
        new_value = table.concat(new_value, internal_sep)
        -- add to the table
        ReorderTable[SelectedParam][i] = new_value
    else 
        return false
    end
end