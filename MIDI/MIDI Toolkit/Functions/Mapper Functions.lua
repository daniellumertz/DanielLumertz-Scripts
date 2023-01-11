--@noindex

---- Mapper

---Get elemets for the mapper table
---@param event_size number event size
---@param is_event number is event
---@param mapper_table table mapper_table[parameter_type][param_idx] = {new_value = '', old_value = '60&61&62'} or new_value after user changes
function GetParamsMapper(event_size,is_event)
    local original_notes = CreateNotesTable(true,false,true,take_list)
    local original_notes = EventTogether(original_notes,event_size,is_event)
    local param_list = CopyMIDIParametersFromEventList(original_notes, false,false,false,false, false, mute_mark) -- param_list[param name][event_idx] = {param1,param2,param3}
    -- If MapperSettings.is_pitch_class use just pitch class
    if MapperSettings.is_pitch_class then
        for event_idx, event_table in pairs(param_list.pitch) do
            local used_pc = {}
            for param_idx, parameter in pairs(event_table) do
                local pc = tostring(tonumber(parameter) % MapperSettings.octave_size)
                if not TableHaveValue(used_pc,pc) then
                    event_table[param_idx] = pc
                    table.insert(used_pc,pc)
                else
                    event_table[param_idx] = nil
                end
            end
        end
    end
    
    --  Get possible intervals
    local new_interval_list = {}
    for event_idx, event_table in pairs(param_list.interval) do
        for param_idx, interval in pairs(event_table) do
            new_interval_list[#new_interval_list+1] = {interval}
        end
    end 
    param_list.interval = new_interval_list

    -- Remove all parameters in between event for rhythm and measure pos
    local function delete_inevent_parameters(param_type)
        for event_idx, event_table in pairs(param_list[param_type]) do
            param_list[param_type][event_idx] = {[1] = event_table[1]}
        end
        param_list[param_type][0] = nil
    end
    delete_inevent_parameters('measure_pos_qn')
    delete_inevent_parameters('rhythm_qn')


    -- unify event parameters in just one string
    local stringfy_param_table = MidiTableParametersEventTogether(param_list) 
    -- create old_parameters_table that will be called mapper table -- for all parameters besides rhythm and intervals
    local old_parameters_table = {pitch = {}, rhythm_qn = {}, measure_pos_qn = {}, vel = {}, interval = {}}

    local function  sort_using_first_value(a,b)
        local first_val = tonumber((a.old_value):match('^-?[%d.]+'))
        local second_val = tonumber((b.old_value):match('^-?[%d.]+'))

        return first_val < second_val 
    end

    -- Get each parameter value only once
    for param_string, _ in pairs(old_parameters_table) do
        if not stringfy_param_table[param_string] then stringfy_param_table[param_string] = {} end

        local parameter_table = stringfy_param_table[param_string]
        for event_index, parameter in pairs(parameter_table) do
            local bol 
            --  check if already added the value
            for index, _ in ipairs(old_parameters_table[param_string]) do
                bol = old_parameters_table[param_string][index].old_value == parameter or bol
            end
            -- if not added then add
            if not bol and parameter ~= '' then
                local param_tab = {new_value = '', old_value = parameter}
                table.insert(old_parameters_table[param_string], param_tab)
            end
        end
        -- sort values
        table.sort(old_parameters_table[param_string], sort_using_first_value)
    end
    -- Quantize Rhythm and Measure pos
    if MapperSettings.is_quantize then
        local function quantize_tables(param)
            for index, map_table in ipairs(old_parameters_table[param]) do -- map_table = {old_value = '1.0&0.5', new_value = '' }
                local new_value = tostring(QuantizeNumber(tonumber(map_table.old_value),MapperSettings.quantize_step))
                -- comapre with all other values to check if it already have the same value
                for index_check, map_table_check in pairs(old_parameters_table[param]) do
                    if map_table_check ~= map_table and map_table_check.old_value == new_value then
                        old_parameters_table[param][index] = nil
                        goto continue
                    end
                end

                map_table.old_value = new_value
                ::continue::
            end
            TableRemoveSpaceKeys(old_parameters_table[param])
        end
        quantize_tables('rhythm_qn')
        quantize_tables('measure_pos_qn')
    end
    -- Get Melodic Intervals and make a table

    local mapper_table = {}
    mapper_table['Pitch'] = old_parameters_table['pitch'] 
    mapper_table['Interval'] = old_parameters_table['interval']
    mapper_table['Rhythm'] = old_parameters_table['rhythm_qn']
    mapper_table['Measure Pos'] = old_parameters_table['measure_pos_qn']
    mapper_table['Velocity'] = old_parameters_table['vel']
    return mapper_table
end

---Set the mapper parameters for selected notes
---@param event_size any
---@param is_event any
---@param mapper_table table mapper_table[parameter_type][param_idx] = {new_value = '65&61&62', old_value = '60&61&62'} or new_value after user changes
---@param param string parameter name
function SetParamsMapper(event_size,is_event,mapper_table,param)
    local user_sep = ';' -- separate by ;
    local internal_sep = '&' -- separate by &

    mapper_table = mapper_table[param] -- get the desired value
    local original_notes = CreateNotesTable(true,false,true,take_list)
    local original_notes = EventTogether(original_notes,event_size,is_event)
    local param_list = CopyMIDIParametersFromEventList(original_notes, false,false,false,false, false, mute_mark) -- param_list[param name][event_idx] = {param1,param2,param3}

    -- unify event parameters in just one string, need for comparrasion and change if match with mapper, then unify and apply.
    local stringfy_param_table = MidiTableParametersEventTogether(param_list) -- stringfy_param_table[param name][event_idx] = 60&65&69

    local convert_param_names = {Pitch = 'pitch', Interval = 'interval', Rhythm = 'rhythm_qn', ['Measure Pos'] = 'measure_pos_qn', Velocity = 'vel', ['M Interval'] = 'interval', ['H Interval'] = 'interval'}
    local stringfy_param_table = stringfy_param_table[convert_param_names[param]] -- stringfy_param_table[event_idx] = '60&65&69'
    -- check if new value normal values (not interval, rhythm) (both had different old_values)
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
            if MapperSettings.is_pitch_class and param == 'Pitch' then
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


        for event_idx, current_value in pairs(stringfy_param_table) do -- loop all selected events 
            if not current_value or current_value == '' then goto continue2 end
            -- apply the quantize/pitch class for the current value
            local new_value
            local match
            for _, mapper_value_tab in ipairs(mapper_table) do -- loop substitute tables in mapper_table
                if param == 'Rhythm' or param == 'Measure Pos' then
                    -- if quantize then apply it to the current value
                    current_value = current_value:match('[^'..internal_sep..']+')
                    if MapperSettings.is_quantize then
                        current_value = tostring(QuantizeNumber(tonumber(current_value),MapperSettings.quantize_step))
                    end

                    -- if is current parameter is equalt to the old parameter
                    if mapper_value_tab.new_value and mapper_value_tab.old_value == current_value and mapper_value_tab.new_value ~= '' then
                        -- process user string to a acceptable string
                        new_value = mapper_value_tab.new_value
                        OLD = mapper_value_tab.old_value:match('^([^'..internal_sep..']*)') -- get the first value
                        new_value = check_user_new_val(new_value)
                        if not new_value then goto continue end
                        stringfy_param_table[event_idx] = new_value

                        match = true
                        OLD = nil
                        ::continue:: -- not valid user input wont assign match and will keep the original values
                        break
                    end


                  
                elseif param == 'Interval' then 
                    local current_value = stringfy_param_table[event_idx] -- update the value . Need becaus it is looping [current event][new values][each interval]
                    local new_current_value = ''
                    for value in current_value:gmatch('[^'..internal_sep..']+') do -- Loop each interval (H and M)
                        local new_value
                        if mapper_value_tab.new_value and mapper_value_tab.old_value == value and mapper_value_tab.new_value ~= '' then
                            -- process user string to a acceptable string
                            new_value = mapper_value_tab.new_value
                            OLD = mapper_value_tab.old_value:match('^([^'..internal_sep..']*)') -- get the first value
                            new_value = check_user_new_val(new_value)
                            if not new_value then goto continue end
                            -- only integers intervals
                            for param_idx, parameter in ipairs(new_value) do
                                parameter = math.floor(tonumber(parameter)+0.5)
                                new_value[param_idx] = parameter
                            end

                            new_value = table.concat(new_value,internal_sep)


                            OLD = nil
                            ::continue:: -- not valid user input wont assign match and will keep the original values
                        end
                        new_current_value = new_current_value..(new_value or value)..internal_sep
                    end                                                    
                    new_current_value = new_current_value:sub(1,-2) -- remove last &
                    stringfy_param_table[event_idx] = new_current_value
                elseif param == 'M Interval' and event_idx >= 1 then 
                    current_value = stringfy_param_table[event_idx]:match('^([^'..internal_sep..']*)') -- rule out the harmonic interval
                    if mapper_value_tab.new_value and mapper_value_tab.old_value == current_value and mapper_value_tab.new_value ~= '' then -- the 
                        -- process user string to a acceptable string
                        new_value = mapper_value_tab.new_value
                        OLD = mapper_value_tab.old_value:match('^([^'..internal_sep..']*)') -- get the first value
                        new_value = check_user_new_val(new_value)
                        local h_idx
                        if not new_value then goto continue end
                        -- only integers intervals
                        for param_idx, parameter in ipairs(new_value) do
                            parameter = math.floor(tonumber(parameter)+0.5)
                            new_value[param_idx] = parameter
                        end
                        -- add the harmonic intervals
                        h_idx = 1
                        for h_interval in stringfy_param_table[event_idx]:gmatch('[^'..internal_sep..']+') do 
                            if h_idx > 1 then 
                                table.insert(new_value,h_interval) 
                            end
                            h_idx = h_idx + 1
                        end
                        -- add to the table
                        stringfy_param_table[event_idx] = new_value
                        
                        match = true
                        OLD = nil
                        ::continue:: -- not valid user input wont assign match and will keep the original values
                        break
                    end
                    
                elseif param == 'H Interval' then -- Loop all h intervals if any
                    if event_idx > 0 then
                        current_value = stringfy_param_table[event_idx]:match('.-'..internal_sep..'(.+)') -- rule out the melodic interval
                    end
                    if mapper_value_tab.new_value and mapper_value_tab.old_value == current_value and mapper_value_tab.new_value ~= '' then -- the 
                        -- process user string to a acceptable string
                        new_value = mapper_value_tab.new_value
                        OLD = mapper_value_tab.old_value:match('^([^'..internal_sep..']*)') -- get the first value
                        new_value = check_user_new_val(new_value)
                        if not new_value then goto continue end
                        -- only integers intervals
                        for param_idx, parameter in ipairs(new_value) do
                            parameter = math.floor(tonumber(parameter)+0.5)
                            new_value[param_idx] = parameter
                        end
                        if event_idx > 0 then
                            table.insert(new_value,1,stringfy_param_table[event_idx]:match('^([^'..internal_sep..']+)')) -- get the first value
                        end
                        stringfy_param_table[event_idx] = new_value

                        match = true
                        OLD = nil
                        ::continue:: -- not valid user input wont assign match and will keep the original values
                        break
                    end
                elseif param == 'Pitch' then
                    -- get current_value as a table (current_values_table), reducing the pitch classes. Add values as strings
                    local used_pc = {}
                    local current_notes_table = {} -- fixed pitch or PC non repeated
                    local current_notes_table_fixed = {} -- fixed pitch 
                    for value in current_value:gmatch('[^'..internal_sep..']+') do -- loop every value
                        local note = value
                        if MapperSettings.is_pitch_class then
                            note = tostring(tonumber(value) % MapperSettings.octave_size)
                        end

                        if not TableHaveValue(used_pc,note) then
                            table.insert(current_notes_table,note)
                            table.insert(used_pc,note)
                            table.insert(current_notes_table_fixed,tonumber(value))
                        end
                    end
                    -- get mapper_value_tab.old_value as a table. Values as strings
                    local used_pc = {}
                    local mapper_values_table = {}
                    for value in mapper_value_tab.old_value:gmatch('[^'..internal_sep..']+') do -- loop every value
                        local note = value
                        if MapperSettings.is_pitch_class then
                            note = tostring(tonumber(value) % MapperSettings.octave_size)
                        end

                        if not TableHaveValue(used_pc,note) then
                            table.insert(mapper_values_table,note)
                            table.insert(used_pc,note)
                        end
                    end
                    -- compare
                    local same_values = TableValuesCompareNoOrder(mapper_values_table,current_notes_table)  
                    
                    if mapper_value_tab.new_value and same_values and mapper_value_tab.new_value ~= '' then
                        -- process user string to a acceptable string
                        new_value = mapper_value_tab.new_value
                        OLD = mapper_value_tab.old_value:match('^([^'..internal_sep..']*)') -- get the first value
                        new_value = check_user_new_val(new_value) -- returns a table with all values the user inserted
                        if not new_value then goto continue end -- not acceptable user input.

                        if MapperSettings.is_pitch_class and param == 'Pitch' then
                            for index, value in ipairs(new_value) do
                                local octave_number = string.match(value, "[%-%d]+") 
                                if not octave_number then --add the closest value of the original note [index]
                                    local user_val = NoteToNumber(value)

                                    local original_note = current_notes_table_fixed[index] 
                                    if not original_note then -- if extra notes, get the closest pitch class
                                        local closest = math.huge
                                        for idx, fixed_old_note in ipairs(current_notes_table_fixed) do
                                            local dif = math.abs(fixed_old_note%MapperSettings.octave_size - user_val%MapperSettings.octave_size)
                                            if dif < closest then
                                                closest = dif
                                                original_note = fixed_old_note
                                            end
                                        end
                                    end
                                    value = GetClosestNote(original_note,user_val % MapperSettings.octave_size)
                                else
                                    value = NoteToNumber(value) or value -- if not a valid note name value should be a number
                                end

                                new_value[index] = value
                            end
                        end

                        stringfy_param_table[event_idx] = new_value
                        -- process parameters in the table
                        for param_idx, parameter in ipairs(stringfy_param_table[event_idx]) do
                            parameter = math.floor(tonumber(parameter)+0.5)
                            parameter = LimitNumber(parameter,0,127)
                            stringfy_param_table[event_idx][param_idx] = parameter
                        end
                        match = true
                        OLD = nil
                        ::continue:: -- not valid user input wont assign match and will keep the original values
                        break
                    end
                elseif param == 'Velocity' then
                    if mapper_value_tab.new_value and mapper_value_tab.old_value == current_value and mapper_value_tab.new_value ~= '' then
                        -- process user string to a acceptable string
                        new_value = mapper_value_tab.new_value
                        OLD = mapper_value_tab.old_value:match('^([^'..internal_sep..']*)') -- get the first value
                        new_value = check_user_new_val(new_value)
                        if not new_value then goto continue end
                        stringfy_param_table[event_idx] = new_value
                        -- process parameters in the table
                        for param_idx, parameter in ipairs(stringfy_param_table[event_idx]) do
                            parameter = math.floor(tonumber(parameter)+0.5)
                            parameter = LimitNumber(parameter,1,127)
                            stringfy_param_table[event_idx][param_idx] = parameter
                        end
                        match = true
                        OLD = nil
                        ::continue:: -- not valid user input wont assign match and will keep the original values
                        break
                    end
                end

            end
            if not match and stringfy_param_table[event_idx] ~= '' then -- did not found a valid match for this event, so keep the same value
                stringfy_param_table[event_idx] = MidiStringSeparateParameters(stringfy_param_table[event_idx]) 
            end
            ::continue2::
        end

    -- Set settings
    local pitch_sequence, pos_sequence,vel_sequence
    if param == 'Pitch' and #stringfy_param_table > 0 then
        pitch_sequence = {sequence = stringfy_param_table , type = 'pitch', complete = true,  use_mutesymbol = false}
    elseif (param == 'Interval' or param == 'M Interval' or param == 'H Interval') and #stringfy_param_table > 0 then
        pitch_sequence = {sequence = stringfy_param_table , type = 'interval', complete = true,  use_mutesymbol = false, loop = false }
    elseif param == 'Rhythm' and #stringfy_param_table  > 0 then
        pos_sequence = {sequence = stringfy_param_table , type = 'rhythm', delta = true, use_mutesymbol = false, unit = 'QN'}
    elseif param == 'Measure Pos' and #stringfy_param_table > 0 then
        pos_sequence = {sequence = stringfy_param_table , type = 'measure_pos', delta = true, use_mutesymbol = false, unit = 'QN'}
    elseif param == 'Velocity' and #stringfy_param_table > 0 then
        vel_sequence = {sequence = stringfy_param_table, use_mutesymbol = false}
    end
    

    ApplyParameterSequenceToNotesMultipleTakes(event_size,true,is_event,pitch_sequence,pos_sequence,vel_sequence,len_sequence,mute_sequence,channel_sequence,'M',false) 
    reaper.Undo_OnStateChange2(0, param..' Mapper on selected notes')   
end