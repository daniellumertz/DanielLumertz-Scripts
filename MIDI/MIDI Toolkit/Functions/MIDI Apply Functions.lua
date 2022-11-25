--@noindex
-- version 0.2.2
-- changelog
-- Fix note off velocities in 

---Generate a take and then Apply a sequence of parameters to the notes. If sequence is bigger than the notes selected it will loop around. Each parameter table is a table with tables for each event  that conatins and numbers or strings for the parameters , if as strings and use_mutesymbol the parameter can have a mute symbol at the end and  that will mute the note else will be nonmuted. If use_mutesymbol false then it wont change the mute flag using the mute symbol, it can change with the mute sequence tho. This function utilizes a simillar function named ApplyParameterSequenceToSelectedNotes. This function sort the notes by time and pitch bottom up bedore pasting, which is impossible with the same of ApplyParameterSequenceToSelectedNotes; 
---@param track Track The track to create the MIDI Item
---@param time number The time to create the MIDI Item. 
---@param number_of_events number The number of events.
---@param event_size number The size of the event in QN, optional.
---@param is_event boolean if true will group neraby notes as events (using event_size). If false each note is an event.
---@param pitch_sequence table table with the pitch sequence or interval sequence at "sequence" index and the "type" index to tell if it is pitch or intervals . Types are "pitch" and "interval" EX:  pitch_sequence = { type = "pitch" , sequence = {{60,64,67},{60,64,67},{60,64,67} } }. in this table can be also an "interpolate" key with a number from 0 to 1 inside that interpolate original value and  new_value. this table also have the key "complete" if true it will always add all notes of the event for each event, creating new notes if needed, if nil or false will just adjust the current notes to the pasted parameters. If type is interval it can use the key "loop" to true and if there is more original notes in the event it will loop around, instead of deleating them. Ex original notes : 60,64,67 sequecence with loop is {1,2} it will generate 60,62,64. Remember the first index in intervals are for between events. If loop is true and one event dont have values above 2 index it will delete the notes. Have a key 'use_mutesymbol' to use the mute symbol in the sequence, if the parameter have a mute symbol the note will be muted, if it dont have it will be unmutted, for intervals it will apply to the second note. If an event is empty it will delete the notes instead of changing pitch. 
---@param pos_sequence table table with the pos sequence or rhythm sequence or measure pos sequence at "sequence" index and the "type" index to tell differentiate. Types are "pos" , "rhythm" , "measure_pos" , "quantize" and "quantize_measure".  pos_sequence = { type = "pos" , sequence = {{0},{960,962,980},{1080,1100}}} or pos_sequence = { type = "measure_pos" , sequence = {{0},{960,962,980},{1080,1100},{3200M,0},{50},{1000},{20}}} in measure_pos it will start in the first bar with a selected note and each time the value gets lower than the previous used it will go to next bar.  in this table can be also an "interpolate" key with a number from 0 to 1 inside that interpolate original value and  new_value. type = 'quantize' and 'quantize_measure' will move the notes to closest position. They also have the mute_symbol and iterpolate options. Ex type = 'quantize' pos_sequence.sequence = {{0},{960},{1080,1100},{5000}}, for each note will check closest value, notes in the same event will continue through the table, if there is no more will move to the same place as the previous note. Ex: type = "quantize_measure" pos_sequence.sequecence = {{{0},{960},{1080,1100},{5000}}, {{520},{1000}}} will move each note to the closest measure position, each new measure from the first selected note it will use another table, structure = sequence[measure][event][param_idx] = idx. All types have the 'delta' idx, if true it will move notes inside a event together with the first (if the event dont have more position/rhythm values inside it), ex: moving a 3 notes event using the type "pos" and the sequence = {{960}} will move the first note to 960 and apply the same distance to the other notes, if it was false it would move all notes to 960. Have a key 'use_mutesymbol' to use the mute symbol in the sequence.All types have the 'unit' idx for setting the unit value in sequences, default is in ppq, but makes more sense to use unit = QN or unit = S for project quarter notes and project seconds.
---@param vel_sequence table table with the velocity sequence. EX:  vel_sequence = {"sequence" = {{100,100,100},{100,100,100},{100,100,100} }} or {"sequence" = {{{'100','100M','100'},{'100','100','100M'},{'100M','100','100'}}}}  in this table can be also an "interpolate" key with a number from 0 to 1 inside that interpolate original value and  new_value. Have a key 'use_mutesymbol' to use the mute symbol in the sequence.
---@param len_sequence table table with the length sequence in the "sequence" index, sequence is in ppq. EX:  len_sequence = {"sequence" = {{960,50,60},{960}}} or { {'960','50','60'},{'960M'}}. Have a key 'use_mutesymbol' to use the mute symbol in the sequence.
---@param mute_sequence table table with the mute sequence. Ex: mute_sequence = {"sequence" = {{true},{true, false, true}, {true, true}, {false, false}}} 
---@param channel_sequence table table with the channel sequence. Ex: channel_sequence = {"sequence" = {{1},{1, 2, 1}, {1, 1}, {2, 2}}}
---@param mute_symbol string mute symbol that will be added at the end of the parameter string and will be catched if use_mutesymbol = true. For rhythm and interval parameters (that are in between notes) it will mute the second note of the interval/rhythm. 
---@param legato boolean legato is boolean.
function CreateItemFromParameterSequence(track, time, number_of_events, event_size, is_event, pitch_sequence, pos_sequence, vel_sequence, len_sequence, mute_sequence, channel_sequence, mute_symbol,legato)

    -- Check if have all sequences, if not add some default values
    if not pitch_sequence then
        pitch_sequence = {type = "pitch", sequence = {{60}}}
    end

    if not pos_sequence then
        pitch_sequence = {type = "rhythm", sequence = {{1}}, unit = 'QN'}
    end

    if not vel_sequence then
        vel_sequence = {sequence = {{100}}}
    end

    if not len_sequence and not legato then
        legato = true 
    end

    -- Create MIDI Item
    local item = reaper.CreateNewMIDIItemInProj(track, time, time+1, false) -- will extend the item at the end so whatever the size now
    local take = reaper.GetActiveTake(item)
    local default_pitch = 60
    local default_flag = PackFlags(false,false)
    local default_vel = 100
    local default_distance = GetTakePPQ(take) * (event_size+1/16) -- the distance in PPQ between notes added need to be larger than the event_size, else when applying the sequence it will be one event
    local new_midi = {}
    local position = 0
    for i = 1, number_of_events do
        -- Note On
        local msg_on = PackMIDIMessage(9,1,default_pitch,default_vel)
        InsertMIDIUnsorted(new_midi, position, msg_on, default_flag)
        -- Add to position
        position = position + default_distance
        -- Note Off
        local msg_off = PackMIDIMessage(8,1,default_pitch,0)
        InsertMIDIUnsorted(new_midi, position, msg_off, default_flag)
    end
    local new_str = PackPackedMIDITable(new_midi)
    reaper.MIDI_SetAllEvts(take, new_str)
    reaper.MIDI_Sort(take) 
    -- Apply
    ApplyParameterSequenceToNotes(take, false, event_size, is_event, pitch_sequence, pos_sequence, vel_sequence, len_sequence, mute_sequence, channel_sequence, mute_symbol, legato) 
    -- Get length of the MIDI, extend item until last note
    local retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, notecnt-1 )
    local end_time = reaper.MIDI_GetProjTimeFromPPQPos(take, endppqpos)
    reaper.SetMediaItemInfo_Value(item, "D_LENGTH", end_time - time)
end


