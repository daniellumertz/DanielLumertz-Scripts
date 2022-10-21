--@noindex

--------------
---- Source
--------------

---Create a blank source table and add it to AllSources table.
---@param AllSources table table with all markov tables
---@return table markov_table blank markov table
---@return table AllSources table with all markov tables
function CreateSourceTable(AllSources)
    local markov_table = {}
    markov_table.name = 'New Source Table '..#AllSources+1
    table.insert(AllSources, markov_table)
    return markov_table, AllSources
end

--------------
---- Learn
--------------



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

-- the opposite of MidiTableParametersEventTogether
function MidiParametersSeparate(parameter_string)
    local internal_sep = '&' -- for iterpolating multiple values in a single string.

    local new_event_table = {}
    parameter_string  = parameter_string .. internal_sep
    for param_val in parameter_string:gmatch('(.-)' .. internal_sep) do -- iterate between value(internal_sep)
        table.insert(new_event_table, param_val)
    end
    return new_event_table
end

---add note sources to source_table. if combine_takes then will add one source to source_table combining all editable takes in one, else will add once per editable take.
---source_table structure: source_table[source i][event i][note_table i] =  {selected = is selected? , muted = is muted? , offset_count = note start in ppq, endppqpos = note end in ppq, chan = chan, pitch = pitch, vel = vel, start_time = proj start_time in sec}
---@param source_table table source table to add sources
---@param event_size number if is_event will put close notes in one event. if not is_event each note is one event
---@param is_event boolean put close notes in events
---@param combine_takes boolean if true sort all editable takes in one source. if false each editable take is a source.
function AddNoteSelectionToSourceTable(source_table, event_size, is_event, combine_takes)
    local takes_table = CreateNotesTable(true, false, combine_takes) -- is_selected,ignore_muted,is_combine_items
    -- Iterate all takes and put in source.
    for index, take_table in ipairs(takes_table) do
        take_table = EventTogether(takes_table, event_size, is_event)
        table.insert(source_table, take_table)
    end
end

function PrintChanceTable(SelectedSourceTable, pitch_settings, rhythm_settings, vel_setting,link_settings)
    reaper.ClearConsole()
    
    local mute_symbol = 'M'
    local nothing_symbol = '*'
    local separetor = ';'
    local internal_sep = '&' -- for iterpolating multiple values in a single string.
    local delete_note_symbol = '\1'
    local print_separator = ' + ' -- between values in a single event
    local print_separator_events = ' | ' -- between events

    -------------------------------------
    local markov_table = CreateMarkovTableFromSource(SelectedSourceTable, pitch_settings, rhythm_settings, vel_setting,link_settings, mute_symbol, nothing_symbol)

    for param_type, markov_param_table in pairs(markov_table) do
        if TableHaveAnything(markov_param_table) then 
            local chance_table = {} --- chance_table[last_val] = {next_val = chance}
            for last_value, possible_next_val in pairs(markov_param_table) do
                if last_value == '###source' then goto continue end
                local total_sum = 0
                local new_t = {}
                for index, next_val in pairs(possible_next_val) do
                    -- Transforms next_val from number to note string
                    if param_type == 'pitch' and next_val ~= nothing_symbol then 
                        local next_val_tab = MidiParametersSeparate(next_val)
                        next_val = ''
                        for index, val in ipairs(next_val_tab) do
                            val = tonumber(val)
                            if val then 
                                next_val = next_val..NumberToNote(val,true,not pitch_settings.drop)..internal_sep
                            end
                        end
                        next_val = next_val:sub(1,-2)
                    end
                    next_val = next_val:gsub(internal_sep, print_separator)
                    ---
                    if next_val == nothing_symbol then goto continue end
                    if new_t[next_val] then -- increase the value chance
                        new_t[next_val] = new_t[next_val] + 1
                    else -- add the value
                        new_t[next_val] = 1
                    end
                    total_sum = total_sum + 1
                    ::continue::
                end

                -- Transform table from count to percentages
                for next_val, count in pairs(new_t) do
                    new_t[next_val] = string.format("%.2f%%", tostring((count / total_sum)*100))
                end
                ------------
                -- Transforms next_val from number to note string

                if param_type == 'pitch' and last_value ~= nothing_symbol  then
                    local last_value_new = ''
                    for last_value in last_value:gmatch('[^'..separetor..']+') do -- iterate each order event
                        local last_val_tab = MidiParametersSeparate(last_value)
                        for index, val in ipairs(last_val_tab) do -- iterate pitch value
                            local number_val = tonumber(val)
                            if number_val then 
                                last_value_new = last_value_new..NumberToNote(number_val,true,not pitch_settings.drop)
                            else
                                last_value_new = last_value_new..val
                            end
                            last_value_new = last_value_new..internal_sep -- add internal separator between each event pitch value
                        end
                        last_value_new = last_value_new:sub(1,-2)-- remove last internal_sep
                        last_value_new = last_value_new..separetor -- add separator between each last order event 
                    end
                    last_value = last_value_new:sub(1,-2)
                end
                last_value = last_value:gsub(internal_sep, print_separator)
                last_value = last_value:gsub(separetor, print_separator_events)
                last_value = last_value:gsub(nothing_symbol, 'Start')


                ---
                
                chance_table[last_value] = new_t

                ::continue::
            end


            print('-------------------------')
            print('------------------  '..param_type)
            print('-------------------------')
            tprint(chance_table)
        end
    end    
