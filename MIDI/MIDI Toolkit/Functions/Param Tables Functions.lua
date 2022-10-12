--@noindex

---Put events in a single table value. EG. midi_table.pitch = {{10},{20,30,40}} will return new_table = {10,20&30&40} Everything turns into a string. midi_table.interval = {{1},{2,3,4}} = {1,2&3&4}. midi_table.groove wont result in anything (not needed for now!)
---@param parameters_table table table containing all parameters (.pitch .interval etc) inside it.
function MidiTableParametersEventTogether(parameters_table) -- Used for my markov
    local internal_sep = '&' -- for iterpolating multiple values in a single string.
    local new_table = {}

    for parameter_type, parameter_table in pairs(parameters_table) do
        new_table[parameter_type] = {}

        for event_n, event_table in pairs(parameter_table) do -- pairs as it can have a 0 index for rhythms and intervals.
            local new_value = ''
            for index, val in ipairs(event_table) do
                if new_value:len() > 0 then
                    new_value = new_value .. internal_sep
                end
                new_value = new_value .. val
            end
            new_table[parameter_type][event_n] = new_value
        end

    end
    return new_table
end

---Receives a parameters_table with all events parameters as strings together. This returns a new table with all events parameters separate as tables.
---@param parameters_table any
---@return table
function MidiTableSeparateParameters(parameters_table)
    local internal_sep = '&' -- for iterpolating multiple values in a single string.

    local new_table = {}
    for param_type, param_table in pairs(parameters_table) do
        new_table[param_type] = {}
        for event_idx, event_string in ipairs(param_table) do
            new_table[param_type][event_idx] = MidiStringSeparateParameters(event_string)
        end
    end

    return new_table
end

-- the opposite of MidiTableParametersEventTogether
function MidiStringSeparateParameters(parameter_string)
    local internal_sep = '&' -- for iterpolating multiple values in a single string.

    local new_event_table = {}

    parameter_string  = parameter_string .. internal_sep
    for param_val in parameter_string:gmatch('(.-)' .. internal_sep) do -- iterate between value(internal_sep)
        table.insert(new_event_table, param_val)
    end
    return new_event_table
end