---Apply a sequence of parameters to the selected notes in multiple takes (notes sorted by position and bottom up). If sequence is bigger than the notes selected it will loop around. Each parameter table is a table with tables for each event  that conatins and numbers or strings for the parameters , if as strings and use_mutesymbol the parameter can have a mute symbol at the end and  that will mute the note else will be nonmuted. If use_mutesymbol false then it wont change the mute flag using the mute symbol, it can change with the mute sequence tho. This function utilizes a simillar function named ApplyParameterSequenceToSelectedNotes. This function sort the notes by time and pitch bottom up bedore pasting, which is impossible with the same of ApplyParameterSequenceToSelectedNotes; 
---@param event_size number The size of the event in QN, optional.
---@param is_selected boolean If true only selected notes will be pasted.
---@param is_event boolean if true will group neraby notes as events (using event_size). If false each note is an event.
---@param pitch_sequence table table with the pitch sequence or interval sequence at "sequence" index and the "type" index to tell if it is pitch or intervals . Types are "pitch" and "interval" EX:  pitch_sequence = { type = "pitch" , sequence = {{60,64,67},{60,64,67},{60,64,67} } }. in this table can be also an "interpolate" key with a number from 0 to 1 inside that interpolate original value and  new_value. this table also have the key "complete" if true it will always add all notes of the event for each event, creating new notes if needed, if nil or false will just adjust the current notes to the pasted parameters. If type is interval it can use the key "loop" to true and if there is more original notes in the event it will loop around, instead of deleating them. Ex original notes : 60,64,67 sequecence with loop is {1,2} it will generate 60,62,64. Remember the first index in intervals are for between events. If loop is true and one event dont have values above 2 index it will delete the notes. Have a key 'use_mutesymbol' to use the mute symbol in the sequence, if the parameter have a mute symbol the note will be muted, if it dont have it will be unmutted, for intervals it will apply to the second note. If an event is empty it will delete the notes instead of changing pitch
---@param pos_sequence table table with the pos sequence or rhythm sequence or measure pos sequence at "sequence" index and the "type" index to tell differentiate. Types are "pos" , "rhythm" , "measure_pos" , "quantize" and "quantize_measure".  pos_sequence = { type = "pos" , sequence = {{0},{960,962,980},{1080,1100}}} or pos_sequence = { type = "measure_pos" , sequence = {{0},{960,962,980},{1080,1100},{3200M,0},{50},{1000},{20}}} in measure_pos it will start in the first bar with a selected note and each time the value gets lower than the previous used it will go to next bar.  in this table can be also an "interpolate" key with a number from 0 to 1 inside that interpolate original value and  new_value. type = 'quantize' and 'quantize_measure' will move the notes to closest position. They also have the mute_symbol and iterpolate options. Ex type = 'quantize' pos_sequence.sequence = {{0},{960},{1080,1100},{5000}}, for each note will check closest value, notes in the same event will continue through the table, if there is no more will move to the same place as the previous note. Ex: type = "quantize_measure" pos_sequence.sequecence = {{{0},{960},{1080,1100},{5000}}, {{520},{1000}}} will move each note to the closest measure position, each new measure from the first selected note it will use another table, structure = sequence[measure][event][param_idx] = idx. All types have the 'delta' idx, if true it will move notes inside a event together with the first (if the event dont have more position/rhythm values inside it), ex: moving a 3 notes event using the type "pos" and the sequence = {{960}} will move the first note to 960 and apply the same distance to the other notes, if it was false it would move all notes to 960. Have a key 'use_mutesymbol' to use the mute symbol in the sequence.
---@param vel_sequence table table with the velocity sequence. EX:  vel_sequence = {"sequence" = {{100,100,100},{100,100,100},{100,100,100} }} or {"sequence" = {{{'100','100M','100'},{'100','100','100M'},{'100M','100','100'}}}}  in this table can be also an "interpolate" key with a number from 0 to 1 inside that interpolate original value and  new_value. Have a key 'use_mutesymbol' to use the mute symbol in the sequence.
---@param len_sequence table table with the length sequence in the "sequence" index, sequence is in ppq. EX:  len_sequence = {"sequence" = {{960,50,60},{960}}} or { {'960','50','60'},{'960M'}}. Have a key 'use_mutesymbol' to use the mute symbol in the sequence. All types have the 'unit' idx for setting the unit value in sequences, default is in ppq, but makes more sense to use unit = QN or unit = S for project quarter notes and project seconds.
---@param mute_sequence table table with the mute sequence. Ex: mute_sequence = {"sequence" = {{true},{true, false, true}, {true, true}, {false, false}}} 
---@param channel_sequence table table with the channel sequence. Ex: channel_sequence = {"sequence" = {{1},{1, 2, 1}, {1, 1}, {2, 2}}}
---@param mute_symbol string mute symbol that will be added at the end of the parameter string and will be catched if use_mutesymbol = true. For rhythm and interval parameters (that are in between notes) it will mute the second note of the interval/rhythm. 
---@param legato string If Legato == true then legato is done by take separated. if legato  == 'takes' then the legato is done combining all takes  
function ApplyParameterSequenceToNotesMultipleTakes(event_size, is_selected, is_event, pitch_sequence, pos_sequence, vel_sequence, len_sequence, mute_sequence, channel_sequence, mute_symbol,legato) 
    is_selected = (is_selected == nil and true) or is_selected
    if len_sequence then
        legato = nil
    end
    -- Get selected notes
    local original_sequence = CreateNotesTable(is_selected, false, true) -- Always return 1 take table with the notes info, combining all editable takes.
    original_sequence = EventTogether(original_sequence, event_size, is_event)

    ----------------------------------------------------------------------------------
    -- Calculate the new sequences per take. Looping the original notes and applying the sequences will return in sequences per take. Rhythm, measure_position, Intervals will result in pitch and pos tables. 
    local all_sequences_tables = { pitch = pitch_sequence, pos = pos_sequence, vel = vel_sequence, len = len_sequence, mute = mute_sequence, channel = channel_sequence } -- for batch processing
    local all_take_sequence = { } -- for batch processing

    -- Create tables for the take_param_sequence. 
    for param_type, sequence_table in pairs(all_sequences_tables) do
        all_take_sequence[param_type] = {}
    end

    -- Generate New Sequences per take. take_pitch_sequence[take][event_idx][note_idx] = pitch_parameter
    local take_pitch_sequence = all_take_sequence.pitch
    local take_pos_sequence = all_take_sequence.pos
    local take_vel_sequence = all_take_sequence.vel
    local take_len_sequence = all_take_sequence.len 
    local take_mute_sequence = all_take_sequence.mute
    local take_channel_sequence = all_take_sequence.channel
    if legato == 'take' then
        take_len_sequence = {}
    end
    
    local i_table = {pitch = 0, pos = 0, vel = 0, len = 0, mute = 0, channel = 0} -- To iterate over the tables
    local ii_table = {pitch = 0, pos = 0, vel = 0, len = 0, mute = 0, channel = 0}

    --local note_idx = -1 I cant count here the note idx, but the original notes have this info! DELETE THIS LINE
    local last_start -- time of last note originally,  time of start of last chord/event originally
    local last_new_event_start, last_new_pos -- new time of last note, new time of start of last event -- for calculating rhythms
    local last_new_event_start_qn, last_new_pos_qn -- new time of last note, new time of start of last event -- for calculating rhythms
    local last_new_event_start_sec, last_new_pos_sec -- new time of last note, new time of start of last event -- for calculating rhythms

    local last_new_pitch, last_new_event_pitch -- new pitch for last note, new pitch for first note of last event -- to set intervals
    local measure_start, last_measure_pos --  current measure start ppqpos . time of last measure position used
    local last_msg -- save the info of the last_msg, use this table to add remaining notes to complement pitch/interval parameters in a event if pitch_sequence.complete = true -- Structure is : {start = (new_pos or offset_count), pitch = (new_pitch or val1), vel = (new_vel or val2), len = (new_len or false), flags = (new_flags or flags)} , if not len or len == false then need to get the length using GetNote(note_idx)
    local last_take -- saves the last note take
    local first_event = true -- to know if is the first event, to be used in rhythm and interval calculations
    local is_looping = false -- to know if already added all intervals from inside an event and now is looping them. Importante to filter out the function "CompleteEvents" from generating more intervals.


    local last_delta -- saves the delta of the last note, to move notes without position values if delta == on 

    local last_mute_rhythm -- Last rhythm parameter was muted? boolean rhythm is a special case, as if the event dont have more values it will last event position or last event delta. It makes sense to also apply last event mute (if use_mutesymbol)
    local quantize_table -- table used to quantize the notes, for each new event it will catch the closest table inside the pos_sequence.sequence table. This is an event table
    
    local measure_n  -- reaper measure number
    local measure_seq_n = 1 -- measure sequence number, used in quantize_measure

    local new_table = {} -- new table 
    local wait_list = {}
    for original_event_idx, original_event in ipairs(original_sequence) do --- Iterate Events

        -- Raises i and set ii to 1
        for param_type, sequence_table in pairs(all_sequences_tables) do 
            i_table[param_type] = i_table[param_type] + 1
            i_table[param_type] = ((i_table[param_type]-1) % #sequence_table.sequence) + 1
            ii_table[param_type] = 1
        end
        -- Change i and ii if fisrt event for rhythm and interval
        if first_event then 
            if pos_sequence and  pos_sequence.type == 'rhythm' then -- Rhythm
                i_table.pos = 0
                if pos_sequence.sequence[0] then
                    ii_table.pos = 0 -- Need to be 0. They will increase to 1 at the next event note (if any) and  will catch the first event inside interval. If I didnt did that at the next event note it would be 2 (which is ok for events > 0) 
                end
            end

            if pitch_sequence and pitch_sequence.type == 'interval' then -- Interval
                i_table.pitch = 0
                if pitch_sequence.sequence[0] then
                    ii_table.pitch = 0
                end
            end
            first_event = false 
        end
        is_looping = false -- if all interval were added in the event, now is looping them 

        -- Set last paramers for rhythm and interval calculate from last event first note
        last_new_pos = last_new_event_start
        last_new_pos_qn = last_new_event_start_qn
        last_new_pos_sec = last_new_event_start_sec

        last_new_pitch = last_new_event_pitch

        for note_idx, original_note in ipairs(original_event) do -- Iterate Event Notes

            local is_new_event = note_idx == 1  -- Is this note the first in a event ? 

            ------------ Get Notes Values from original_sequence
            --[[ Original Note Structure: {selected = selected,
                                           muted = muted,
                                           offset_count = startppqpos,
                                           endppqpos = endppqpos, 
                                           chan = chan, 
                                           pitch = pitch, 
                                           vel = vel, 
                                           start_time = start_time, 
                                           start_qn = start_qn, 
                                           end_qn = end_qn, 
                                           measure_pos = measure_pos, 
                                           take = take}]]

            local take = original_note.take
            local selected, muted  = original_note.selected, original_note.muted
            local msg_ch,val1,val2 = original_note.chan, original_note.pitch, original_note.vel
            local offset_count = original_note.offset_count
            local offset_count_qn = original_note.start_qn
            local offset_count_sec = original_note.start_time


            -------------- Transpose PPQ between takes from all ppq related variables
            if pos_sequence and not pos_sequence.unit and last_take and last_take ~= take then -- only need to transpose PPQ values between takes
                -- time of last note originally,  time of start of last chord/event originally
                last_start = GetPPQPosFromTake1_FromPPQPosFromTake2(take, last_take, last_start)
                -- new time of last note, new time of start of last event -- for calculating rhythms
                last_new_event_start = GetPPQPosFromTake1_FromPPQPosFromTake2(take, last_take, last_new_event_start)
                last_new_pos = GetPPQPosFromTake1_FromPPQPosFromTake2(take, last_take, last_new_pos)
                --  current measure start ppqpos . time of last measure position used
                if measure_start then
                    measure_start = GetPPQPosFromTake1_FromPPQPosFromTake2(take, last_take, measure_start)
                end
                if last_measure_pos then
                    last_measure_pos = GetPPQPosFromTake1_FromPPQPosFromTake2(take, last_take, last_measure_pos)
                end
                if last_delta then
                    -- saves the delta of the last note, to move notes without position values if delta == on 
                    -- calculate the ratio playback between the takes and multiply the delta by this ratio
                    local ratio = reaper.GetMediaItemTakeInfo_Value(take, 'D_PLAYRATE') / reaper.GetMediaItemTakeInfo_Value(last_take, 'D_PLAYRATE')  
                    last_delta =  last_delta * ratio
                end
            end
            
            --------------- Raises ii
            if not is_new_event then -- this note continues a event/chord
                for param_type, sequence_table in pairs(all_sequences_tables) do -- Raises ii 
                    ii_table[param_type] = ii_table[param_type] + 1
                    if (param_type ~= 'pitch') and (param_type ~= 'pos')  then -- if param_type is NOT pitch/interval/rhythm. this because the pitch/interval dont loop around the event parameters. Instead they delete execive notes, this way it will keep increasing ii and if it catch no value it will delete it. If this event does not have more rhythms it will use 0 for the rhythm
                        ii_table[param_type] = ((ii_table[param_type]-1) % #sequence_table.sequence[i_table[param_type]]) + 1 -- only for pos, vel, length and mute
                    elseif (sequence_table.type == 'interval') and (sequence_table.loop == true) and sequence_table.sequence[i_table[param_type]] then -- if interval have loop idx it will loop the interval inside this event (from ii_table = 2 to #i_table)
                        is_looping = ii_table[param_type] + 1 > #sequence_table.sequence[i_table[param_type]] 
                        ii_table[param_type] = ((ii_table[param_type]-1) % #sequence_table.sequence[i_table[param_type]]) + 1 
                        ii_table[param_type] = LimitNumber(ii_table[param_type],((i_table.pitch == 0 and 1) or 2)) -- if is the first event it will get from 0 i idx and the intervals between the event notes start at idx 1. Opposite to other idx that the idx 1 is gor in between events intervals
                    end
                end
            end

            ------------------------ Calculate the new values for the note ------------------------------
            local new_pos


            local new_pitch -- to set last_new_pitch at the end
            local new_pitch_num
            if last_start then -- not first note. ----------- !!! Calculate rhythm and intervals if needed
                -- Intervals 
                if pitch_sequence and pitch_sequence.type == 'interval' then -- if is an interval sequence
                    if pitch_sequence.sequence[i_table.pitch] then 
                        local interval = pitch_sequence.sequence[i_table.pitch][ii_table.pitch]
                        if interval then -- If dont find dont add. Let the Apply take care. If I add/loop it here it will add extra notes with the last pitch
                            local is_mute 
                            interval, is_mute = ParameterStringToVals(interval,mute_symbol)
                            new_pitch = last_new_pitch + interval
                            new_pitch = LimitNumber(new_pitch,0,127)
                            if is_mute then
                                new_pitch = tostring(new_pitch) .. mute_symbol
                            end
                        end
                    end
                    if not take_pitch_sequence[take] then take_pitch_sequence[take] = {} end
                    if not take_pitch_sequence[take][original_event_idx] then take_pitch_sequence[take][original_event_idx] = {} end
                    table.insert(take_pitch_sequence[take][original_event_idx],new_pitch) -- It add pitches (transform a interval table in a pitch table.)
                    new_pitch_num = ParameterStringToVals(new_pitch,mute_symbol) -- just to leave the value as a number for saving in last_new_pitch
                end

                if pos_sequence and pos_sequence.type == 'rhythm' then
                    local rhythm = TableCheckValues(pos_sequence.sequence, i_table.pos, ii_table.pos) -- Tries to get the value or return nil . if not i_table.pos 
                    if not rhythm and not pos_sequence.delta then-- if ii_table.pos is bigger than the number of rhythms in the event. Use last delta
                        rhythm = 0
                    end
                    if rhythm then
                        local is_mute 
                        rhythm, is_mute = ParameterStringToVals(rhythm,mute_symbol)
                        ---- Calculate the rhythm, wont transpose to ppq, keep in original values.
                        new_pos = last_new_pos + rhythm
                        --------------------------
                        last_mute_rhythm = is_mute
                        if is_mute then
                            new_pos = tostring(new_pos) .. mute_symbol
                        end                
                    else -- delta is on and it didnt catch any rhythm so use last delta
                        if not pos_sequence.unit then
                            new_pos = offset_count + last_delta
                        elseif pos_sequence.unit == 'QN' then 
                            new_pos = offset_count_qn + last_delta
                        elseif pos_sequence.unit == 'S' then
                            new_pos = offset_count_sec + last_delta
                        end
                        
                        if last_mute_rhythm then
                            new_pos = tostring(new_pos) .. mute_symbol
                        end                         
                    end

                    if not take_pos_sequence[take] then take_pos_sequence[take] = {} end
                    if not take_pos_sequence[take][original_event_idx] then take_pos_sequence[take][original_event_idx] = {} end
                    table.insert(take_pos_sequence[take][original_event_idx],new_pos) -- It add the new postions (transform a rhythm table in a pos table.)
                    new_pos = ParameterStringToVals(new_pos,mute_symbol) -- just to leave the value as a number for saving in last_new_pos
                end
                                    
            else -- first note save measure start if pos_sequence.type == measure_pos
                if pos_sequence and pos_sequence.type == 'measure_pos'  then
                    if pos_sequence.unit == 'QN' then
                        local retval, qnMeasureStart, qnMeasureEnd = reaper.TimeMap_QNToMeasures( 0, offset_count_qn )
                        measure_start = qnMeasureStart
                    elseif pos_sequence.unit == 'S' then
                        local retval, qnMeasureStart, qnMeasureEnd = reaper.TimeMap_QNToMeasures( 0, offset_count_qn )
                        measure_start = reaper.TimeMap2_QNToTime( 0, qnMeasureStart ) -- qn to time
                    else -- ppq
                        measure_start =  reaper.MIDI_GetPPQPos_StartOfMeasure( take, offset_count )
                    end
                end

                if pitch_sequence and pitch_sequence.type == 'interval' then -- Insert the first pitch from the selected notes
                    if not take_pitch_sequence[take] then take_pitch_sequence[take] = {} end
                    if not take_pitch_sequence[take][original_event_idx] then take_pitch_sequence[take][original_event_idx] = {} end
                    table.insert(take_pitch_sequence[take][original_event_idx],val1) -- It add pitches (transform a interval table in a pitch table.)
                    new_pitch = val1 -- just to leave the value as a number for saving in last_new_pitch
                end

                if pos_sequence and pos_sequence.type == 'rhythm' then -- Insert the first note pos  from the selected notes
                    if not take_pos_sequence[take] then take_pos_sequence[take] = {} end
                    if not take_pos_sequence[take][original_event_idx] then take_pos_sequence[take][original_event_idx] = {} end
                    new_pos = (pos_sequence.unit == 'QN' and offset_count_qn) or (pos_sequence.unit == 'S' and offset_count_sec) or offset_count  -- insert offset_count depeding on the unit QN/SEC/PPQ
                    table.insert(take_pos_sequence[take][original_event_idx],new_pos) -- It add position of the first note 
                end  
            end

        
            ------!!! Calculate new pos, measure_pos, pitch, vel, mute, len if needed
            if pos_sequence and pos_sequence.type ~= 'rhythm' then
                -- get new_pos
                if pos_sequence.type == 'pos' then -- Pos
                    new_pos = TableCheckValues(pos_sequence.sequence, i_table.pos, ii_table.pos) -- Tries to get the value or return nil . if not i_table.pos 
                    local is_mute 
                    if not new_pos and not pos_sequence.delta then -- Need to add because it wont know when applying between takes, need to solve here. Use values of last note. 
                        new_pos = last_new_pos
                        is_mute = last_mute_rhythm
                    end
                    new_pos, is_mute = ParameterStringToVals(new_pos,mute_symbol)
                    last_mute_rhythm = is_mute 

                    if new_pos then
                        if is_mute then
                            new_pos = new_pos .. mute_symbol
                        end
                        if not take_pos_sequence[take] then take_pos_sequence[take] = {} end
                        if not take_pos_sequence[take][original_event_idx] then take_pos_sequence[take][original_event_idx] = {} end
                        table.insert(take_pos_sequence[take][original_event_idx],new_pos)
                        new_pos = ParameterStringToVals(new_pos,mute_symbol) -- just to leave the value as a number for saving in last_new_pos
                    end
                elseif pos_sequence.type == 'measure_pos' then   -- Measure Pos
                    local new_measure_pos = pos_sequence.sequence[i_table.pos][ii_table.pos]
                    local is_mute
                    if new_measure_pos then
                        new_measure_pos, is_mute = ParameterStringToVals(new_measure_pos,mute_symbol)
                        last_mute_rhythm = is_mute
                        -- if the new value is lower it will go to next bar
                        if last_measure_pos and ((new_measure_pos < last_measure_pos) or ((new_measure_pos == last_measure_pos) and is_new_event)) then -- go to next bar
                            if pos_sequence.unit == 'QN' then
                                local retval, qnMeasureStart, qnMeasureEnd = reaper.TimeMap_QNToMeasures( 0, measure_start )
                                measure_start = qnMeasureEnd
                            elseif pos_sequence.unit == 'S' then
                                local measure_start_qn =   reaper.TimeMap2_timeToQN( 0, measure_start ) -- time to qn 
                                local retval, qnMeasureStart, qnMeasureEnd = reaper.TimeMap_QNToMeasures( 0, measure_start_qn )
                                measure_start = reaper.TimeMap2_QNToTime( 0, qnMeasureEnd ) -- qn to time
                            else -- ppq
                                measure_start = reaper.MIDI_GetPPQPos_EndOfMeasure(take, measure_start+1) 
                            end
                        end
                        -- for next loop
                        last_measure_pos = new_measure_pos
                        -- get new_pos
                        new_pos = new_measure_pos + measure_start
                    elseif not pos_sequence.delta then  -- if there is no more value in this event put at the same position at the last note in this event. dont update the measure start
                        new_pos = last_new_pos
                        is_mute = last_mute_rhythm
                    end

                    if new_pos then
                        if is_mute then
                            new_pos = tostring(new_pos) .. mute_symbol
                        end
                        if not take_pos_sequence[take] then take_pos_sequence[take] = {} end
                        if not take_pos_sequence[take][original_event_idx] then take_pos_sequence[take][original_event_idx] = {} end
                        table.insert(take_pos_sequence[take][original_event_idx],new_pos)
                        new_pos = ParameterStringToVals(new_pos,mute_symbol) -- just to leave the value as a number for saving in last_new_pos
                    end


                elseif pos_sequence.type == 'quantize_measure' or pos_sequence.type == 'quantize' then
                    if not take_pos_sequence[take] then 
                        take_pos_sequence[take] = pos_sequence.sequence
                    end
                end

                if not( pos_sequence.type == 'quantize_measure' or pos_sequence.type == 'quantize') and not new_pos and pos_sequence.delta then -- delta is on move the same amount, dont iterpolate, as it is gettings already the value interpolated from last delta.
                    if not pos_sequence.unit then
                        new_pos = offset_count + last_delta
                    elseif pos_sequence.unit == 'QN' then 
                        new_pos = offset_count_qn + last_delta
                    elseif pos_sequence.unit == 'S' then
                        new_pos = offset_count_sec + last_delta
                    end

                    local is_mute = last_mute_rhythm
                    if is_mute then
                        new_pos = tostring(new_pos) .. mute_symbol
                    end
                    if not take_pos_sequence[take] then take_pos_sequence[take] = {} end
                    if not take_pos_sequence[take][original_event_idx] then take_pos_sequence[take][original_event_idx] = {} end
                    table.insert(take_pos_sequence[take][original_event_idx],new_pos)
                    new_pos = ParameterStringToVals(new_pos,mute_symbol) -- just to leave the value as a number for saving in last_new_pos
                end
            end

            -- local new_pitch called above
            if pitch_sequence and pitch_sequence.type == 'pitch' then -- Pitch
                new_pitch = pitch_sequence.sequence[i_table.pitch][ii_table.pitch]
                if new_pitch then -- if ii value run out it wont get any pitch. Do nothing with the table, if I added the complete chord would generate plus notes.
                    local is_mute 
                    new_pitch, is_mute = ParameterStringToVals(new_pitch,mute_symbol)
                    if is_mute then
                        new_pitch = tostring(new_pitch)..mute_symbol
                    end
                    new_pitch_num = ParameterStringToVals(new_pitch,mute_symbol) -- just to leave the value as a number for saving in last_new_pitch
                end
                if not take_pitch_sequence[take] then take_pitch_sequence[take] = {} end
                if not take_pitch_sequence[take][original_event_idx] then take_pitch_sequence[take][original_event_idx] = {} end
                table.insert(take_pitch_sequence[take][original_event_idx],new_pitch) -- if new_pitch = nil (when iitable goes above the event sequence values ) it wil insert a nil and delete the note
            end

            local new_vel
            if vel_sequence then -- Velocity
                new_vel = vel_sequence.sequence[i_table.vel][ii_table.vel]
                local is_mute 
                new_vel, is_mute = ParameterStringToVals(new_vel,mute_symbol)
                if is_mute then
                    new_vel = tostring(new_vel) .. mute_symbol
                end
                if not take_vel_sequence[take] then take_vel_sequence[take] = {} end
                if not take_vel_sequence[take][original_event_idx] then take_vel_sequence[take][original_event_idx] = {} end
                table.insert(take_vel_sequence[take][original_event_idx],new_vel)
            end
            
            local new_len
            if len_sequence then -- Length
                new_len = len_sequence.sequence[i_table.len][ii_table.len]
                local is_mute 
                new_len, is_mute = ParameterStringToVals(new_len,mute_symbol)
                if is_mute then
                    new_len = tostring(new_len) .. mute_symbol
                end
                if not take_len_sequence[take] then take_len_sequence[take] = {} end
                if not take_len_sequence[take][original_event_idx] then take_len_sequence[take][original_event_idx] = {} end
                table.insert(take_len_sequence[take][original_event_idx],new_len)
            end

            local new_chan -- 1 based
            if channel_sequence then -- Channel
                new_chan = channel_sequence.sequence[i_table.channel][ii_table.channel]
                local is_mute 
                new_chan, is_mute = ParameterStringToVals(new_chan,mute_symbol)
                new_chan = LimitNumber(new_chan,1,16)
                if is_mute then
                    new_chan = tostring(new_chan) .. mute_symbol
                end
                if not take_channel_sequence[take] then take_channel_sequence[take] = {} end
                if not take_channel_sequence[take][original_event_idx] then take_channel_sequence[take][original_event_idx] = {} end
                table.insert(take_channel_sequence[take][original_event_idx],new_chan)
            end
            
            local new_mute
            if mute_sequence then -- Mute
                new_mute = mute_sequence.sequence[i_table.mute][ii_table.mute]
                if not take_mute_sequence[take] then take_mute_sequence[take] = {} end
                if not take_mute_sequence[take][original_event_idx] then take_mute_sequence[take][original_event_idx] = {} end
                table.insert(take_mute_sequence[take][original_event_idx],new_mute)
            end

            -------------- Legato 
            if legato == 'take' then
                local position --  new note position in qn 
                if pos_sequence and not (TableCheckValues(pos_sequence,'unit') == 'QN') then
                    if TableCheckValues(pos_sequence,'unit') == 'S' then -- new pos in sec
                        position = reaper.TimeMap2_QNToTime(0, new_pos)
                    else -- new_pos in ppq
                        position = reaper.MIDI_GetProjQNFromPPQPos(take, new_pos)
                    end
                else  -- not new pos or new pos in qn
                    position = new_pos or offset_count_qn
                end
                

                if is_new_event then
                    if #wait_list >= 1 then
                        for index, wait_note in ipairs(wait_list) do
                            local len_val = position - wait_note.start_qn
                            if not take_len_sequence[wait_note.take] then take_len_sequence[wait_note.take] = {} end
                            if not take_len_sequence[wait_note.take][wait_note.original_event_idx] then take_len_sequence[wait_note.take][wait_note.original_event_idx] = {} end
                            table.insert(take_len_sequence[wait_note.take][wait_note.original_event_idx],len_val)
                        end
                        wait_list = {}
                    end 
                end

                if original_event_idx == #original_sequence then -- if last event then add current lenght
                    local len_val = original_note.end_qn - original_note.start_qn
                    if not take_len_sequence[original_note.take] then take_len_sequence[original_note.take] = {} end
                    if not take_len_sequence[original_note.take][original_event_idx] then take_len_sequence[original_note.take][original_event_idx] = {} end
                    table.insert(take_len_sequence[original_note.take][original_event_idx],len_val)
                else -- if not last event then add current time and idx for next event start use it
                    wait_list[#wait_list+1] = {take = take, start_qn = position or new_pos, original_event_idx = original_event_idx}
                end 
            end

            

            ----------------Set Variables for next selected note------------------------------------
            last_start = offset_count
            last_take = take
            -- for rhythm and interval
            if pos_sequence then
                if pos_sequence.unit == 'QN' then
                    last_new_pos = new_pos or offset_count_qn
                    last_delta = last_new_pos - offset_count_qn

                elseif pos_sequence.unit == 'S' then
                    last_new_pos = new_pos or offset_count_sec
                    last_delta = last_new_pos - offset_count_sec

                else -- no unit
                    last_new_pos = new_pos or offset_count -- complicated because new_pos is not always ppq, can be qn or sec
                    last_delta = last_new_pos - offset_count

                end
            end

            last_new_pitch = new_pitch_num or val1
            -- for pos/rhythms qwith delta option for times it didnt catch a new pos value. 
            if is_new_event then
                last_new_event_start = last_new_pos
                last_new_event_start_qn = last_new_pos_qn
                last_new_event_start_sec = last_new_pos_sec

                last_new_event_pitch = last_new_pitch
            end
        end
        ----- END EVENT 
        -- Complete notes for interval and pitch
        if pitch_sequence and pitch_sequence.complete and not is_looping and pitch_sequence.sequence[i_table.pitch] and ii_table.pitch < #pitch_sequence.sequence[i_table.pitch] then -- will use last_msg to insert new values, need the last_start to not catch the first run. last_msg = {note_idx , start , pitch , vel , len , flags} it will not contain len if the length wasnt changed, get with getnote
            for ii = ii_table.pitch+1, #pitch_sequence.sequence[i_table.pitch] do -- for each non added note
                -- calculate the new pitch to add
                local is_mute, loop_new_pitch
                if pitch_sequence.type == 'interval' then -- Interval
                    local loop_interval = pitch_sequence.sequence[i_table.pitch][ii]
                    loop_interval, is_mute = ParameterStringToVals(loop_interval,mute_symbol)
                    loop_new_pitch = last_new_pitch + loop_interval 
                else -- Pitch
                    loop_new_pitch = pitch_sequence.sequence[i_table.pitch][ii]
                    loop_new_pitch, is_mute = ParameterStringToVals(loop_new_pitch,mute_symbol)
                end
                loop_new_pitch = LimitNumber(loop_new_pitch,0,127)
                -- save for next loop
                last_new_pitch = loop_new_pitch

                if is_mute then
                    loop_new_pitch = tostring(loop_new_pitch)..mute_symbol
                end
                if not take_pitch_sequence[last_take] then take_pitch_sequence[last_take] = {} end
                if not take_pitch_sequence[last_take][original_event_idx] then take_pitch_sequence[last_take][original_event_idx] = {} end
                table.insert(take_pitch_sequence[last_take][original_event_idx],loop_new_pitch) -- It add pitches (transform a interval table in a pitch table.)
                
            end
        end
    end
    -- If legato take add the new len table to all_take_se

    --add settings keys to takes table
    local take_list = {} -- take list I will use to iterate the Apply latter. Structure take_list[take][param_type] = new parameter table with .sequence = sequence table with events, and other keys inside. param_type are 'pos', 'pitch', 'vel', 'len', 'channel', 'mute' 
    for param_type, sequence_take_table in pairs(all_take_sequence) do
        for take, sequence_table in pairs(sequence_take_table) do
            local param_take_table = {}
            --prepare the sequence key
            --remove blank keys in the takes table / i and ii
            sequence_table = TableRemoveSpaceKeys(sequence_table)
            for event_idx, event_table in ipairs(sequence_table) do
                sequence_table[event_idx] = TableRemoveSpaceKeys(event_table)
            end
            --put the new sequence in it
            param_take_table.sequence = sequence_table
            --put the settings in it
            for key, val in pairs(all_sequences_tables[param_type]) do
                if key == 'sequence' then goto continue end
                if key == 'type' then -- change the type value for interval, rhythm and measure_pos
                    if val == 'interval' then
                        val = 'pitch'
                    elseif val == 'rhythm' or val ==  'measure_pos' then
                        val = 'pos'
                    end
                end

                param_take_table[key] = val
                ::continue::
            end
            -- put it inside take list
            if not take_list[take] then take_list[take] = {} end
            take_list[take][param_type] = param_take_table
        end
    end 

    if legato == 'take' then 
        for take, len_sequence in pairs(take_len_sequence) do
            local sequence = TableRemoveSpaceKeys(len_sequence)
            if not take_list[take] then take_list[take] = {} end
            take_list[take].len = {sequence = sequence, unit = 'QN'}
        end
        legato = nil
    end  -- If legato was set to take, it created a pos table.

    for take, take_parameters_table in pairs(take_list) do
        ApplyParameterSequenceToNotes(take, is_selected, event_size, is_event, take_parameters_table.pitch, take_parameters_table.pos, take_parameters_table.vel, take_parameters_table.len, take_parameters_table.mute, take_parameters_table.channel, mute_symbol,legato,true)
    end
end

---Apply a sequence of parameters to the selected notes. If sequence is bigger than the notes selected it will loop around. Each parameter table is a table with tables for each event  that conatins and numbers or strings for the parameters , if as strings and use_mutesymbol the parameter can have a mute symbol at the end and  that will mute the note else will be nonmuted. If use_mutesymbol false then it wont change the mute flag using the mute symbol, it can change with the mute sequence tho.
---@param take MediaTake The take to apply.
---@param selected boolean If true it will only apply to selected notes, if false it will apply to all notes.
---@param event_size number The size of the event in QN.
---@param is_event boolean if true will group neraby notes as events (using event_size). If false each note is an event.
---@param pitch_sequence table table with the pitch sequence or interval sequence at "sequence" index and the "type" index to tell if it is pitch or intervals . Types are "pitch" and "interval" EX:  pitch_sequence = { type = "pitch" , sequence = {{60,64,67},{60,64,67},{60,64,67} } }. in this table can be also an "interpolate" key with a number from 0 to 1 inside that interpolate original value and  new_value. this table also have the key "complete" if true it will always add all notes of the event for each event, creating new notes if needed, if nil or false will just adjust the current notes to the pasted parameters. If type is interval it can use the key "loop" to true and if there is more original notes in the event it will loop around, instead of deleating them. Ex original notes : 60,64,67 sequecence with loop is {1,2} it will generate 60,62,64. Remember the first index in intervals are for between events. If loop is true and one event dont have values above 2 index it will delete the notes. Have a key 'use_mutesymbol' to use the mute symbol in the sequence, if the parameter have a mute symbol the note will be muted, if it dont have it will be unmutted, for intervals it will apply to the second note. If an event is empty it will delete the notes instead of changing pitch
---@param pos_sequence table table with the pos sequence or rhythm sequence or measure pos sequence at "sequence" index and the "type" index to tell differentiate. Types are "pos" , "rhythm" , "measure_pos" , "quantize" and "quantize_measure".  pos_sequence = { type = "pos" , sequence = {{0},{960,962,980},{1080,1100}}} or pos_sequence = { type = "measure_pos" , sequence = {{0},{960,962,980},{1080,1100},{3200M,0},{50},{1000},{20}}} in measure_pos it will start in the first bar with a selected note and each time the value gets lower than the previous used it will go to next bar.  in this table can be also an "interpolate" key with a number from 0 to 1 inside that interpolate original value and  new_value. type = 'quantize' and 'quantize_measure' will move the notes to closest position. They also have the mute_symbol and iterpolate options. Ex type = 'quantize' pos_sequence.sequence = {{0},{960},{1080,1100},{5000}}, for each note will check closest value, notes in the same event will continue through the table, if there is no more will move to the same place as the previous note. Ex: type = "quantize_measure" pos_sequence.sequecence = {{{0},{960},{1080,1100},{5000}}, {{520},{1000}}} will move each note to the closest measure position, each new measure from the first selected note it will use another table, structure = sequence[measure][event][param_idx] = idx. All types have the 'delta' idx, if true it will move notes inside a event together with the first (if the event dont have more position/rhythm values inside it), ex: moving a 3 notes event using the type "pos" and the sequence = {{960}} will move the first note to 960 and apply the same distance to the other notes, if it was false it would move all notes to 960. Have a key 'use_mutesymbol' to use the mute symbol in the sequence. All types have the 'unit' idx for setting the unit value in sequences, default is in ppq, but makes more sense to use unit = QN or unit = S for project quarter notes and project seconds.
---@param vel_sequence table table with the velocity sequence. EX:  vel_sequence = {"sequence" = {{100,100,100},{100,100,100},{100,100,100} }} or {"sequence" = {{{'100','100M','100'},{'100','100','100M'},{'100M','100','100'}}}}  in this table can be also an "interpolate" key with a number from 0 to 1 inside that interpolate original value and  new_value. Have a key 'use_mutesymbol' to use the mute symbol in the sequence.
---@param len_sequence table table with the length sequence in the "sequence" index, sequence is in ppq. EX:  len_sequence = {"sequence" = {{960,50,60},{960}}} or { {'960','50','60'},{'960M'}}. Have a key 'use_mutesymbol' to use the mute symbol in the sequence. All types have the 'unit' idx for setting the unit value in sequences, default is in ppq, but makes more sense to use unit = QN or unit = S for project quarter notes and project seconds.
---@param mute_sequence table table with the mute sequence. Ex: mute_sequence = {"sequence" = {{true},{true, false, true}, {true, true}, {false, false}}} 
---@param channel_sequence table table with the channel sequence. Ex: channel_sequence = {"sequence" = {{1},{1, 2, 1}, {1, 1}, {2, 2}}}
---@param mute_symbol string mute symbol that will be added at the end of the parameter string and will be catched if use_mutesymbol = true. For rhythm and interval parameters (that are in between notes) it will mute the second note of the interval/rhythm. 
---@param legato boolean if true and not pos_sequence then it will change notes off to start of next event
---@param sort_up boolean sort notes that happen at the same time bottom up at the start of the function. With SortNotes(take,bottomup,sort) 
function ApplyParameterSequenceToNotes(take, is_selected, event_size, is_event, pitch_sequence, pos_sequence, vel_sequence, len_sequence, mute_sequence, channel_sequence, mute_symbol, legato, sort_up) 
    is_selected = (is_selected == nil and true) or is_selected
    legato = not len_sequence and legato or false -- if len_sequence is true it will force legato be false.
    legato = not (pos_sequence and (pos_sequence.type == 'quantize' or pos_sequence.type == 'quantize_measure')) and legato or false -- if quantize is true it will force legato be false. Makes no sense to use in one loop as a lot of notes will move to the same place if you try to apply legato a bunch will have 0 len


    if sort_up then
        SortNotes(take,true,true) 
    end
    -- Functions
    local function CompleteEvents(pitch_sequence, last_start_qn, i_table_val, ii_table_val, last_msg, new_table, is_looping, offset_count, legato )
        if last_start_qn and pitch_sequence and pitch_sequence.complete and pitch_sequence.sequence[i_table_val] and ii_table_val < #pitch_sequence.sequence[i_table_val] and not is_looping then -- will use last_msg to insert new values, need the last_start to not catch the first run. last_msg = {note_idx , start , pitch , vel , len , flags} it will not contain len if the length wasnt changed, get with getnote
            local loop_msg_end
            if last_msg.len then
                loop_msg_end = last_msg.start + last_msg.len
            elseif legato then
                loop_msg_end = offset_count
            else
                local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, last_msg.note_idx)
                loop_msg_end = last_msg.start + (endppqpos - startppqpos) -- new start + original len. 
            end
            local loop_new_pitch = last_msg.pitch -- start whith last note pitch
            local is_mute_symbol
            for ii = ii_table_val+1, #pitch_sequence.sequence[i_table_val] do -- for each non added note
                -- calculate the new pitch to add
                if pitch_sequence.type == 'interval' then -- Interval
                    local loop_interval = pitch_sequence.sequence[i_table_val][ii]
                    loop_interval, is_mute_symbol = ParameterStringToVals(loop_interval,mute_symbol)
                    loop_new_pitch = loop_new_pitch + loop_interval 
                else -- Pitch
                    loop_new_pitch = pitch_sequence.sequence[i_table_val][ii]
                    loop_new_pitch, is_mute_symbol = ParameterStringToVals(loop_new_pitch,mute_symbol)
                end
                loop_new_pitch = LimitNumber(loop_new_pitch,0,127)

                local new_flags
                if pitch_sequence.use_mutesymbol and is_mute_symbol then -- set this note to mute if mute sequence got a mute, or some parameter had is_mute_symbol with use_mutesymbol true
                    new_flags = PackFlags(true,true)
                elseif pitch_sequence.use_mutesymbol and not is_mute_symbol then -- set this note to non muted. if no parameter had is_mute_symbol with use_mutesymbol true
                    new_flags = PackFlags(true,false)
                end
                local flags = new_flags or  last_msg.flags

                -- Pack/add note on message
                local new_midi_note = PackMIDIMessage(9, last_msg.msg_ch, loop_new_pitch, last_msg.vel)
                InsertMIDIUnsorted(new_table,last_msg.start,new_midi_note,flags)
                
                -- Pack/add note off message
                local new_midi_note_off = PackMIDIMessage(8, last_msg.msg_ch, loop_new_pitch, last_msg.vel)
                InsertMIDIUnsorted(new_table,loop_msg_end,new_midi_note_off,flags)
            end
        end
    end

    local function BinarySearchInQuantize(t,ppq) -- Quantize table =  {{50,100}, {150,200}} , look using first note event
        local floor = 1
        local ceil = #t
        local i = math.floor(ceil/2)
        -- Try to get in the edges after the max value and before the min value
        local first_val = ParameterStringToVals(t[1][1],mute_symbol)
        local last_val = ParameterStringToVals(t[#t][1],mute_symbol)

        if last_val <= ppq then return #t end -- check if it is after the last t value 
        if first_val > ppq then return 1 end --check if is before the first value. return 0 if it is
        -- Try to find in between values
        while floor <= ceil  do
            -- get value of t[i] and    t[i+1]
            local val = ParameterStringToVals(t[i][1],mute_symbol)
            local next_val = ParameterStringToVals(t[i+1][1],mute_symbol)

            -- check if is between t and t[i+1]

            if t[i+1] and val <= ppq and ppq <= next_val then
                if next_val - ppq <= ppq - val then
                    return i+1
                else
                    return i
                end
            end -- check if it is in between two values
    
            -- change the i (this is not the correct answer)
            if val > ppq then
                ceil = i
                i = ((i - floor) / 2) + floor
                i = math.floor(i)
            elseif val < ppq then
                floor = i
                i = ((ceil - i) / 2) + floor
                i = math.ceil(i)
            end
            -- Safe break
            if floor == ceil then return i end
        end
    end

    ---Transpose QN or S project values to ppq
    ---@param unit string 'QN' or 'S'
    ---@param val number QN value or S value
    ---@param tTickFromQN table table with the Tick from QN
    ---@param tTickFromTime table table with the Tick from S
    ---@return number ppq value
    local function TransposeToPPQ(unit,val,tTickFromQN,tTickFromTime)
        -- Transpose QN and Seconds to Ppq
        if unit == 'QN' then
            val = tTickFromQN[take][val] 
        end
        if unit == 'S' then
            val = tTickFromTime[take][val]                                 
        end
        val = math.floor(val+0.5)
        return val
    end

    ---Transpose QN or S project values to ppq
    ---@param unit string 'QN' or 'S'
    ---@param val number ppq value to get as qn or S
    ---@param tTickFromQN table table with the QN from tick
    ---@param tTickFromTime table table with the S from tick
    ---@return number ppq value
    local function TransposeToQN_Sec(unit,val,tQNFromTick,tTimeFromTick)
        -- Transpose QN and Seconds to Ppq
        if unit == 'QN' then
            val = tQNFromTick[take][val] 
        end
        if unit == 'S' then
            val = tTimeFromTick[take][val]                                 
        end
        return val
    end


    ---- Transpose Project QN/Sec position to PPQ if quantize
    if pos_sequence and (pos_sequence.unit == 'QN' or pos_sequence.unit == 'S') and pos_sequence.type == 'quantize' then -- TODO CHECK QUANTIZE
        for event_idx, event_table in ipairs(pos_sequence.sequence) do
            for param_idx, param in ipairs(event_table) do
                local param, is_mute = ParameterStringToVals(param,mute_symbol)
                if pos_sequence.unit == 'QN' then
                    param = math.floor(reaper.MIDI_GetPPQPosFromProjQN( take, param )+0.5)
                elseif pos_sequence.unit == 'S' then
                    param = math.floor(reaper.MIDI_GetPPQPosFromProjTime(take, param)+0.5)
                end
                if is_mute then
                    param = tostring(param) .. mute_symbol 
                end
                pos_sequence.sequence[event_idx][param_idx] = param
            end
        end
    end

    ---- Declare variables
    local tTimeFromTick, tTickFromTime = CreateTickTable()
    local tQNFromTick, tTickFromQN = CreateQNTable() 

    ---- Set variables for the mod notes table "mod_notes" (to pass information got on note on to adjust note offs and meta events)
    local mod_symbol = 'MOD'
    local delete_symbol =  'DEL'
    ----
    local all_sequences_tables = { pitch = pitch_sequence, pos = pos_sequence, vel = vel_sequence, len = len_sequence, mute = mute_sequence, channel = channel_sequence } -- for batch processing
    
    local i_table = {pitch = 0, pos = 0, vel = 0, len = 0, mute = 0, channel = 0} -- To iterate over the tables
    local ii_table = {pitch = 0, pos = 0, vel = 0, len = 0, mute = 0, channel = 0}

    local note_idx = -1
    local last_start -- time of last note originally,  time of start of last chord/event originally
    local last_start_qn -- last_start but in QN

    local last_new_event_start, last_new_pos -- new time of last note, new time of start of last event -- for calculating rhythms
    local last_new_event_start_qn, last_new_pos_qn -- for setting rhythm in QN
    local last_new_event_start_sec, last_new_pos_sec -- for setting rhythm in seconds

    local last_new_pitch, last_new_event_pitch -- new pitch for last note, new pitch for first note of last event -- to set intervals

    local measure_start, last_measure_pos --  current measure start ppqpos . time of last measure position used
    local measure_start_unit, last_measure_unit -- same as above but in QN or Sec

    --local measure_start_qn, last_measure_pos_qn --  current measure start qn . time of last measure position used
    --local measure_start_sec, last_measure_pos_sec --  current measure start sec . time of last measure position used

    local last_msg -- save the info of the last_msg, use this table to add remaining notes to complement pitch/interval parameters in a event if pitch_sequence.complete = true -- Structure is : {start = (new_pos or offset_count), pitch = (new_pitch or val1), vel = (new_vel or val2), len = (new_len or false), flags = (new_flags or flags)} , if not len or len == false then need to get the length using GetNote(note_idx)
    local first_event = true -- to know if is the first event, to be used in rhythm and interval calculations
    local is_looping = false -- to know if already added all intervals from inside an event and now is looping them. Importante to filter out the function "CompleteEvents" from generating more intervals.

    local last_delta -- saves the delta of the last note, to move notes without position values if delta == on 
    local last_mute_rhythm -- Last rhythm parameter was muted? boolean rhythm is a special case, as if the event dont have more values it will last event position or last event delta. It makes sense to also apply last event mute (if use_mutesymbol)
    local quantize_table -- table used to quantize the notes, for each new event it will catch the closest table inside the pos_sequence.sequence table. This is an event table
    
    local measure_n  -- reaper measure number
    local measure_seq_n = 1 -- measure sequence number, used in quantize_measure

    local new_table = {} -- new MIDI table 
    local mod_notes = {} -- notes that are modified, add here in the note on and use it for meta messages and noteoffs. delete after note off.
    local retval, MIDIstr = reaper.MIDI_GetAllEvts(take)

    local wait_list, notes_cnt, notes_cnt_off
    if legato then
        wait_list = {} -- list to add note offs info, for using legato
        notes_cnt_off = 0 -- count of notes off. to know when is the last one
        if is_selected then
            notes_cnt = CountSelectedNotes(take)
        else
            local retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
            notes_cnt = notecnt
        end
    end

    

    -------- Looop through all events
    for offset, offset_count, flags, midimsg, stringPos in IterateAllMIDI(MIDIstr,false) do
        --Unpacking messages 
        local selected, muted, curve_shape = UnpackFlags(flags)
        local msg_type,msg_ch,val1,val2,text,msg = UnpackMIDIMessage(midimsg)
        -- Note Idx counter
        if msg_type == 9 and val2 > 0 then
            note_idx = note_idx + 1
        end
        -- QN value
        local offset_count_qn = tQNFromTick[take][offset_count]

        local offset_count_sec
        
        if ( pos_sequence and pos_sequence.unit == 'S') or (len_sequence and len_sequence.unit == 'S') then -- Only if needed
            offset_count_sec = tTimeFromTick[take][offset_count]
        end
        
        -- Calculate and Change Values of selected notes
        local is_mute_symbol
        if (not is_selected) or (is_selected and selected) then
            ----------------------------------------------------------------------------------------------
            -------------------------------------------------------------------------------------- NOTE ON
            ----------------------------------------------------------------------------------------------
            if msg_type == 9 and val2 > 0 then -- if is a note on
                local is_new_event = (not is_event) or (not last_start_qn or last_start_qn < offset_count_qn-event_size)  -- this note starts a event/chord.
                --- Variables to use at Complete Events function if is_new_event and need to complete pitches at last event. Because of Legato I need to use CompleteEvents at the end of the note on section. else it wouldnt know the proper length if legato on
                local i_table_old,ii_table_old,is_looping_old
                if is_new_event then  
                    ----------------------------------------------------------------------------------
                    -------------------------------------------------------------------------- New Event
                    ----------------------------------------------------------------------------------
                    i_table_old,ii_table_old,is_looping_old = i_table.pitch,ii_table.pitch,is_looping -- to use at CompleteEvents at the end of the note on section

                    -- Raises i and set ii to 1
                    for param_type, sequence_table in pairs(all_sequences_tables) do 
                        i_table[param_type] = i_table[param_type] + 1
                        i_table[param_type] = ((i_table[param_type]-1) % #sequence_table.sequence) + 1
                        ii_table[param_type] = 1
                    end

                    -- Change i and ii if fisrt event for rhythm and interval
                    if first_event then 
                        if pos_sequence and  pos_sequence.type == 'rhythm' then -- Rhythm
                            i_table.pos = 0
                            if pos_sequence.sequence[0] then
                                ii_table.pos = 0
                            end
                        elseif pitch_sequence and pitch_sequence.type == 'interval'  then -- Interval
                            i_table.pitch = 0
                            if pitch_sequence.sequence[0] then
                                ii_table.pitch = 0
                            end
                        end
                        first_event = false 
                    end
                    is_looping = false

                    -- Set last paramers for rhythm and interval calculate from last event first note
                    last_new_pos = last_new_event_start
                    if pos_sequence then 
                        if pos_sequence.unit == 'QN' then
                            last_new_pos_qn = last_new_event_start_qn
                        elseif pos_sequence.unit == 'S' then
                            last_new_pos_sec = last_new_event_start_sec
                        end
                    end

                    last_new_pitch = last_new_event_pitch

                else -- this note continues a event/chord
                    ----------------------------------------------------------------------------------
                    -------------------------------------------------------------------- Continue Event
                    ----------------------------------------------------------------------------------
                    for param_type, sequence_table in pairs(all_sequences_tables) do -- Raises ii 
                        ii_table[param_type] = ii_table[param_type] + 1
                        if (param_type ~= 'pitch') and (param_type ~= 'pos')  then -- if param_type is NOT pitch/interval/rhythm. this because the pitch/interval dont loop around the event parameters. Instead they delete execive notes, this way it will keep increasing ii and if it catch no value it will delete it. If this event does not have more rhythms it will use 0 for the rhythm
                            ii_table[param_type] = ((ii_table[param_type]-1) % #sequence_table.sequence[i_table[param_type]]) + 1 -- only for pos, vel, length and mute
                        elseif (sequence_table.type == 'interval') and (sequence_table.loop == true) and sequence_table.sequence[i_table[param_type]] then -- if interval have loop idx it will loop the interval inside this event (from ii_table = 2 to #i_table)
                            is_looping = ii_table[param_type] + 1 > #sequence_table.sequence[i_table[param_type]] 
                            ii_table[param_type] = ((ii_table[param_type]-1) % #sequence_table.sequence[i_table[param_type]]) + 1 
                            ii_table[param_type] = LimitNumber(ii_table[param_type],((i_table.pitch == 0 and 1) or 2)) -- if is the first event it will get from 0 i idx and the intervals between the event notes start at idx 1. Opposite to other idx that the idx 1 is gor in between events intervals
                        end
                    end

                    if legato then
                        wait_list[#wait_list+1] = {ori_pitch = val1, ori_channel = msg_ch}
                    end
                end
                --------------------------------------------------------------------------------------------
                ------------------------ Calculate the new values for the note -----------------------------
                --------------------------------------------------------------------------------------------
                local new_pos
                local new_pos_qn
                local new_pos_sec

                local new_pitch
                if last_start_qn then -- not first note. ----------- !!! Calculate rhythm and intervals if needed
                    ----------------------------------------------------------------------------------------------
                    -------------------------------------------------------------------------- Calculate Intervals
                    ----------------------------------------------------------------------------------------------
                    -- Intervals 
                    if pitch_sequence and pitch_sequence.type == 'interval' then -- if is an interval sequence
                        local interval =( pitch_sequence.sequence[i_table.pitch] and pitch_sequence.sequence[i_table.pitch][ii_table.pitch]) or delete_symbol 
                        if interval and interval ~= delete_symbol then
                            local is_mute 
                            interval, is_mute = ParameterStringToVals(interval,mute_symbol)
                            if pitch_sequence.use_mutesymbol then
                                is_mute_symbol = is_mute_symbol or is_mute
                            end
                            new_pitch = last_new_pitch + interval
                            if pitch_sequence.interpolate then
                                new_pitch = math.floor(InterpolateBetween2(new_pitch,val1,pitch_sequence.interpolate)+0.5)
                            end
                            new_pitch = LimitNumber(new_pitch,0,127)
                        else -- if there is no more intervals for this event,delete original note
                            new_pitch = delete_symbol
                        end
                    end
                    ----------------------------------------------------------------------------------------------
                    -------------------------------------------------------------------------- Calculate Rhythms
                    ----------------------------------------------------------------------------------------------
                    if pos_sequence and pos_sequence.type == 'rhythm' then
                        local rhythm = TableCheckValues(pos_sequence.sequence, i_table.pos, ii_table.pos) -- Tries to get the value or return nil . if not i_table.pos 
                        if not rhythm and not pos_sequence.delta then-- if ii_table.pos is bigger than the number of rhythms in the event. Use last delta
                            rhythm = 0
                        end
                        if rhythm then
                            local is_mute 
                            rhythm, is_mute = ParameterStringToVals(rhythm,mute_symbol)
                            last_mute_rhythm = is_mute
                            if pos_sequence.use_mutesymbol then
                                is_mute_symbol = is_mute_symbol or is_mute
                            end
                            ---- Calculate new rhythm using different units
                            if not pos_sequence.unit then
                                new_pos = last_new_pos + rhythm
                            elseif pos_sequence.unit == 'QN' then 
                                new_pos_qn = rhythm + last_new_pos_qn
                                new_pos = TransposeToPPQ(pos_sequence.unit,new_pos_qn,tTickFromQN,tTickFromTime)
                            elseif pos_sequence.unit == 'S' then
                                new_pos_sec = rhythm + last_new_pos_sec
                                new_pos = TransposeToPPQ(pos_sequence.unit,new_pos_sec,tTickFromQN,tTickFromTime)
                            end
                            --------------------------
                            if pos_sequence.interpolate then
                                new_pos = math.floor(InterpolateBetween2(new_pos,offset_count,pos_sequence.interpolate)+0.5)
                            end                        
                        else -- delta is on and it didnt catch any rhythm use last delta ( I need to put here because last delta is already with interpolate, cant apply to it again)
                            new_pos = offset_count + last_delta 
                            if pos_sequence.use_mutesymbol then
                                is_mute_symbol = is_mute_symbol or last_mute_rhythm
                            end                         
                        end
                    end
                                        
                else -- first note save measure start if pos_sequence.type == measure_pos
                    --------------------------------------------------------------------
                    --------------------------------------------------------- First Note
                    --------------------------------------------------------------------
                    if pos_sequence and (pos_sequence.type == 'measure_pos' or pos_sequence.type == 'quantize_measure') then
                        measure_start =  reaper.MIDI_GetPPQPos_StartOfMeasure( take, offset_count )
                        measure_start_unit = TransposeToQN_Sec(pos_sequence.unit,measure_start,tQNFromTick,tTimeFromTick)
                        -- get reaper measure N // only usefull for quantize_measure
                        if pos_sequence.type == 'quantize_measure' then
                            measure_n = GetMeasureNumberFromPPQPos(take, measure_start)
                            quantize_table = 1  
                        end
                    end
                end

            
                ------!!! Calculate new pos, measure_pos, pitch, vel, mute, len if needed
                -- local new_pos callled above
                if pos_sequence and pos_sequence.type ~= 'rhythm' then
                    -- get new_pos
                    if pos_sequence.type == 'pos' then -- Pos
                        new_pos = pos_sequence.sequence[i_table.pos][ii_table.pos]
                        if new_pos then
                            local is_mute 
                            new_pos, is_mute = ParameterStringToVals(new_pos,mute_symbol)
                            -- Transpose QN and Seconds to Ppq
                            new_pos = TransposeToPPQ(pos_sequence.unit,new_pos,tTickFromQN,tTickFromTime)
                            -----------------------------------
                            last_mute_rhythm = is_mute
                            if pos_sequence.use_mutesymbol then
                                is_mute_symbol = is_mute_symbol or is_mute
                            end
                        elseif not pos_sequence.delta then  -- if there is no more value in this event put at the same position at the last note in this event. dont update the measure start
                            new_pos = last_new_pos
                            is_mute_symbol = is_mute_symbol or last_mute_rhythm 
                        end
                    elseif pos_sequence.type == 'measure_pos' then   -- Measure Pos
                        local new_measure_pos = pos_sequence.sequence[i_table.pos][ii_table.pos]
                        if new_measure_pos then
                            local is_mute 
                            new_measure_pos, is_mute = ParameterStringToVals(new_measure_pos,mute_symbol)
                            last_mute_rhythm = is_mute
                            if pos_sequence.use_mutesymbol then
                                is_mute_symbol = is_mute_symbol or is_mute
                            end
                            -- if the new value is lower it will go to next bar
                            if last_measure_pos and ((new_measure_pos < last_measure_pos) or ((new_measure_pos == last_measure_pos) and is_new_event)) then -- go to next bar
                                measure_start = reaper.MIDI_GetPPQPos_EndOfMeasure(take, measure_start+1)
                                measure_start_unit = TransposeToQN_Sec(pos_sequence.unit,measure_start,tQNFromTick,tTimeFromTick)
                            end
                            if new_measure_pos then
                                if pos_sequence.unit then
                                    new_pos = TransposeToPPQ(pos_sequence.unit,measure_start_unit + new_measure_pos,tTickFromQN,tTickFromTime)
                                else
                                    new_pos = measure_start + new_measure_pos
                                end
                                last_measure_pos = new_measure_pos
                            end
                        elseif not pos_sequence.delta then  -- if there is no more value in this event put at the same position at the last note in this event. dont update the measure start
                            new_pos = last_new_pos
                            if pos_sequence.use_mutesymbol then
                                is_mute_symbol = is_mute_symbol or last_mute_rhythm
                            end
                        end
                    elseif pos_sequence.type == 'quantize' then
                        if is_new_event then
                            quantize_table = pos_sequence.sequence[BinarySearchInQuantize(pos_sequence.sequence,offset_count)]
                        end
                        new_pos = quantize_table[ii_table.pos]
                        if new_pos then
                            local is_mute 
                            new_pos, is_mute = ParameterStringToVals(new_pos,mute_symbol)
                            last_mute_rhythm = is_mute
                            if pos_sequence.use_mutesymbol then
                                is_mute_symbol = is_mute_symbol or is_mute
                            end
                        elseif not pos_sequence.delta then -- if there is no more value in this event put at the same position at the last note in this event. dont update the measure start
                            new_pos = last_new_pos
                            if pos_sequence.use_mutesymbol then
                                is_mute_symbol = is_mute_symbol or last_mute_rhythm
                            end
                        end
                    elseif pos_sequence.type == 'quantize_measure' then
                        if is_new_event then
                            local new_measure_start = reaper.MIDI_GetPPQPos_StartOfMeasure(take, offset_count)
                            if measure_start ~= new_measure_start then --if the note is in a new measure calculate the new quantize table
                                local new_measure_n = GetMeasureNumberFromPPQPos(take, new_measure_start)
                                local measure_diff = new_measure_n - measure_n
                                measure_seq_n = (((measure_seq_n + measure_diff)-1) % #pos_sequence.sequence)+1 -- Loop around the sequence, that is filled with the measures tables {{event1,event2},{event4,event3},{etc}} each internal table is a new measure with the events table.
                                measure_start = new_measure_start
                                measure_start_unit = TransposeToQN_Sec(pos_sequence.unit,measure_start,tQNFromTick,tTimeFromTick)
                                measure_n = new_measure_n
                            end
                            local measure_quantize_table = pos_sequence.sequence[measure_seq_n] -- table with the events of the current measure. measure_quantize_table = {{960,968},{1250},{etc}} use this to search for nearst event start  value 
                            local measure_offset
                            if pos_sequence.unit then
                                measure_offset = (offset_count_sec or offset_count_qn) - measure_start_unit -- if is sec will use sec offset if is qn will use qn offset
                            else
                                measure_offset = offset_count - measure_start
                            end
                            quantize_table = measure_quantize_table[BinarySearchInQuantize(measure_quantize_table,measure_offset)] --event table 
                        end   
                        local new_measure_pos = quantize_table[ii_table.pos]
                        if new_measure_pos then
                            local is_mute 
                            new_measure_pos, is_mute = ParameterStringToVals(new_measure_pos,mute_symbol)
                            last_mute_rhythm = is_mute
                            if pos_sequence.use_mutesymbol then
                                is_mute_symbol = is_mute_symbol or is_mute
                            end
                        elseif not pos_sequence.delta then  -- if there is no more value in this event put at the same position at the last note in this event. dont update the measure start
                            new_measure_pos = last_measure_pos
                            if pos_sequence.use_mutesymbol then
                                is_mute_symbol = is_mute_symbol or last_mute_rhythm
                            end
                        end
                        if new_measure_pos then
                            new_pos = TransposeToPPQ(pos_sequence.unit,measure_start_unit + new_measure_pos,tTickFromQN,tTickFromTime) or measure_start + new_measure_pos
                            last_measure_pos = new_measure_pos
                        end
                    end

                    if not new_pos and pos_sequence.delta then -- delta is on move the same amount, dont iterpolate, as it is gettings already the value interpolated from last delta.
                        new_pos = offset_count + last_delta
                        if pos_sequence.use_mutesymbol then
                            is_mute_symbol = is_mute_symbol or last_mute_rhythm
                        end
                    elseif pos_sequence.interpolate then -- Iterpolate
                        new_pos = math.floor(InterpolateBetween2(new_pos,offset_count,pos_sequence.interpolate)+0.5)
                    end
                end

                -- local new_pitch called above
                if pitch_sequence and pitch_sequence.type == 'pitch' then -- Pitch
                    new_pitch = pitch_sequence.sequence[i_table.pitch][ii_table.pitch]
                    if new_pitch then
                        local is_mute 
                        new_pitch, is_mute = ParameterStringToVals(new_pitch,mute_symbol)
                        if pitch_sequence.use_mutesymbol then
                            is_mute_symbol = is_mute_symbol or is_mute
                        end
                        if pitch_sequence.interpolate then
                            new_pitch = math.floor(InterpolateBetween2(new_pitch,val1,pitch_sequence.interpolate)+0.5)
                        end
                        new_pitch = LimitNumber(new_pitch,0,127)
                    else
                        new_pitch = delete_symbol
                    end
                end
                local is_delete = new_pitch == delete_symbol --delete this note if true (only happen if there is no more pitch to be inserted in this event, and originally it got more notes than needed)

                local new_vel
                if vel_sequence then -- Velocity
                    new_vel = vel_sequence.sequence[i_table.vel][ii_table.vel]
                    local is_mute 
                    new_vel, is_mute = ParameterStringToVals(new_vel,mute_symbol)
                    if vel_sequence.use_mutesymbol then
                        is_mute_symbol = is_mute_symbol or is_mute
                    end

                    if vel_sequence.interpolate then
                        new_vel = math.floor(InterpolateBetween2(new_vel,val2,vel_sequence.interpolate)+0.5)
                    end
                    new_vel = LimitNumber(new_vel,1,127)
                end
                
                local new_len
                if len_sequence then -- Length
                    new_len = len_sequence.sequence[i_table.len][ii_table.len]
                    local is_mute 
                    new_len, is_mute = ParameterStringToVals(new_len,mute_symbol)
                    if len_sequence.use_mutesymbol then
                        is_mute_symbol = is_mute_symbol or is_mute
                    end
                    
                    --- new pos to the unit used in length sequence. new_pos is always in ppq
                    local  new_pos_unit
                    if new_pos then
                        if len_sequence.unit == 'S' then -- Transpose new_pos to the unit used in legth
                            new_pos_unit = tTimeFromTick[take][new_pos]
                        elseif len_sequence.unit == 'QN' then
                            new_pos_unit = tQNFromTick[take][new_pos]
                        end
                    end 

                    if len_sequence.unit and len_sequence.unit == 'QN' then
                        local cur_pos = new_pos_unit or offset_count_qn
                        local pos = tTickFromQN[take][cur_pos + new_len]
                        new_len = ((pos - tTickFromQN[take][cur_pos])+0.5 )//1 -- new len in ppq
                    elseif len_sequence.unit and len_sequence.unit == 'S' then
                        local cur_pos = new_pos_unit or offset_count_sec
                        local pos = tTickFromTime[take][cur_pos + new_len]
                        new_len = ((pos - tTickFromTime[take][cur_pos])+0.5)//1 -- new len in ppq
                    end

                    if len_sequence.interpolate then
                        local _, _, _, startppqpos, endppqpos, _, _, _ = reaper.MIDI_GetNote( take, note_idx )
                        local current_len = endppqpos - startppqpos
                        new_len = math.floor(InterpolateBetween2(new_len,current_len,len_sequence.interpolate)+0.5)
                    end
                end

                local new_chan -- 1 based
                if channel_sequence then -- Channel
                    new_chan = channel_sequence.sequence[i_table.channel][ii_table.channel]
                    local is_mute 
                    new_chan, is_mute = ParameterStringToVals(new_chan,mute_symbol)
                    new_chan = LimitNumber(new_chan,1,16)
                    if channel_sequence.use_mutesymbol then
                        is_mute_symbol = is_mute_symbol or is_mute
                    end
                end
                
                local new_mute
                if mute_sequence then -- Mute
                    new_mute = mute_sequence.sequence[i_table.mute][ii_table.mute]
                end
                
                local new_flags

                local any_is_mute_symbol = (pitch_sequence and pitch_sequence.use_mutesymbol) or (vel_sequence and vel_sequence.use_mutesymbol) or (len_sequence and len_sequence.use_mutesymbol) or (pos_sequence and pos_sequence.use_mutesymbol) or (channel_sequence and channel_sequence.use_mutesymbol)
                if new_mute or (any_is_mute_symbol and is_mute_symbol) then -- set this note to mute if mute sequence got a mute, or some parameter had is_mute_symbol with use_mutesymbol true
                    new_flags = PackFlags(selected,true)
                elseif (any_is_mute_symbol and not is_mute_symbol) or new_mute == false then -- set this note to non muted. if no parameter had is_mute_symbol with use_mutesymbol true
                    new_flags = PackFlags(selected,false)
                end

                --------------------------Add to Modded notes---------------------------------------------
                local table_type = is_delete and delete_symbol or mod_symbol

                mod_notes[#mod_notes+1] = { type = table_type, 
                                            ori_pitch = val1,
                                            ori_channel = msg_ch,
                                            ori_offset_count = offset_count,
                                            new_pitch = new_pitch or val1,
                                            new_channel = new_chan or msg_ch,
                                            new_vel = new_vel or val2,
                                            new_flags = new_flags or flags,
                                            new_len = new_len,
                                            new_pos = new_pos or offset_count}


                --------------- If Legato and is event : Set Notes Off to the MIDI Table
                if is_new_event then
                    -- if needed add remaining notes to complement pitch/interval parameters in last event.
                    CompleteEvents(pitch_sequence, last_start_qn, i_table_old, ii_table_old, last_msg, new_table,is_looping_old, ( new_pos or offset_count), legato)
                    
                    if legato then 
                        for i = #wait_list, 1, -1 do -- add note offs to new table
                            local wait_note = wait_list[i]
                            if wait_note.val2 then
                                local off_msg = PackMIDIMessage(8,wait_note.new_channel,wait_note.new_pitch,wait_note.val2)
                                SetMIDIUnsorted(new_table,( new_pos or offset_count) , wait_note.ori_offset_count, off_msg, wait_note.flags )
                                table.remove(wait_list,i)
                            else
                                if not wait_note.legato_pos then 
                                    wait_note.legato_pos = (new_pos or offset_count)
                                end 
                            end
                        end
                        -- add current note
                        wait_list[#wait_list+1] = {ori_pitch = val1, ori_channel = msg_ch}
                    end
                end
                --------------------Set at new MIDI table----------------------------------------------- 
                local new_msg
                if is_delete then
                    new_msg = ''
                else
                    new_msg = PackMIDIMessage(msg_type,(new_chan or msg_ch),(new_pitch or val1),(new_vel or val2))
                end
                SetMIDIUnsorted(new_table,(new_pos or offset_count),offset_count,new_msg,(new_flags or flags))




                ----------------Set Variables for next selected note------------------------------------
                last_msg = {note_idx = note_idx, start = (new_pos or offset_count), pitch = (new_pitch or val1), vel = (new_vel or val2), len = (new_len or false), flags = (new_flags or flags), msg_ch = msg_ch}
                last_start = offset_count
                last_start_qn = offset_count_qn
                -- for rhythm and interval
                last_new_pos = new_pos or offset_count
                last_new_pos_qn = new_pos_qn or offset_count_qn
                last_new_pos_sec = new_pos_sec or offset_count_sec

                last_new_pitch = new_pitch or val1
                -- for pos/rhythms with delta option for times it didnt catch a new pos value. 
                last_delta = last_new_pos - offset_count
                if is_new_event then
                    last_new_event_start = last_new_pos
                    last_new_event_start_qn = last_new_pos_qn
                    last_new_event_start_sec = last_new_pos_sec

                    last_new_event_pitch = last_new_pitch
                end
            elseif msg_type == 8 or (msg_type == 9 and val2 == 0) then -- if is a note off
                local bol = false

                for index, note_table in ipairs(mod_notes) do -- Note table structure {type, ori_pitch, ori_channel, ori_offset_count, new_pitch, new_vel, new_flags, new_len, new_pos}
                    if note_table.ori_pitch == val1 and note_table.ori_channel == msg_ch then -- found a note modded/deleted with that had the same pitch
                        local new_msg
                        local is_delete
                        -- Get the new midi msg
                        if note_table.type == mod_symbol then -- Get note off from notes I changed pitch and adjust pitch
                            new_msg =  PackMIDIMessage(msg_type,note_table.new_channel,note_table.new_pitch,val2)
                        elseif note_table.type == delete_symbol then  -- Get note off from notes I deleted and delete
                            new_msg = ''
                            is_delete = true
                        end

                        local new_pos
                        if note_table.new_len then -- There is a length to this note, calculate from new MIDI start
                            new_pos = note_table.new_pos + note_table.new_len
                        else -- Add at  new_pos maintaning the same length. 
                            local new_delta = (note_table.new_pos) - (note_table.ori_offset_count) -- Delta between original start and new start. Use the same delta to the note off. if it didnt change position it will be 0 
                            new_pos = offset_count + new_delta 
                        end

                        -- Add to table or wait legato position
                        if not legato then  -- Normal Add to the table withot Legato
                            -- Add to table
                            SetMIDIUnsorted(new_table,new_pos,offset_count,new_msg,note_table.new_flags)

                        else --  Legato
                            -- count notes off
                            if notes_cnt_off then
                                notes_cnt_off = notes_cnt_off + 1
                            end

                            for index, wait_note in ipairs(wait_list) do -- Loop all note offs hanging
                                if wait_note.ori_pitch == val1 and wait_note.ori_channel == msg_ch and not wait_note.val2 then
                                    if wait_note.legato_pos then --  Add to the table with Legato
                                        SetMIDIUnsorted(new_table,wait_note.legato_pos,offset_count,new_msg,note_table.new_flags)
                                        table.remove(wait_list,index)
                                    else -- add note off information
                                        InsertPlaceHolder(new_table,offset,offset_count) -- Insert a place holder on the original MIDI off position.
                                        if note_table.new_pitch ~= delete_symbol then
                                            wait_note.new_pitch = note_table.new_pitch or val1
                                            wait_note.new_channel = note_table.new_channel or msg_ch
                                            wait_note.val2 = val2
                                            wait_note.ori_offset_count = offset_count
                                            wait_note.new_pos = new_pos or offset_count -- position it should be added if not legato (use to add last note offs.)
                                            wait_note.flags = note_table.new_flags
                                            wait_note.pos = #new_table
                                        else
                                            table.remove(wait_list,index)
                                        end
                                    end
                                    break
                                end                        
                            end

                            if notes_cnt_off == notes_cnt then  -- Last note off insert all note offs
                                for i = #wait_list, 1, -1 do -- add note offs to new table
                                    local wait_note = wait_list[i]
                                    if wait_note.val2 then
                                        local off_msg = PackMIDIMessage(8,wait_note.new_channel,wait_note.new_pitch,wait_note.val2) 
                                        SetMIDIUnsorted(new_table, wait_note.new_pos, wait_note.ori_offset_count, off_msg, wait_note.flags)
                                        --table.remove(wait_list,#wait_list) -- Wont use this table again just leave as is...
                                    end
                                end
                            end

                        end
                        -- Remove from mod_notes and break
                        table.remove(mod_notes,index)
                        bol = true --  mark as already added to the new_table
                        break
                    end
                end

                if not bol then  -- not in the wanted notes list 
                    TableInsert(new_table,offset,offset_count,flags,midimsg)
                end 
            else -- any other MIDI selected
                TableInsert(new_table,offset,offset_count,flags,midimsg)
            end
        else -- Non selected MIDI Messages

            local bol = false -- try to catch MIDI meta Messages.
            -- Change Meta Note Evnts pitch 
            if msg_type == 15 and text:sub(1,4) == 'NOTE' then  -- catch if is meta messages.
                local meta_ch, meta_pitch = text:match('NOTE (%d+) (%d+)')
                for index, note_table in ipairs(mod_notes) do
                    if note_table.ori_pitch == tonumber(meta_pitch) and note_table.ori_offset_count == offset_count and note_table.ori_channel == (tonumber(meta_ch)+1) then -- Catch if the Meta message is for one of the selected notes
                        if note_table.type == mod_symbol then
                            local new_text = text:gsub('NOTE (%d+) (%d+)', 'NOTE '..(note_table.new_channel-1)..' '..note_table.new_pitch)
                            local new_msg = PackMIDIMessage(msg_type,msg_ch,val1,new_text)
                            SetMIDIUnsorted(new_table,note_table.new_pos,offset_count,new_msg,flags)
                        elseif note_table.type == delete_symbol then
                            --InsertPlaceHolder() dont need to insert a place holder as it is at the same offset_cout than the note!
                        end
                        bol = true
                        break
                    end
                end
            end 

            if msg_type == 11 and val1 == 123 then -- MIDI ITEM END
                -- if needed add remaining notes to complement pitch/interval parameters in last event.
                CompleteEvents(pitch_sequence, last_start_qn, i_table.pitch, ii_table.pitch, last_msg, new_table,is_looping, offset_count, false) -- Check if last event added all notes to complete the pitch/interval event. Need to lie to legato, else the note added would extended until this offsectount

                TableInsert(new_table,offset,offset_count,flags,msg)
                break
            end

            if not bol then -- Not MIDI Note Meta Message
                TableInsert(new_table,offset,offset_count,flags,msg)
            end
            

        end
    end

    local new_str = PackPackedMIDITable(new_table)
    reaper.MIDI_SetAllEvts(take, new_str)
    reaper.MIDI_Sort(take)
end

---Use this function to catch parameters that are strings and return the value and mute symbol, if any.
---@param parameter any
---@param mute_symbol string
---@return number parameter_val , boolean is_mute 
function ParameterStringToVals(parameter,mute_symbol)
    mute_symbol = mute_symbol or 'M'
    if type(parameter) ~= 'string' then --- rule out all parameters that are NOT a string, only proceed if is a string
        return parameter, false
    end 

    --local parameter_val = tonumber(parameter:match('%-?%d+'))
    local parameter_val = tonumber(parameter:match('(.*)'..mute_symbol) or parameter) -- catch the number before the mute symbol
    local mute = (parameter:match(mute_symbol .. '$') and true) or false

    return parameter_val, mute
end


    -----------------------------------