end

function ReaperApplyMarkov(SelectedSourceTable, pitch_settings, rhythm_settings, vel_setting, link_settings, event_size, is_event, legato) --- inside each of the three settigs table

    local mute_symbol = 'M'
    local nothing_symbol = '*'
    local separetor = ';'
    local internal_sep = '&' -- for iterpolating multiple values in a single string.
    local delete_note_symbol = '\1'

    local is_selected = true

    -------------------------------------
    -- Learn the markov table from source
    -------------------------------------
    local markov_table = CreateMarkovTableFromSource(SelectedSourceTable, pitch_settings, rhythm_settings, vel_setting,link_settings, mute_symbol, nothing_symbol)

    ---------------------
    -- Get selected notes
    ---------------------
    local original_notes = CreateNotesTable(true, false, true) -- Always return 1 take table with the notes info, combining all editable takes.

    original_notes = EventTogether(original_notes, event_size, is_event)
    local original_sequence = EventListTableToMarkovTable(original_notes, mute_symbol, pitch_settings, rhythm_settings, vel_setting,link_settings, nothing_symbol)

    if #original_notes == 0 then
        reaper.ShowMessageBox('No notes selected!\nPlease Select Some Notes!', 'Error', 0)
        return
    end
    ------------------------
    -- Generate New Sequences
    -------------------------
    local new_pitch_sequence
    local new_interval_sequence -- redundant try to merge into pitch sequence
    local new_rhythm_sequence
    local new_measurepos_sequence -- redundant try to merge into rhythm sequence
    local new_vel_sequece

    local new_qn_pos_sequence -- for weight tables this is a table with all new positions
    --- count link settings
    local link_count = CountLinks(link_settings,pitch_settings,rhythm_settings,vel_setting)
    if link_count > 1 then -- Link
        new_pitch_sequence, new_rhythm_sequence, new_vel_sequece, new_qn_pos_sequence = GenerateNewLinkSequence(original_sequence,markov_table,link_settings,pitch_settings,rhythm_settings,vel_setting)
    end
    --Rhythm
    if rhythm_settings.mode == 1 and (not (link_count > 1 and link_settings.rhythm)) and #original_notes > 1 then -- Rhythm
        --new_rhythm_sequence = GenerateNewSequence(original_sequence.rhythm_qn, markov_table.rhythm, #original_sequence.rhythm_qn, rhythm_settings, rhythm_settings.keep_start)
        new_rhythm_sequence, new_qn_pos_sequence = GenerateNewSequenceRhythm(original_sequence, markov_table.rhythm, #original_sequence.rhythm_qn, rhythm_settings, rhythm_settings.keep_start, PosQNWeight, mute_symbol)
    elseif rhythm_settings.mode == 2 and (not (link_count > 1 and link_settings.rhythm)) then -- Measure position
        --new_measurepos_sequence = GenerateNewSequence(original_sequence.measure_pos_qn, markov_table.measure_pos, #original_sequence.measure_pos_qn, rhythm_settings, rhythm_settings.keep_start)
        new_rhythm_sequence, new_qn_pos_sequence = GenerateNewSequenceMeasurePos(original_sequence, markov_table.measure_pos, #original_sequence.measure_pos_qn, rhythm_settings, rhythm_settings.keep_start, PosQNWeight, mute_symbol)
    end

    if not new_qn_pos_sequence then new_qn_pos_sequence = original_sequence.pos_qn end
    -- Pitch
    if pitch_settings.mode == 1 and (not (link_count > 1 and link_settings.pitch)) then -- Pitch
        --new_pitch_sequence = GenerateNewSequence(original_sequence.pitch, markov_table.pitch, #original_sequence.pitch,pitch_settings, pitch_settings.keep_start)
        new_pitch_sequence = GenerateNewSequencePitch(original_sequence, markov_table.pitch, #original_sequence.pitch, pitch_settings, pitch_settings.keep_start, PCWeight, PitchWeight, new_qn_pos_sequence, pitch_settings)
    elseif pitch_settings.mode == 2 and (not (link_count > 1 and link_settings.pitch)) then -- Interval
        new_interval_sequence = GenerateNewSequence(original_sequence.interval, markov_table.interval,#original_sequence.interval, pitch_settings, pitch_settings.keep_start)
        --new_interval_sequence = GenerateNewSequenceInterval(original_sequence, markov_table.interval,#original_sequence.interval, pitch_settings, pitch_settings.keep_start, PCWeight, PitchWeight, new_qn_pos_sequence, pitch_settings)
    end
    -- Vel
    if vel_setting.mode == 1 and (not (link_count > 1 and link_settings.vel)) then -- Vel
        new_vel_sequece = GenerateNewSequence(original_sequence.vel, markov_table.vel, #original_sequence.vel,vel_setting, vel_setting.keep_start)
    end


    ----------------------
    -- Prepare sequences
    ----------------------

    -- In the new sequences remove nothing symbol from the start of sequence(if settings.keep_start is false).
    local all_sequences = { pitch = {settings = pitch_settings, sequence = new_pitch_sequence or new_interval_sequence},
                            rhythm = {settings = rhythm_settings, sequence = new_rhythm_sequence or new_measurepos_sequence},
                            vel  = {settings = vel_setting, sequence = new_vel_sequece}} -- just to batch process all sequences.

    
    local pitch_sequence, pos_sequence, vel_sequence  = PrepareNewSequencesToApply(all_sequences, mute_symbol, nothing_symbol, internal_sep)

    ----------------------
    -- Enhance Resolution
    ----------------------
    EnhanceResolution(pitch_sequence,pos_sequence,vel_sequence, pitch_settings, rhythm_settings, vel_setting, link_settings, original_notes, mute_symbol)
    ----------------------
    -- Apply sequences
    ----------------------
    ApplyParameterSequenceToNotesMultipleTakes(event_size, is_selected, is_event, pitch_sequence, pos_sequence, vel_sequence, len_sequence, mute_sequence, channel_sequence, mute_symbol, legato)

    reaper.Undo_OnStateChange2( 0, 'Script: Apply Markov to Selected Notes' )
end

---Prepare the new sequences to be applied at ApplyParameterSequenceToNotesMultipleTakes.
---@param all_sequences table contaning the other settings and sequences     local all_sequences = { pitch = {settings = pitch_settings, sequence = new_pitch_sequence or new_interval_sequence}, rhythm = {settings = rhythm_settings, sequence = new_rhythm_sequence or new_measurepos_sequence}, vel  = {settings = vel_setting, sequence = new_vel_sequece}} -- just to batch process all sequences.
---@param mute_symbol any
---@param nothing_symbol any
---@param internal_sep any
function PrepareNewSequencesToApply(all_sequences, mute_symbol, nothing_symbol, internal_sep)


    for param_type, param_table in pairs(all_sequences) do
        if param_table.sequence == nil then goto continue end
        local settings = param_table.settings
        local sequence = param_table.sequence
        -- remove blank [0]
        if sequence[0] == '' then sequence[0] = nil end
        -- remove nothing symbol added if the sequence dont keep start. (It adds nothing symbol to markov checks values that started sequences.) (It the markov order number of nothings symbols)
        while true do
            if sequence[1] == nothing_symbol then
                table.remove(sequence, 1)
            else
                break
            end
        end
        -- Break the glued event string, in a table. The opposite of MidiTableParametersEventTogether.
        for idx, parameter_string in pairs(sequence) do
            local new_event_table = MidiParametersSeparate(parameter_string)

            
            -- If parameter is only the mute symbol (for pitch and velocity) tehn make vel =1M and pitch = 1M, change all muted symbols for a muted value
            for k,value in pairs(new_event_table) do
                if value == mute_symbol then
                    if param_type == 'pitch' then
                        new_event_table[k] = '0'..mute_symbol
                    elseif param_type == 'vel' then
                        new_event_table[k] = '1'..mute_symbol
                    end
                end
            end
            sequence[idx] = new_event_table
        end
        ::continue::
    end

    ------ Add the settings to the sequence table.
    local pitch_sequence, pos_sequence, vel_sequence

    if TableCheckValues(all_sequences, 'pitch', 'sequence') then
        pitch_sequence = {
            type = (all_sequences.pitch.settings.mode == 1 and 'pitch') or 'interval',
            sequence = all_sequences.pitch.sequence,
            complete = true,
            use_mutesymbol = all_sequences.pitch.settings.use_muted and true
        }
    end

    if TableCheckValues(all_sequences, 'rhythm', 'sequence') then
        pos_sequence = {
            type = (all_sequences.rhythm.settings.mode == 1 and 'rhythm') or 'measure_pos',
            sequence = all_sequences.rhythm.sequence,
            use_mutesymbol = all_sequences.rhythm.settings.use_muted and true,
            delta = true,
            unit = 'QN'
        }
    end

    if TableCheckValues(all_sequences, 'vel', 'sequence') then
        vel_sequence = {
            sequence = all_sequences.vel.sequence,
            use_mutesymbol = all_sequences.vel.settings.use_muted and true
        }
    end

    --- If an sequence in empty then nil it.
    if pitch_sequence and #pitch_sequence.sequence == 0 then pitch_sequence = nil end
    if pos_sequence and #pos_sequence.sequence == 0 then pos_sequence = nil end
    if vel_sequence and #vel_sequence.sequence == 0 then vel_sequence = nil end
    -----
    return pitch_sequence, pos_sequence, vel_sequence    
end

---Take the SelectedSourceTable and Learn the Markov Table from it. 
---@param SelectedSourceTable table selected table with the sources
---@param pitch_settings table table with pitch settings
---@param rhythm_settings table table with rhythm settings
---@param vel_setting table table with velocity settings
---@param mute_symbol string the mute symbol
---@return table markov_table the markov table, used to generate new sequences.
function CreateMarkovTableFromSource(SelectedSourceTable, pitch_settings, rhythm_settings, vel_setting, link_settings, mute_symbol, nothing_symbol)
    -- Prepare the source table and create the table that Markov will use to learn.
    local parameters = {} -- table used to store the parameters to feed markov. each index is a take inside the source table. Inside each indexed table is .pitch .interval etc.
    -- parameters[source_idx].pitch = {60,64,67} etc. Parameters: pitch,vel,interval,rhythm,measure_pos,len
    for index, take_table in ipairs(SelectedSourceTable) do
        parameters[index] = EventListTableToMarkovTable(take_table, mute_symbol, pitch_settings, rhythm_settings,vel_setting,link_settings, nothing_symbol) -- already drop the resolution inside it 
    end

    -------- Link parameters 
    local link_counter = CountLinks(link_settings,pitch_settings,rhythm_settings,vel_setting)

    ----------------------------------------- Learn the parameters.
    -- Make this a function if use more than once!
    local markov_table = {}
    markov_table.pitch = {}
    markov_table.interval = {}
    markov_table.rhythm = {}
    markov_table.measure_pos = {}
    markov_table.vel = {}
    markov_table.link = {}
    

    for index, parameter_table in ipairs(parameters) do
        -- Pitch/ Interval
        if pitch_settings.mode == 1 then
            AddLearnMarkov(parameter_table.pitch, markov_table.pitch, pitch_settings.order)
        elseif pitch_settings.mode == 2 then
            AddLearnMarkov(parameter_table.interval, markov_table.interval, pitch_settings.order)
        end
        -- Rhythm/ measure pos
        if rhythm_settings.mode == 1 then
            AddLearnMarkov(parameter_table.rhythm_qn, markov_table.rhythm, rhythm_settings.order)
        elseif rhythm_settings.mode == 2 then
            AddLearnMarkov(parameter_table.measure_pos_qn, markov_table.measure_pos, rhythm_settings.order)
        end
        -- Vel
        if vel_setting.mode == 1 then
            AddLearnMarkov(parameter_table.vel, markov_table.vel, vel_setting.order)
        end

        if link_counter > 1 then
            GetHighestOrderFromLinked(pitch_settings, rhythm_settings,vel_setting,link_settings) -- Add the order to the link settings.
            AddLearnMarkov(parameter_table.link, markov_table.link, link_settings.order)
        end
    end

    return markov_table
end

function GetHighestOrderFromLinked(pitch_settings, rhythm_settings,vel_setting,link_settings)
    local highest_order = 0
    if link_settings.pitch == true and pitch_settings.mode ~= 0 then
        if pitch_settings.order > highest_order then
            highest_order = pitch_settings.order
        end
    end
    if link_settings.rhythm == true and rhythm_settings.mode ~= 0 then
        if rhythm_settings.order > highest_order then
            highest_order = rhythm_settings.order
        end
    end
    if link_settings.vel == true and vel_setting.mode ~= 0 then
        if vel_setting.order > highest_order then
            highest_order = vel_setting.order
        end
    end
    link_settings.order = highest_order
end

---Take a new_sequence table (works for pitch new_sequences and velocities new_sequences) and return a new_sequence table by take/event/notes_param using original_notes tables.
---@param original_notes any
---@param new_sequence any
---@param delete_note_symbol any
---@param is_delete boolean if true will add delete symbol to notes that dont have any more parameters . Ex event 3 is originally {C,D,E} and the new event value is {F,Bb} if true it will return {F,Bb,del}. If false it will loop around: {F,Bb,F}, my plans is is_delete = true to pitch and false to velocity
---@return table|unknown
function TakefyPitchVelocity(original_notes,new_sequence,delete_note_symbol,is_delete)
    local new_param_take 
    new_param_take = {}
    for evnt_idx, original_event_table in ipairs(original_notes) do
        local takes_in_this_event = {}
        local last_note_idx 
        for note_idx, original_note_table in ipairs(original_event_table) do -- for each of the original notes get a new value or delete value.
            -- just a nicer variable name 
            local take = original_note_table.take
            table.insert(takes_in_this_event, take)
            -- check if this take already have a table. if not create for every parameter a new table.
            if not new_param_take[take] then 
                new_param_take[take] = {}
            end
            if not new_param_take[take][evnt_idx] then -- if it isnt a table 
                new_param_take[take][evnt_idx] = {} -- Remember! it will insert at evnt_idx. this may create gaps in the table as a take can have notes in certain event and not in others. 
            end 
            -- add the value from new_sequence to new_param_take tables. Or add a delete note value
            if  #new_sequence[evnt_idx] >=  note_idx then -- there is some note to get at new_sequence[evnt_idx][note_idx]
                table.insert(new_param_take[take][evnt_idx], new_sequence[evnt_idx][note_idx])
            else -- there is no more note values to get, but it has more original notes in this event. DELETE THEM!
                if is_delete then
                    table.insert(new_param_take[take][evnt_idx], delete_note_symbol)
                else
                    local looped_note_idx = note_idx % #new_sequence[evnt_idx]
                    table.insert(new_param_take[take][evnt_idx], new_sequence[evnt_idx][looped_note_idx])
                end
            end
                last_note_idx = note_idx
        end
        -- check if used all parameters in the new_sequences. If there still values remaning add them looping available takes
        if last_note_idx < #new_sequence[evnt_idx] then
            local take_val = 1
            for i = last_note_idx+1, #new_sequence[evnt_idx] do
                local take = takes_in_this_event[take_val]
                take_val = (take_val + 1)%#takes_in_this_event -- loop around the takes
                table.insert(new_param_take[take][evnt_idx], new_sequence[evnt_idx][i])
            end
        end
    end
    return new_param_take  
end

---Generate the markov sequence using settings and start sequence.
---@param original_sequence table table contaning the settings of the current midi sequence. OPTIONAL
---@param markov_table table table contaning the markov table. to be used to generate the sequence
---@param len number number of how many new notes to generate
---@param param_settings table table contaning the user settings.
---@param keep_start boolean keep the start of the original_sequece? 
---@return table table contaning the generated new sequence.
function GenerateNewSequence(original_sequence, markov_table, len, param_settings, keep_start)
    local start_sequence = {}
    if keep_start then
        local lowest_idx = original_sequence[0] and 0 or 1
        for i = lowest_idx, param_settings.order do
            start_sequence[i] = original_sequence[i]
        end
    end
    return GenerateMarkovSequence(markov_table, len, param_settings.order, start_sequence, true, false)
end

function GenerateNewLinkSequence(original_sequence,markov_table,link_settings,pitch_settings,rhythm_settings,vel_setting,mute_symbol)
    local nothing = '*'


    local new_qn_pos_sequence = {}
    local new_pitch_sequence, new_rhythm_sequence, new_vel_sequece
    local new_link_sequence = GenerateNewSequence(original_sequence.link, markov_table.link, #original_sequence.link,link_settings, link_settings.keep_start)
    if link_settings.pitch then new_pitch_sequence = {} end
    if link_settings.rhythm then new_rhythm_sequence = {} end
    if link_settings.vel then new_vel_sequece = {} end

    -- for weight tables, add start qn values to new_qn_pos_sequence
    local last_val, last_measure_start 
    GetHighestOrderFromLinked(pitch_settings, rhythm_settings,vel_setting,link_settings) -- set link_settings.order to the highest order of the linked parameters
    if rhythm_settings then
        if link_settings.keep_start then
            for i = 1, link_settings.order do
                new_qn_pos_sequence[i] = MidiParametersSeparate(original_sequence.pos_qn[i])[1]
            end
        else 
            local pos_table = MidiParametersSeparate(original_sequence.pos_qn[1])[1]
            new_qn_pos_sequence[1] = pos_table
        end    
    end

    for index, new_val in ipairs(new_link_sequence) do
        if link_settings.pitch and pitch_settings.mode ~= 0 then
            new_pitch_sequence[#new_pitch_sequence+1] = new_val:match(link_settings.pitch_start..'(.-)'..link_settings.separator) -- already remove the nothing symbol
        end
        if link_settings.rhythm and rhythm_settings.mode ~= 0 then
            new_rhythm_sequence[#new_rhythm_sequence+1] = new_val:match(link_settings.rhythm_start..'(.-)'..link_settings.separator)  -- already remove the nothing symbol
            
            --- for weight tables, make new_qn_pos_sequence
            local new_val = new_rhythm_sequence[#new_rhythm_sequence]
            if new_val and  new_val ~= nothing then
                local new_val = ParameterStringToVals(MidiParametersSeparate(new_val)[1],mute_symbol) -- first note of the event rhythm
                if rhythm_settings.mode == 1 then -- tudo
                    local last_val = tonumber(new_qn_pos_sequence[#new_qn_pos_sequence])
                    if last_val then
                        local new_qn = last_val + new_val
                        new_qn_pos_sequence[#new_qn_pos_sequence+1] =  new_qn
                        last_val = new_qn
                    end                   

                elseif rhythm_settings.mode == 2 then
                    local retval, qnMeasureStart, qnMeasureEnd = reaper.TimeMap_QNToMeasures( 0, new_qn_pos_sequence[#new_qn_pos_sequence] )
                    if not last_val then
                        last_val = new_qn_pos_sequence[#new_qn_pos_sequence] - qnMeasureStart
                    end
                    if last_val and new_val <= last_val  then
                        new_qn_pos_sequence[#new_qn_pos_sequence+1] = qnMeasureEnd + new_val
                    else
                        new_qn_pos_sequence[#new_qn_pos_sequence+1] = qnMeasureStart + new_val
                    end
                    last_val = new_val 
                end
                
            end
            
        end
        if link_settings.vel and link_settings.mode ~= 0 then
            new_vel_sequece[#new_vel_sequece+1] = new_val:match(link_settings.vel_start..'(.-)'..link_settings.separator)  -- already remove the nothing symbol
        end
    end
    return new_pitch_sequence, new_rhythm_sequence, new_vel_sequece, new_qn_pos_sequence
end

--- Three Types of mute
--- Ignore Mute = 0 (remove the mute symbol)
--- Mute Type = 1 (dont change nothing)
--- One Mute = 2 (parameters marked with mute will be only a muted symbol)
function AddMuteSymbolToParameters(parameter_list, mute_type, mute_symbol)
    if mute_type == 1 then return end -- dont change anything
    if mute_type == 2 then -- all parameters with mute will only be the mute symbol
        for event_idx, event_list in pairs(parameter_list) do -- pairs because it also haves the 0 index for intervals and rhythms tables
            for param_idx, parameter_string in ipairs(event_list) do
                if type(parameter_string) ~= 'string' then parameter_string = tostring(parameter_string) end
                if parameter_string:match(mute_symbol .. "$") then
                    parameter_list[event_idx][param_idx] = mute_symbol
                end
            end
        end
    end

    if mute_type == 0 then -- remove mute symbol
        for event_idx, event_list in pairs(parameter_list) do -- pairs because it also haves the 0 index for intervals and rhythms tables
            for param_idx, parameter_string in ipairs(event_list) do
                if type(parameter_string) ~= 'string' then parameter_string = tostring(parameter_string) end
                if parameter_string:match(mute_symbol .. "$") then
                    parameter_list[event_idx][param_idx] = parameter_string:gsub(mute_symbol .. "$", "")
                end
            end
        end
    end
end

--- Process a table with events with notes parameteres to a sequence of strings to be used to learn Markov, and add the mute symbol if needed, group events as one string, and group velocities.
---@param take_table table table with events with notes parameters created in CreateNotesTable
---@param mute_symbol string mute symbol to be added to parameters from muted notes.
---@param pitch_settings table table contaning user settings for pitch
---@param rhythm_settings table table contaning user settings for rhythm
---@param vel_setting table table contaning user settings for velocities
---@return table new_table table with .pitch .rhythm .interval etc... events as strings to be used to learn Markov, or to get the start of a markov sequence.
function EventListTableToMarkovTable(take_table, mute_symbol, pitch_settings, rhythm_settings, vel_setting,link_settings, nothing_symbol)
    local new_table = CopyMIDIParametersFromEventList(take_table, true, true, true, true,true, mute_symbol)

    --- Drop Resolution
    DropResolution(pitch_settings,rhythm_settings,vel_setting,new_table,mute_symbol)

    -- process new_table table (put mute symbol, group vel TODO, put group events as one string )
    ------ Mute
    -- Only process the actives new_table.
    -- Pitch/ Interval
    if pitch_settings.mode == 1 then
        AddMuteSymbolToParameters(new_table.pitch, pitch_settings.use_muted, mute_symbol)
    elseif pitch_settings.mode == 2 then
        AddMuteSymbolToParameters(new_table.interval, pitch_settings.use_muted, mute_symbol)
    end
    -- Rhythm/ measure pos
    if rhythm_settings.mode == 1 then
        AddMuteSymbolToParameters(new_table.rhythm_qn, rhythm_settings.use_muted, mute_symbol)
    elseif rhythm_settings.mode == 2 then
        AddMuteSymbolToParameters(new_table.measure_pos_qn, rhythm_settings.use_muted, mute_symbol)
    end
    -- Vel
    if vel_setting.mode == 1 then
        AddMuteSymbolToParameters(new_table.vel, vel_setting.use_muted, mute_symbol)
    end
    ---------
    new_table = MidiTableParametersEventTogether(new_table)

    -------- Link parameters 
    local link_counter = CountLinks(link_settings,pitch_settings,rhythm_settings,vel_setting)

    if link_counter > 1 then 
        new_table.link = {}

        local function AddToParamLink(new_table, parameter_table, offset, paremeter_identifier, nothing_symbol) -- offset in necessary for rhythm and interval. Add it one index after, as it is in between notes (dont use the first note)
            local lowest_key = (parameter_table[0] and 0) or 1
            for param_idx = lowest_key, #parameter_table do -- Loop every parameter
                local param = parameter_table[param_idx]
                if param == '' then param = nothing_symbol end -- substitute for nothing symbol, importante for rhythm and interval that start in a different offset
                local link_param_string = new_table.link[param_idx+offset] or ''
                link_param_string = link_param_string .. paremeter_identifier .. param .. link_settings.separator
                new_table.link[param_idx+offset] = link_param_string
            end
        end

        -- Pitch/ Interval
        if link_settings.pitch then -- If link pitches 
            if pitch_settings.mode == 1  then
                AddToParamLink(new_table, new_table.pitch, 0, link_settings.pitch_start, nothing_symbol)
            elseif pitch_settings.mode == 2 then
                AddToParamLink(new_table, new_table.interval, 0, link_settings.pitch_start, nothing_symbol)
            end
        end
        -- Rhythm/ measure pos
        if link_settings.rhythm then
            if rhythm_settings.mode == 1 then
                AddToParamLink(new_table, new_table.rhythm_qn, 0, link_settings.rhythm_start, nothing_symbol)
            elseif rhythm_settings.mode == 2 then
                AddToParamLink(new_table, new_table.measure_pos_qn, 0, link_settings.rhythm_start, nothing_symbol)
            end
        end
        -- Vel
        if link_settings.vel then
            if vel_setting.mode == 1 then
                AddToParamLink(new_table, new_table.vel, 0, link_settings.vel_start, nothing_symbol)
            end
        end

        if pitch_settings.mode == 2 or rhythm_settings.mode == 1 then
            new_table.link[#new_table.link] = nil -- remove the last parameter if is using rhythms or interval. This is NEEDED, rhythms and intervals are in between notes, and they will have one value less. If I leave it would result in a parameter without interval or rhythm, and that would missalign the rest. 
        end
    end


    return new_table
end

function RecreateSourceTable(SelectedSourceTable)
    reaper.Undo_BeginBlock()
    local track = reaper.GetLastTouchedTrack()
    local time = reaper.GetCursorPosition()
    local pos_qn = reaper.TimeMap2_timeToQN(0, time)
    
    for index, event_list in ipairs(SelectedSourceTable) do
        CreateMIDIItemFromEventList(event_list, track, pos_qn)
    end
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Recreate Source Table", -1)
end

function CountLinks(link_settings,pitch_settings,rhythm_settings,vel_setting)
    local link_counter = 0 -- to count the parameters that are true
    for k,v in pairs(link_settings) do
        if k == 'pitch' or k == 'rhythm' or k == 'vel' then
            if k ==  'pitch' and pitch_settings.mode == 0 then goto continue end
            if k ==  'rhythm' and rhythm_settings.mode == 0 then goto continue end
            if k ==  'vel' and vel_setting.mode == 0 then goto continue end

            if v == true then
                link_counter = link_counter + 1 
            end
            ::continue::
        end
    end
    return link_counter
end