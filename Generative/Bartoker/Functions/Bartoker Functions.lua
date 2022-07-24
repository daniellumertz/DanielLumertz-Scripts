-- @noindex
function GenerateRhythm(length,rhythm_options_table)
    local melody_table_rhythm = {}
    local rhythm_sum = 0
    while rhythm_sum < length do -- if rhythm_sum is equal or less than length, add a note to the rhythm.
        local new_rhythm_value_table = rhythm_options_table[math.random(1,#rhythm_options_table)]
        for k,rhythm_val in ipairs(new_rhythm_value_table) do
            local do_break = false
            if rhythm_sum < length then -- the start of this note will be inside the melody length. So will always add it. 
                if rhythm_sum + rhythm_val > length then -- this note length will exeed the melody length trim it add it break
                    rhythm_val = rhythm_val - ((rhythm_sum + rhythm_val) - length) -- the new value trimmed to the melody length
                    do_break = true
                end
                melody_table_rhythm[#melody_table_rhythm+1] = rhythm_val
                rhythm_sum = rhythm_sum + rhythm_val
                if do_break then break end -- if the note length was greater than the melody length, break. 
            end
        end
    end
    return melody_table_rhythm    
end

---comment
---@param all_chords_table table table with chords table inside.
---@param scale table with degrees
function ChordMakeIntervalsFromSteps(all_chords_table,scale)
    for index, chord_table in ipairs(all_chords_table) do
        chord_table.fix_intervals = {}
        for key, diatonic_interval in ipairs(chord_table.diatonic_interval) do
            local scale_step = ((chord_table.root + diatonic_interval - 2) % #scale) + 1 -- -2 is for making the root and diatonic interval 0 based. +1 is to get the new scale_step 1 based
            local interval_between_root_and_scale_step = scale[scale_step] - scale[(chord_table.root)] -- interval in semitones between the root and the scale step.
            interval_between_root_and_scale_step = interval_between_root_and_scale_step % 12 -- interval in semitones between the root and the scale step make sure it is in a octave
            chord_table.fix_intervals[#chord_table.fix_intervals+1] = interval_between_root_and_scale_step  
        end
    end
    return all_chords_table
end

---comment
---@param mel_rhythms any
---@param scale any
---@param start_note any
---@param end_note any
---@param melody_steps_pillars any
---@param length any
---@param possible_intervals any
---@param tolerance number when filling the melody the tolerance is how much steps it can go off between two pillars notes. ex tolerance = 2 means it can go up to 2 steps further than it should between pillars notes.
---@param limit_5 number limit to 5 notes. if limit_5 is true, the melody will be limited to 5 first notes.
function GeneratePitches(mel_rhythms,scale,start_note,end_note,melody_steps_pillars,length,possible_intervals,tolerance,limit_5,random)
    tolerance = tolerance or 0
    limit_5 = limit_5 or 5
    possible_intervals = possible_intervals or {0,1,2,3,4}
    local mel_pitches = {}

    -- put pillar pitch in the melody. divide equally the melody, and each part gets one pillar note. each note of the part haves the length_part/note_length chance of having the pillar note
    local length_part = length/#melody_steps_pillars
    local count_length = 0 -- for summing the rhythms and triggering the end of the part to sort a pillar note
    local rhythms_per_part = {} -- saves all rhythms of the part.
    local mel_step = 1 -- 
    for index, rhythm_val in ipairs(mel_rhythms) do
        count_length = count_length + rhythm_val
        rhythms_per_part[index] = rhythm_val
        if count_length >= length_part then -- Got all the rhythms of this part
            -- generate a random number between 0 and the decimal count_length.
            local random_number = ScaleNumber(math.random(0,1000),0,1000,0,count_length)
            -- loop each rhythm index in rhythms_per_part and go adding the values if the value is bigger than the random value this note will be a pillar note.
            local count_rhythm_part = 0
            for index, rhythm_val in pairs(rhythms_per_part) do
                count_rhythm_part = count_rhythm_part + rhythm_val
                if random_number <= count_rhythm_part then
                    mel_pitches[index] = melody_steps_pillars[mel_step]
                    mel_step = mel_step + 1
                    break
                end
            end
            count_length = count_length - length_part
            rhythms_per_part = {}
        end          
    end
    -- if user say start and end note then hard put them. (even if over pillars)
    if start_note then mel_pitches[1] = start_note end
    if end_note then mel_pitches[#mel_rhythms] = end_note end
    -- if not an start or end note then put a random note from the first 5 notes from the scale.
    if not mel_pitches[1] then mel_pitches[1] = math.random(1,5) end
    if not mel_pitches[#mel_rhythms] then mel_pitches[#mel_rhythms] = math.random(1,5) end

    -- go through added notes and add notes in between
    local mel_pitches_keys = GetKeys(mel_pitches) -- get all keys from mel_pitches:
    for i, key in ipairs(mel_pitches_keys) do -- loop through the keys and add values in between next
        local next_key = mel_pitches_keys[i+1]
        if not next_key then break end
        local next_note = mel_pitches[next_key]
        local current_note = mel_pitches[key]
        local notes_in_between = next_key - key - 1
        if notes_in_between == 0 then goto continue end -- there is no notes in between
        --using possible_intervals get randomly new intervals that are in between next_note+-tolerance
        local extreme_value -- value the melody can't pass but can reach
        if next_note < current_note then -- next note is under current note
            extreme_value = next_note + (tolerance * -1)
            -- invert all intervals
            for index, interval in ipairs(possible_intervals) do
                possible_intervals[index] = interval * -1                
            end
        elseif next_note == current_note then-- same note only use 
            extreme_value =  current_note -- so it wont matter
        else -- next note is over current note
            extreme_value = next_note + tolerance
        end
        
        for i = 1, notes_in_between do
            local motion -- 1 is in direction of next note, -1 is in opposite direction.
            if (math.abs(next_note - current_note))-1 <= notes_in_between then -- the number of degrees/steps in between current and next note is less than the number of notes in between. need to go opposite directions
                motion = -1
            else -- the number of degrees in between are smaller than the number of notes in between. go same direction
                motion = 1
            end
            -- check which intervals I could use with the motion to get the 
            local current_possible_intervals = PossibleIntervals(motion,possible_intervals,current_note,next_note,extreme_value,limit_5,scale,notes_in_between)
            current_note = CalculateNewPitch(current_note,current_possible_intervals,next_note,notes_in_between,random)

            -- flip intervals if exeed limit
            current_note = FlipNotesLimit(current_note,1,limit_5 or #scale)
            notes_in_between = notes_in_between - 1
            mel_pitches[key+i] = current_note
        end
        ::continue::
    end
    mel_pitches = ScaleDegreeToNotes(scale,mel_pitches)
    return mel_pitches
end

function CalculateNewPitch(current_note,current_possible_intervals,next_note,notes_in_between,random)
    local new_note = current_note + GetFromTableRandom(current_possible_intervals) -- get a random interval
    local inter_note = current_note + ((next_note - current_note) / (notes_in_between+1))-- get the interval between current and new note
    current_note = InterpolateBetween2(new_note,inter_note,random)
    current_note = math.floor(current_note+0.5)
    return current_note
    
end

function PossibleIntervals(motion,possible_intervals,current_note,next_note,extreme_value,limit_5,scale,notes_in_between)
    local filter_uni = false
    if next_note == current_note and (notes_in_between-1) == 0 then -- remove chance of the same note repeating in sequence for 3 times 
        local bol, idx = TableHaveValue(possible_intervals, 0) 
        filter_uni = bol
    end -- if same note only use grau conjuto
    local new_intervals = {}
    for index, interval in ipairs(possible_intervals) do
        if interval == 0 and filter_uni then goto continue end -- remove chance of the same note repeating in sequence for 3 times
        local test_step = current_note + (interval * motion) -- calculate the new step if pass then add to the table
        local test_pos
        if motion == 1 then
            test_pos = (current_note <= math.abs(test_step) and math.abs(test_step) <= math.abs(extreme_value)) or (current_note >= math.abs(test_step) and math.abs(test_step) >= math.abs(extreme_value))
        elseif motion == -1 then
            test_pos = ((math.abs(test_step) <= current_note and current_note <= math.abs(extreme_value)) or (math.abs(test_step) >= current_note and current_note >= math.abs(extreme_value)))
        end
        if test_pos or not motion then -- test if the new note is in between the extreme value and the current note if motion 1. else test if current note is in between new note and extreme value
            if test_step >= 1 then -- is in between 5 notes?
                if  not limit_5 or (limit_5 and test_step<=limit_5) then
                    new_intervals[#new_intervals+1] = interval
                end
            end
        end
        ::continue::
    end
    if #new_intervals == 0 then return possible_intervals end
    return new_intervals
end

function FlipNotesLimit(current_note,min,max)
    if current_note < min then
        current_note = min + (min - current_note)
    elseif current_note > max then
        current_note = max - (current_note - max)
    end
    return current_note
end  

function ScaleDegreeToNotes(scale,mel_pitches)
    for key, step in pairs(mel_pitches) do
        mel_pitches[key] = scale[step]
    end
    return mel_pitches    
end

function GenerateChords(all_chords_sequence_table,scale,gen_take,chord_track)
    local rhythm_item = reaper.CountTrackMediaItems(chord_track)
    for i = 0, rhythm_item - 1 do
        local chord_item = reaper.GetTrackMediaItem(chord_track, i)
        local chord_take = reaper.GetActiveTake(chord_item)
        local retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(chord_take)
        local chord_sequence_idx = 1 -- to loop around a chord sequence table like: i IV, i IV, i IV
        local chord_sequence = all_chords_sequence_table[i+1]
        for note_idx = 0, notecnt-1 do
            local _, _, _, startppqpos, endppqpos, chan, _, vel = reaper.MIDI_GetNote(chord_take, note_idx)
            local note_start_time = reaper.MIDI_GetProjTimeFromPPQPos(chord_take, startppqpos) 
            local note_end_time = reaper.MIDI_GetProjTimeFromPPQPos(chord_take, endppqpos) 
            local note_start= reaper.MIDI_GetPPQPosFromProjTime(gen_take, note_start_time)
            local note_end = reaper.MIDI_GetPPQPosFromProjTime(gen_take, note_end_time)
            --- get chord and add 1 to next loop
            local chord = chord_sequence[chord_sequence_idx]
            chord_sequence_idx = (chord_sequence_idx % #chord_sequence) + 1
            ------- get chord root note 
            local root = scale[chord.root]
            local chord_notes = {root}
            local octaves_transpose = 0
            for index, semitones_interval in ipairs(chord.fix_intervals) do
                chord_notes[#chord_notes+1] = semitones_interval + chord_notes[#chord_notes]
                octaves_transpose = math.max(((chord_notes[#chord_notes]-scale[1])//12)+1,octaves_transpose) -- get how much the notes of this chord needs to be transposed!
            end
            for key, pitch in pairs(chord_notes) do
                --- insert notes
                pitch = pitch - (12*octaves_transpose)
                reaper.MIDI_InsertNote(gen_take, false, false, note_start, note_end, chan, pitch, vel, true)
            end
        end
    end
    reaper.MIDI_Sort(gen_take)  
end

function SetVelocity(rhythm_table,min_vel,max_vel,i,accents,chance,rhythm)
    -- set velocity
    local vel_curve = ScaleNumber(math.abs((#rhythm_table/2)-i), (#rhythm_table/2)-1,(#rhythm_table/2)-#rhythm_table ,1,0)
    local vel = InterpolateBetween2(min_vel,max_vel,vel_curve)
    if chance > 0 then 
        local sorted_table = TableRemoveRepeated(rhythm_table)
        table.sort(sorted_table)
        local bol,idx = TableHaveValue(sorted_table, rhythm) -- longer notes have more chance and more accentued 
        if math.random(0,100) < chance/idx then
            vel = vel + (accents/idx)
        end
    end
    vel = LimitNumber(vel,0,127)
    vel = vel//1
    return vel
end

