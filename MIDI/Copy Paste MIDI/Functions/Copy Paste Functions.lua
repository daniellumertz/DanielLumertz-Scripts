-- @noindex
function CopyMIDIParameters(take) -- TODO implement this function to look in all takes 
    if not take then  -- Change this
        local midieditor = reaper.MIDIEditor_GetActive()        
        take = reaper.MIDIEditor_GetTake( midieditor ) 
    end
    local copy_list = {} -- copy_list.rhythm copy_list.len copy_list.vel copy_list.pitch copy_list.interval
    -- Each of the following tables will have tables inside. E.G. copy_list.pitch = {{50},{60, 64, 67}} -- Sequence of pitch is note 50, chord with notes 60,64,67
    copy_list.pitch = {}
    copy_list.interval = {} -- number of elements = number of notes - 1 (insert only the difference)
    copy_list.vel = {}
    copy_list.len = {}
    copy_list.rhythm = {}   -- number of elements = number of notes - 1 (insert only the difference)
    copy_list.groove = {}   -- store position calculated from start of the measure in ppq. only store start of events position when pasting move the start of the event to the position and the other notes of the event should move the same distance, not to the same position.

    local last_start, last_note_start -- last note ppq, last first note in a chord/event ppq 
    local last_measure
    for retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel in IterateMIDINotes(take) do
        if selected then
            if (not last_start or last_start < (startppqpos-Gap)) or (not IsGap) then -- this note start a new event in the lists
                copy_list.pitch[#copy_list.pitch+1] = {pitch}
                copy_list.len[#copy_list.len+1] = {endppqpos-startppqpos}
                copy_list.vel[#copy_list.vel+1] = {vel}

                -- Rhythm 
                if last_start then -- Rule out first note
                    copy_list.rhythm[#copy_list.rhythm+1] = {startppqpos-last_note_start}
                end

                last_note_start = startppqpos -- First note of previous chord
                -- Groove/ Measure position. 
                -- Get Measure start
                local measure_start =  reaper.MIDI_GetPPQPos_StartOfMeasure( take, startppqpos )
                -- if different from last_measure open a new table inside  copy_list.groove
                if not last_measure or measure_start ~= last_measure then
                    copy_list.groove[#copy_list.groove+1] = {}
                end
                last_measure =  measure_start -- save for comparing with next note
                -- insert at the latest index of  copy_list.groove the delta from the start of the measure
                local measure_delta = startppqpos - measure_start
                table.insert(copy_list.groove[#copy_list.groove],measure_delta)
                
            else -- This notes is close to the last saved one. Save together.
                copy_list.pitch[#copy_list.pitch][#copy_list.pitch[#copy_list.pitch]+1] = pitch -- Insert at the list in the last element in copy_list.pitch same as table.insert(copy_list.pitch[#copy_list.pitch], pitch) -- Pitch
                copy_list.len[#copy_list.len][#copy_list.len[#copy_list.len]+1] = endppqpos-startppqpos
                copy_list.vel[#copy_list.vel][#copy_list.vel[#copy_list.vel]+1] = vel

                if not copy_list.rhythm[#copy_list.rhythm] then copy_list.rhythm[0] = {} end -- If the first selected note are part of chord then insert at [0]
                copy_list.rhythm[#copy_list.rhythm][#copy_list.rhythm[#copy_list.rhythm]+1] = startppqpos-last_start
            end           

            last_start = startppqpos
        end
    end
    local last_pitch
    -- Sort Pitch and make interval list (in one loop to economize time)
    for index, table_with_notes in ipairs(copy_list.pitch) do
        -- Sort
        if #table_with_notes > 1 then -- if there is more then 1 note in this event
            table.sort(copy_list.pitch[index])
        end
        -- Interval list
        -- Put the interval between the last lowest note and this lowest note.
        local pitch =  table_with_notes[1]-- pick the lowest note
        if last_pitch then 
            table.insert(copy_list.interval,{pitch - last_pitch})
        elseif #table_with_notes > 1 then
            copy_list.interval[0] = {}
        end
        -- if this index have more than one note (its a chord event), then insert a new table and calculate the interval between each element and put in a table. EG:  _v_v_vEvEv_ -- Each _ represet a note and E a chord v is a interval between elements. Inside each E needs to calculate the 2 intervals between the notes.  this wll result in a table with this archtetcture: {{inter1},{inter2},{inter3},{inter4,inter5},{inter6},{inter7,inter8}}
        if #table_with_notes > 1 then
            local last_pitch_in_chord
            for key, pitch_in_chord in ipairs(table_with_notes) do
                if last_pitch_in_chord then -- Only after 2 note will form a interval
                    copy_list.interval[#copy_list.interval][#copy_list.interval[#copy_list.interval]+1] = pitch_in_chord - last_pitch_in_chord
                end
                last_pitch_in_chord = pitch_in_chord
            end
        end

        last_pitch = pitch
    end
    return copy_list
end

function PasteRhythm(take,CopyList,RhythmInter)
    if not CopyList.rhythm or not (CopyList.rhythm[0] or CopyList.rhythm[1]) then return end -- There isnt anything saved
    local i = 0 -- To iterate over CopyList table eg = CopyList.rhythm[i][i_i]
    local i_i = 0 -- To iterate inside every CopyList table table  needs to be 0! if start with a new event it will set to 1 if start with chord then it will add to 1, if it was 1 here it would add to 2
    local notes_on = {}
    local last_start, last_new_start, last_event_start, last_new_event_start -- time of last note originally, new time of last note, time of start of last chord/event originally, new time of start of last chord/event
    local new_table = {}
    local retval, MIDIstr = reaper.MIDI_GetAllEvts(take)
    for offset, offset_count, flags, msg, stringPos in IterateAllMIDI(MIDIstr,false) do 
        local selected = (flags&1 == 1) -- Look at UnpackFlags()
        --local msg_type = msg:byte(1)>>4
        local msg_type,msg_ch,val1,val2,text,msg = UnpackMIDIMessage(msg)
        --vars

        if selected then
            if msg_type == 9 and val2 > 0 then
                if  last_start  then -- This wont be the first event/note
                    local last -- new ppq of last note that will be used to calculate the new position. Can use the start of previous note or start of previous event/chord
                    local last_original -- ppq from last note originally
                    local is_new_event = false
                    if (last_start < (offset_count-Gap)) or (not IsGap) then -- this note start a new event in the lists
                        --Reset i_i to get the first note in the table and go to next i. 
                        i = i + 1
                        i = ((i-1)%#CopyList.rhythm)+1 -- Make i loop around from 1 to #CopyList.rhythm
                        i_i = 1
                        last = last_new_event_start 
                        is_new_event = true
                        last_original = last_event_start
                        last_event_start = offset_count -- Set this event ppq as the last that happen will only be used next note
                    else-- Getting next note of a chord. 
                        i_i = i_i + 1
                        last = last_new_start
                        last_original = last_start
                    end
                    -- Get the delta in CopyList table
                    local val-- New ppq difference. If dont find the = 0. In cases like i_i is big and dont have more info on chord rhythm just put at the same place
                    if not CopyList.rhythm[i] or not CopyList.rhythm[i][i_i] then
                        val = 0
                    else
                        val = CopyList.rhythm[i][i_i]
                    end
                    --Calculate Original delta
                    local original_delta = offset_count - last_original
                    --- Calculate delta to be used using interpolation
                    val = math.floor(InterpolateBetween2(val,original_delta,RhythmInter)+0.5)-- Interpolation
                    -- new position
                    local new_val = last + val

                    SetMIDIUnsorted(new_table,new_val,offset_count,msg,flags)
                    -- Add to notes on list to catch next note off
                    notes_on[#notes_on+1] = {pitch = val1, delta = new_val - offset_count, offset_count = offset_count, ch = msg_ch} -- delta is the difference between the new ppq and the old ppq position. negative it is earlier positive it went afterwards. offset count is the original ppq position to get meta events
                    last_new_start = new_val
                    if is_new_event then last_new_event_start = new_val end
                else -- First note wont add any rhythm 
                    TableInsert(new_table,offset,offset_count,flags,msg)
                    last_new_start = offset_count
                    last_new_event_start = offset_count
                    last_event_start = offset_count
                end
                last_start = offset_count

            elseif msg_type == 8 or (msg_type == 9 and val2 == 0) then
                local bol = false
                for index, note_table in ipairs(notes_on) do
                    if note_table.pitch == val1 and note_table.ch == msg_ch then -- This pitch is on 
                        local new_val = offset_count + note_table.delta  
                        SetMIDIUnsorted(new_table,new_val,offset_count,msg,flags)
                        bol = true
                        table.remove(notes_on,index)                  
                        break
                    end
                end
                if not bol then -- if didnt catch in the notes on table
                    TableInsert(new_table,offset,offset_count,flags,msg)
                end
            else
                TableInsert(new_table,offset,offset_count,flags,msg)
            end
        else
            local bol = false
            -- Move Meta Note Evnts
            if msg_type == 15 and text:sub(1,4) == 'NOTE' then 
                local ch, pitch = text:match('NOTE (%d+) (%d+)')
                for index, note_table in ipairs(notes_on) do
                    if note_table.pitch == tonumber(pitch) and note_table.offset_count == offset_count and note_table.ch == (tonumber(ch)+1) then 
                        local new_val = offset_count + note_table.delta  
                        SetMIDIUnsorted(new_table,new_val,offset_count,msg,flags)
                        bol = true
                        break
                    end
                end
            end 
            if not bol then
                TableInsert(new_table,offset,offset_count,flags,msg)
            end
        end
    end

    local new_str = PackPackedMIDITable(new_table)
    reaper.MIDI_SetAllEvts(take, new_str)
    reaper.MIDI_Sort(take)    
end

function PasteRhythmTakes(CopyList,InterVal)
    local midi_editor = reaper.MIDIEditor_GetActive()
    for take in enumMIDITakes(midi_editor, true) do 
        if CountSelectedNotes(take) > 0 then 
            PasteRhythm(take,CopyList,InterVal)
        end
    end
    reaper.Undo_OnStateChange2( 0, 'Script: Paste MIDI Rythm' )
end

-- Diferent option paste using measure poisitions copied and saved in groove. Dont copy more than one position per event. 
function PasteRythmMeasure(take,CopyList,RhythmInter)
    if not CopyList.groove or not (CopyList.groove[0] or CopyList.groove[1]) then return end -- There isnt anything saved
    local i = 1 -- To iterate over CopyList.groove measures table eg = CopyList.groove[i][i_i]
    local i_i = 0 -- To iterate inside every measure postion. needs to be 0! if start with a new event it will set to 1 if start with chord then it will add to 1, if it was 1 here it would add to 2
    local notes_on = {}
    local last_start, last_new_start, last_event_delta -- time of last note originally, new time of last note, last_event_delta
    local new_table = {}
    local current_measure_start 
    local retval, MIDIstr = reaper.MIDI_GetAllEvts(take)
    for offset, offset_count, flags, msg, stringPos in IterateAllMIDI(MIDIstr,false) do 
        local selected = (flags&1 == 1) -- Look at UnpackFlags()
        --local msg_type = msg:byte(1)>>4
        local msg_type,msg_ch,val1,val2,text,msg = UnpackMIDIMessage(msg)
        --vars

        if selected then
            if msg_type == 9 and val2 > 0 then
                if not current_measure_start then -- save first measure start
                    current_measure_start = reaper.MIDI_GetPPQPos_StartOfMeasure( take, offset_count )
                end
                if ((not last_start) or (last_start < (offset_count-Gap))) or (not IsGap) then -- this note start a new event in the lists
                    i_i = i_i + 1 
                    if i_i > #CopyList.groove[i] then -- Go to next measure
                        i = i + 1
                        i = ((i-1)%#CopyList.groove)+1 -- Make i loop around from 1 to #CopyList.rhythm
                        i_i = 1
                        current_measure_start = reaper.MIDI_GetPPQPos_EndOfMeasure(take, current_measure_start+1) -- go to next measure
                    end
                    local new_delta_start_measure = CopyList.groove[i][i_i]
                    -- Interpolate
                    --local original_measure_start = reaper.MIDI_GetPPQPos_StartOfMeasure( take, offset_count )
                    --local original_delta = offset_count - original_measure_start 
                    --local delta = math.floor(InterpolateBetween2(new_delta_start_measure, original_delta, RhythmInter)+0.5)
                    -- use original_delta to interpolate using the current measure position. But It is kinda strange when notes come from another measure so rulling it out and interpolating using the current position and the new position
                    
                    local ppq_using_delta = new_delta_start_measure + current_measure_start
                    local new_ppq = math.floor(InterpolateBetween2(ppq_using_delta, offset_count, RhythmInter)+0.5)


                    SetMIDIUnsorted(new_table,new_ppq,offset_count,msg,flags)
                    last_event_delta = new_ppq - offset_count 
                else-- Getting next note of a chord. 
                    local new_ppq = offset_count + last_event_delta
                    SetMIDIUnsorted(new_table,new_ppq,offset_count,msg,flags)
                    -- use last_event_delta to se the new position
                end
                notes_on[#notes_on+1] = {pitch = val1, delta = last_event_delta , offset_count = offset_count, ch = msg_ch} -- delta is the difference between the new ppq and the old ppq position. negative it is earlier positive it went afterwards. offset count is the original ppq position to get meta events

                last_start = offset_count

            elseif msg_type == 8 or (msg_type == 9 and val2 == 0) then
                local bol = false
                for index, note_table in ipairs(notes_on) do
                    if note_table.pitch == val1 and note_table.ch == msg_ch then -- This pitch is on 
                        local new_val = offset_count + note_table.delta  
                        SetMIDIUnsorted(new_table,new_val,offset_count,msg,flags)
                        bol = true
                        table.remove(notes_on,index)                  
                        break
                    end
                end
                if not bol then -- if didnt catch in the notes on table
                    TableInsert(new_table,offset,offset_count,flags,msg)
                end
            else
                TableInsert(new_table,offset,offset_count,flags,msg)
            end
        else
            local bol = false
            -- Move Meta Note Evnts
            if msg_type == 15 and text:sub(1,4) == 'NOTE' then 
                local ch, pitch = text:match('NOTE (%d+) (%d+)')
                for index, note_table in ipairs(notes_on) do
                    if note_table.pitch == tonumber(pitch) and note_table.offset_count == offset_count and note_table.ch == (tonumber(ch)+1) then 
                        local new_val = offset_count + note_table.delta  
                        SetMIDIUnsorted(new_table,new_val,offset_count,msg,flags)
                        bol = true
                        break
                    end
                end
            end 
            if not bol then
                TableInsert(new_table,offset,offset_count,flags,msg)
            end
        end
    end

    local new_str = PackPackedMIDITable(new_table)
    reaper.MIDI_SetAllEvts(take, new_str)
    reaper.MIDI_Sort(take)    
end

function PasteRhythmTakesMeasure(CopyList,InterVal)
    local midi_editor = reaper.MIDIEditor_GetActive()
    for take in enumMIDITakes(midi_editor, true) do 
        if CountSelectedNotes(take) > 0 then 
            PasteRythmMeasure(take,CopyList,InterVal)
        end
    end
    reaper.Undo_OnStateChange2( 0, 'Script: Paste MIDI Rythm' )
end

function PasteLength(take,CopyList,LenghtInter)
    if not CopyList.len or not (CopyList.len[0] or CopyList.len[1]) then return end -- There isnt anything saved
    local i = 0 -- To iterate over CopyList table eg = CopyList.len[i][i_i]
    local i_i = 0 -- To iterate inside every CopyList table table 
    local last_start
    local notes_on = {}
    local new_table = {}
    local retval, MIDIstr = reaper.MIDI_GetAllEvts(take)
    for offset, offset_count, flags, msg, stringPos in IterateAllMIDI(MIDIstr,false) do 
        local selected = (flags&1 == 1) -- Look at UnpackFlags()
        local msg_type,msg_ch,val1,val2,text,msg = UnpackMIDIMessage(msg)
        --vars
        if selected then
            if msg_type == 9 and val2 > 0 then
                if (not last_start or last_start < offset_count-Gap) or (not IsGap) then -- this note starts a event/chord
                    i = i + 1
                    i = ((i-1)%#CopyList.len)+1 -- Make i loop around from 1 to #CopyList.len  
                    i_i = 1
                else -- this note continues a event/chord
                    i_i = i_i + 1
                    i_i = ((i_i-1)%#CopyList.len[i])+1 -- Make i_i loop around from 1 to #CopyList.len[i]  
                end
                
                notes_on[#notes_on+1] = {pitch = val1, start = offset_count, new_len = CopyList.len[i][i_i], ch = msg_ch}
                TableInsert(new_table,offset,offset_count,flags,msg)
                last_start = offset_count
            elseif msg_type == 8 or (msg_type == 9 and val2 == 0) then
                local bol 
                for index, note_table in ipairs(notes_on) do
                    if note_table.pitch == val1 and note_table.ch == msg_ch then
                        local original_len = offset_count - note_table.start
                        local len = math.floor(InterpolateBetween2(note_table.new_len, original_len, LenghtInter)+0.5)
                        local new_pos = note_table.start + len
                        SetMIDIUnsorted(new_table,new_pos,offset_count,msg,flags)
                        bol = true -- found this note off and added to the new table
                        table.remove(notes_on,index)
                        break
                    end
                end

                if not bol then -- this selected note off wasnt found in the list of note on. Meaning: this is a lost note off without note on
                    TableInsert(new_table,offset,offset_count,flags,msg)
                end
            else -- Selected non note on/note off
                TableInsert(new_table,offset,offset_count,flags,msg)
            end
    
        else
            TableInsert(new_table,offset,offset_count,flags,msg)
        end
    end

    local new_str = PackPackedMIDITable(new_table)
    reaper.MIDI_SetAllEvts(take, new_str)
    reaper.MIDI_Sort(take)    
end

function PasteLenTakes(CopyList,LenghtInter)
    local midi_editor = reaper.MIDIEditor_GetActive()
    for take in enumMIDITakes(midi_editor, true) do 
        if CountSelectedNotes(take) > 0 then 
            PasteLength(take,CopyList,LenghtInter)
        end
    end
    reaper.Undo_OnStateChange2( 0, 'Script: Paste MIDI Length' )
end

function PasteVelocity(take,CopyList,VelocityInter)
    if not CopyList.vel or not (CopyList.vel[0] or CopyList.vel[1]) then return end -- There isnt anything saved
    local i = 0 -- To iterate over CopyList table eg = CopyList.len[i][i_i]
    local i_i = 0 -- To iterate inside every CopyList table table 
    local last_start
    local new_table = {}
    local retval, MIDIstr = reaper.MIDI_GetAllEvts(take)
    for offset, offset_count, flags, msg, stringPos in IterateAllMIDI(MIDIstr,false) do 
        local selected = (flags&1 == 1) -- Look at UnpackFlags()
        local msg_type,msg_ch,val1,val2,text,msg = UnpackMIDIMessage(msg)
        --vars
        if selected then
            if msg_type == 9 and val2 > 0 then
                if (not last_start or last_start < offset_count-Gap ) or (not IsGap) then -- this note starts a event/chord
                    i = i + 1
                    i = ((i-1)%#CopyList.len)+1 -- Make i loop around from 1 to #CopyList.len  
                    i_i = 1
                else -- this note continues a event/chord
                    i_i = i_i + 1
                    i_i = ((i_i-1)%#CopyList.vel[i])+1 -- Make i_i loop around from 1 to #CopyList.len[i]  
                end
                local new_vel = CopyList.vel[i][i_i]
                local vel = math.floor(InterpolateBetween2(new_vel,val2,VelocityInter)+0.5)
                local new_midi = PackMIDIMessage(msg_type,msg_ch,val1,vel)
                TableInsert(new_table,offset,offset_count,flags,new_midi)
                last_start = offset_count
            else -- Selected non note on/note off
                TableInsert(new_table,offset,offset_count,flags,msg)
            end
        else
            TableInsert(new_table,offset,offset_count,flags,msg)
        end
    end

    local new_str = PackPackedMIDITable(new_table)
    reaper.MIDI_SetAllEvts(take, new_str)
    reaper.MIDI_Sort(take) 
    
end

function PasteVelTakes(CopyList,VelocityInter)
    local midi_editor = reaper.MIDIEditor_GetActive()
    for take in enumMIDITakes(midi_editor, true) do 
        if CountSelectedNotes(take) > 0 then 
            PasteVelocity(take,CopyList,VelocityInter)
        end
    end
    reaper.Undo_OnStateChange2( 0, 'Script: Paste MIDI Velocity' )
end

function PastePitches(take,CopyList,PitchInter)
    if not CopyList.pitch or not (CopyList.pitch[0] or CopyList.pitch[1]) then return end -- There isnt anything saved
    local note_idx = -1
    local i = 0 -- To iterate over CopyList table eg = CopyList.len[i][i_i]
    local i_i = 0 -- To iterate inside every CopyList table table 
    local last_start, last_msg -- last note on offset_count, last note on msg info {msg_type = msg_type, msg_ch = msg_ch, val1 = val1, val2 = val2}
    local new_table = {} -- Table to be inserted
    --- Manager tables
    local notes_mod = {} -- table with notes I changed the pitch. need to catch the original note off pitches and transpose then together. table with notes I deleted. need to catch the note off and delete them. table with notes I added using last note info. will catch next note off with the same pitch of the last note and apply to the pitches added. these notes will end up  with the same length of the last note   eg of a table inside notes_mod = {type = 'MOD', pitch = val1, new_pitches = pitch, ch = msg_ch, flags = flags}

    local retval, MIDIstr = reaper.MIDI_GetAllEvts(take)
    for offset, offset_count, flags, msg, stringPos in IterateAllMIDI(MIDIstr,false) do 
        local selected = (flags&1 == 1) -- Look at UnpackFlags()
        local msg_type,msg_ch,val1,val2,text,msg = UnpackMIDIMessage(msg)

        if msg_type == 9 then
            note_idx = note_idx + 1
        end
        --vars
        if selected then
            if msg_type == 9 and val2 > 0 then
                -- Adjust i and i_i
                if (not last_start or last_start < offset_count-Gap) or (not IsGap) then -- this note starts a event/chord
                    -- Check if i_i < #CopyList.pitch[i] and PitchFill. if true then insert notes remaning notes at last_start. using last_msg info
                    FillNotesToLastNote(CopyList,take,i,i_i,last_msg,new_table)
                    -- set i to a new value
                    i = i + 1
                    i = ((i-1)%#CopyList.pitch)+1 -- Make i loop around from 1 to #CopyList.len  
                    i_i = 1
                else -- this note continues a event/chord
                    i_i = i_i + 1 
                end
                if i_i <= #CopyList.pitch[i] then -- There are pitches in this list to be inserted
                    -- interpolate the notes
                    local new_pitch = CopyList.pitch[i][i_i]
                    local pitch = math.floor(InterpolateBetween2(new_pitch,val1,PitchInter)+0.5)
                    -- Pack and insert in the table
                    local new_midi = PackMIDIMessage(msg_type,msg_ch,pitch,val2)
                    TableInsert(new_table,offset,offset_count,flags,new_midi)
                    -- save info for next loop
                    last_msg = {msg_type = msg_type, msg_ch = msg_ch, val1 = val1 , val2 = val2, flags = flags, note_idx = note_idx}
                    -- add to a table to adjust note off
                    notes_mod[#notes_mod+1] = {type = 'MOD', pitch = val1, new_pitches = pitch, ch = msg_ch, flags = flags, offset_count = offset_count} -- pitch is original pitch new_pitches is the new pitch 
                else -- if i_i is bigger than #CopyList.pitch[i] then insert place holder! Remove pitches and dont insert anything!
                    InsertPlaceHolder(new_table,offset,offset_count)
                    notes_mod[#notes_mod+1] = {type = 'DEL', pitch = val1, ch = msg_ch,  offset_count = offset_count}
                end
                last_start = offset_count -- originally was inside the if condition of pitches that will be mooded
            elseif msg_type == 8 or (msg_type == 9 and val2 == 0) then
                local bol = false

                for index, note_table in ipairs(notes_mod) do
                    if note_table.pitch == val1 and note_table.ch == msg_ch then -- found a note modded/added/deleted with that had the same pitch
                        if note_table.type == 'MOD' then -- Get note off from notes I changed pitch and adjust pitch
                            local new_midi =  PackMIDIMessage(msg_type,msg_ch,note_table.new_pitches,val2)
                            --InsertMIDIUnsorted(new_table,offset_count,new_midi,flags)
                            TableInsert(new_table,offset,offset_count,note_table.flags,new_midi)
                        elseif note_table.type == 'DEL' then  -- Get note off from notes I deleted and delete
                            --InsertMIDIUnsorted(new_table,offset_count,'',flags)
                            InsertPlaceHolder(new_table,offset,offset_count)
                        end
                        table.remove(notes_mod,index)
                        bol = true --  mark as already added to the new_table
                        break
                    end
                end

                if not bol then  -- not in the wanted notes list 
                    TableInsert(new_table,offset,offset_count,flags,msg)
                end 
            else -- Selected non note on/note off
                TableInsert(new_table,offset,offset_count,flags,msg)
            end
        else
            local bol = false
            -- Change Meta Note Evnts pitch 
            if msg_type == 15 and text:sub(1,4) == 'NOTE' then 
                local ch, pitch = text:match('NOTE (%d+) (%d+)')
                for index, note_table in ipairs(notes_mod) do
                    if note_table.pitch == tonumber(pitch) and note_table.offset_count == offset_count and note_table.ch == (tonumber(ch)+1) then 
                        if note_table.type == 'MOD' then 
                            local new_text = text:gsub('NOTE (%d+) (%d+)', 'NOTE '..ch..' '..note_table.new_pitches)
                            local new_msg = PackMIDIMessage(msg_type,msg_ch,val1,new_text)
                            TableInsert(new_table,offset,offset_count,flags,new_msg)
                        elseif note_table.type == 'DEL' then
                            --InsertPlaceHolder() dont need to insert a place holder as it is at the same offset_cout than the note!
                        end
                        bol = true
                        break
                    end
                end
            end 
            if not bol then
                TableInsert(new_table,offset,offset_count,flags,msg)
            end
        end
    end
    FillNotesToLastNote(CopyList,take,i,i_i,last_msg,new_table) -- after all events check if it was added all notes in last CopyList.pitch[i] used

    local new_str = PackPackedMIDITable(new_table)
    reaper.MIDI_SetAllEvts(take, new_str)
    reaper.MIDI_Sort(take) 
    
end

function PastePitchTakes(CopyList,PitchInter)
    local midi_editor = reaper.MIDIEditor_GetActive()
    for take in enumMIDITakes(midi_editor, true) do 
        if CountSelectedNotes(take) > 0 then 
            PastePitches(take, CopyList,PitchInter)
        end
    end
    reaper.Undo_OnStateChange2( 0, 'Script: Paste MIDI Pitch' )
end

--- Add the notes missing in the chord CopyList.pitch[i] at the new_table
function FillNotesToLastNote(CopyList,take,i,i_i,last_msg,new_table)
    if i > 0 and i_i < #CopyList.pitch[i] and PitchFill then -- check if is missing some note
        local _, _, _, startppqpos, endppqpos, _, _, _ = reaper.MIDI_GetNote(take, last_msg.note_idx)
        for j = i_i+1, #CopyList.pitch[i] do
            local new_note_pitch = CopyList.pitch[i][j]
            -- Insert note on
            local new_midi_note = PackMIDIMessage(9,last_msg.msg_ch,new_note_pitch,last_msg.val2)
            InsertMIDIUnsorted(new_table,startppqpos,new_midi_note,last_msg.flags)
            -- Insert note off
            local new_midi_note_off = PackMIDIMessage(8,last_msg.msg_ch,new_note_pitch,0)
            InsertMIDIUnsorted(new_table,endppqpos,new_midi_note_off,last_msg.flags)
        end
    end
end

function PasteIntervals(take,CopyList,IntervalInter)
    if not CopyList.interval or not (CopyList.interval[0] or CopyList.interval[1]) then return end -- There isnt anything saved
    local note_idx = -1
    local i = 0 -- To iterate over CopyList table eg = CopyList.interval[i][i_i]
    local i_i = 0 -- To iterate inside every CopyList table table 
    local last_start, last_msg, last_msg_evnt_start -- last note on offset_count, last note on msg info, last message that started a event
    local new_table = {} -- Table to be inserted
    local note_idx = -1
    --- Manager tables
    local notes_mod = {} -- table with notes I changed the pitch. need to catch the original note off pitches and transpose then together. table with notes I deleted. need to catch the note off and delete them. table with notes I added using last note info. will catch next note off with the same pitch of the last note and apply to the pitches added. these notes will end up  with the same length of the last note   eg of a table inside notes_mod = {type = 'MOD', pitch = val1, new_pitches = pitch, ch = msg_ch, flags = flags}

    local retval, MIDIstr = reaper.MIDI_GetAllEvts(take)
    for offset, offset_count, flags, msg, stringPos in IterateAllMIDI(MIDIstr,false) do 
        local selected = (flags&1 == 1) -- Look at UnpackFlags()
        local msg_type,msg_ch,val1,val2,text,msg = UnpackMIDIMessage(msg)

        if msg_type == 9 and val2 > 0 then
            note_idx = note_idx + 1
        end
        --vars
        if selected then
            if msg_type == 9 and val2 > 0 then
                local new_pitch, last, is_start_evt -- number: new pitch, points to table to get last note original pitch/new_pitch. last alternates between last_msg and   last_msg_evnt_start. boolean if this note will start a new event
                if last_msg then
                    -- Adjust i and i_i
                    if (not last_start or last_start < offset_count-Gap) or (not IsGap) then -- this note starts a event/chord
                        -- Check if i_i < #CopyList.interval[i] and PitchFill. if true then insert notes remaning notes at last_start. using last_msg info
                        FillIntervalsToLastNote(CopyList,take,i,i_i,last_msg,new_table)
                        -- set i to a new value
                        i = i + 1
                        i = ((i-1)%#CopyList.interval)+1 -- Make i loop around from 1 to #CopyList.interval  
                        i_i = 1
                        last = last_msg_evnt_start 
                        is_start_evt = true
                    else -- this note continues a event/chord
                        i_i = i_i + 1 
                        last = last_msg
                    end
                    if CopyList.interval[i] and i_i <= #CopyList.interval[i] then -- there are intervals to add
                        -- Get interval value
                        local new_interval = CopyList.interval[i][i_i] 
                        -- Get previous note pitch original pitch, calculate the original interval.
                        local original_inter = val1 - last.original_pitch -- Positive is upwards. 
                        -- Interpolate to get the new interval
                        new_interval = math.floor(InterpolateBetween2(new_interval,original_inter,IntervalInter)+0.5)
                        -- Get previous note new pitch. Calculate with interval the new note
                        new_pitch = last.new_pitch + new_interval
                        new_pitch = LimitNumber(new_pitch,0,127)
                        -- Set on the table
                        local new_midi = PackMIDIMessage(msg_type,msg_ch,new_pitch,val2)
                        TableInsert(new_table,offset,offset_count,flags,new_midi)
                        -- Save info for meta and noteoff
                        notes_mod[#notes_mod+1] = {type = 'MOD', pitch = val1, new_pitches = new_pitch, ch = msg_ch, flags = flags, offset_count = offset_count} -- pitch is original pitch new_pitches is the new pitch 
                    else -- delete this note (no more interval info)
                        InsertPlaceHolder(new_table,offset,offset_count)
                        notes_mod[#notes_mod+1] = {type = 'DEL', pitch = val1, ch = msg_ch,  offset_count = offset_count}
                    end
                else -- First selected note
                    TableInsert(new_table,offset,offset_count,flags,msg)
                end
                -- Save info for next note on
                last_msg = {original_pitch = val1, new_pitch = (new_pitch or val1), note_idx = note_idx, val2 = val2, flags = flags, msg_ch = msg_ch} -- if not new_pitch (first note) get val1
                if not last_start or is_start_evt then last_msg_evnt_start = {original_pitch = val1, new_pitch = (new_pitch or val1)} end -- save info if this note start a event 
                last_start = offset_count
            elseif msg_type == 8 or (msg_type == 9 and val2 == 0) then
                local bol = false

                for index, note_table in ipairs(notes_mod) do
                    if note_table.pitch == val1 and note_table.ch == msg_ch then -- found a note modded/added/deleted with that had the same pitch
                        if note_table.type == 'MOD' then -- Get note off from notes I changed pitch and adjust pitch
                            local new_midi =  PackMIDIMessage(msg_type,msg_ch,note_table.new_pitches,val2)
                            TableInsert(new_table,offset,offset_count,note_table.flags,new_midi)
                        elseif note_table.type == 'DEL' then  -- Get note off from notes I deleted and delete
                            InsertPlaceHolder(new_table,offset,offset_count)
                        end
                        table.remove(notes_mod,index)
                        bol = true --  mark as already added to the new_table
                        break
                    end
                end

                if not bol then  -- not in the wanted notes list 
                    TableInsert(new_table,offset,offset_count,flags,msg)
                end 
            else -- Selected non note on/note off
                TableInsert(new_table,offset,offset_count,flags,msg)
            end
        else
            local bol = false
            -- Change Meta Note Evnts pitch 
            if msg_type == 15 and text:sub(1,4) == 'NOTE' then 
                local ch, pitch = text:match('NOTE (%d+) (%d+)')
                for index, note_table in ipairs(notes_mod) do
                    if note_table.pitch == tonumber(pitch) and note_table.offset_count == offset_count and note_table.ch == (tonumber(ch)+1) then 
                        if note_table.type == 'MOD' then 
                            local new_text = text:gsub('NOTE (%d+) (%d+)', 'NOTE '..ch..' '..note_table.new_pitches)
                            local new_msg = PackMIDIMessage(msg_type,msg_ch,val1,new_text)
                            TableInsert(new_table,offset,offset_count,flags,new_msg)
                        elseif note_table.type == 'DEL' then
                            --InsertPlaceHolder() dont need to insert a place holder as it is at the same offset_cout than the note!
                        end
                        bol = true
                        break
                    end
                end
            end 
            if not bol then
                TableInsert(new_table,offset,offset_count,flags,msg)
            end

        end
    end
    FillIntervalsToLastNote(CopyList,take,i,i_i,last_msg,new_table)

    local new_str = PackPackedMIDITable(new_table)
    reaper.MIDI_SetAllEvts(take, new_str)
    reaper.MIDI_Sort(take) 
    
end

--- Add the notes missing in the chord CopyList.interval[i] at the new_table
function FillIntervalsToLastNote(CopyList,take,i,i_i,last_msg,new_table)
    if i == 0 and not CopyList.interval[0] then return end -- rule out first event if not filled with intervals at [0]
    if  i_i < #CopyList.interval[i] and InterFill then -- check if is missing some note
        local _, _, _, startppqpos, endppqpos, _, _, _ = reaper.MIDI_GetNote(take, last_msg.note_idx)
        local last_pitch
        for j = i_i+1, #CopyList.interval[i] do
            local new_interval = CopyList.interval[i][j]
            --Get last note pitch
            last_pitch = last_pitch or last_msg.new_pitch
            -- calculate the interval
            local new_note_pitch = last_pitch + new_interval
            new_note_pitch = LimitNumber(new_note_pitch,0,127)
            last_pitch = new_note_pitch
            -- Insert note on
            local new_midi_note = PackMIDIMessage(9,last_msg.msg_ch,new_note_pitch,last_msg.val2)
            InsertMIDIUnsorted(new_table,startppqpos,new_midi_note,last_msg.flags)
            -- Insert note off
            local new_midi_note_off = PackMIDIMessage(8,last_msg.msg_ch,new_note_pitch,0)
            InsertMIDIUnsorted(new_table,endppqpos,new_midi_note_off,last_msg.flags)
        end
    end
end

function PasteIntervalsTakes(CopyList,IntervalInter)
    local midi_editor = reaper.MIDIEditor_GetActive()
    for take in enumMIDITakes(midi_editor, true) do 
        if CountSelectedNotes(take) > 0 then 
            PasteIntervals(take,CopyList,IntervalInter)
        end
    end
    reaper.Undo_OnStateChange2( 0, 'Script: Paste MIDI Intervals' )
end


function PasteGroove(take,CopyList,GrooveInter)
    if not CopyList.groove or not (CopyList.groove[0] or CopyList.groove[1]) then return end -- There isnt anything saved
    local i = 0 -- To iterate over CopyList table eg = CopyList.rhythm[i][i_i]
    local notes_on = {}
    local last_start -- time of last note originally
    local last_delta_start -- how much last note was move 
    local last_measure_start -- last measure position
    local new_table = {}
    local retval, MIDIstr = reaper.MIDI_GetAllEvts(take)
    for offset, offset_count, flags, msg, stringPos in IterateAllMIDI(MIDIstr,false) do 
        local selected = (flags&1 == 1) -- Look at UnpackFlags()
        --local msg_type = msg:byte(1)>>4
        local msg_type,msg_ch,val1,val2,text,msg = UnpackMIDIMessage(msg)
        --vars

        if selected then
            if msg_type == 9 and val2 > 0 then
                -- get start of this measure
                local measure_start = reaper.MIDI_GetPPQPos_StartOfMeasure( take, offset_count )
                ---if this note is in a new measure  increment i (get values from another measure in the list )
                if measure_start ~= last_measure_start then
                    i = i + 1
                    i = ((i-1)%#CopyList.groove)+1 -- Make i loop around from 1 to #CopyList.groove
                end

                if (not last_start or last_start < offset_count-Gap) or (not IsGap) then -- this note starts a event/chord
                    -- get distance from measure start
                    local distance_from_measure_start = offset_count - measure_start
                    -- get the index of closest measure positon smaller than offset_count  
                    local small_idx = BinarySearchInTable(CopyList.groove[i],distance_from_measure_start)
                    -- calculate nearest position 
                    local new_measure_pos 
                    if small_idx == 0 then -- happens before any event in the list
                        new_measure_pos = CopyList.groove[i][1]
                    elseif small_idx == #CopyList.groove[i] then -- happens after all events in the list
                        new_measure_pos = CopyList.groove[i][#CopyList.groove[i]]
                    else -- happens between two values
                        local delta_prev = distance_from_measure_start - CopyList.groove[i][small_idx] 
                        local delta_next = CopyList.groove[i][small_idx+1]  - distance_from_measure_start
                        new_measure_pos = (delta_prev < delta_next) and CopyList.groove[i][small_idx] or CopyList.groove[i][small_idx+1] -- if (delta_prev < delta_next) then CopyList.groove[i][small_idx] else CopyList.groove[i][small_idx+1] end
                    end

                    -- calculate new position and delta
                    local new_pos = measure_start + new_measure_pos
                    new_pos = InterpolateBetween2(new_pos, offset_count, GrooveInter)
                    new_pos = math.floor(new_pos + 0.5) -- quantize to a integer value, cant set a decimal point ppq 
                    local delta = new_pos - offset_count -- positive it moves to after. negative it moves to before
                    -- Set midi
                    SetMIDIUnsorted(new_table,new_pos,offset_count,msg,flags)
                    -- save info for next event note
                    last_delta_start = delta 
                else -- this note continues a event/chord
                    -- get last delta movement and apply the same value here
                    local new_pos = offset_count + last_delta_start 
                    --- set midi
                    SetMIDIUnsorted(new_table,new_pos,offset_count,msg,flags)
                end             
                -- Save info for note off and meta
                notes_on[#notes_on+1] = {pitch = val1, delta = last_delta_start, ch = msg_ch, offset_count = offset_count}
                last_start = offset_count
                last_measure_start = measure_start
            elseif msg_type == 8 or (msg_type == 9 and val2 == 0) then

                local bol = false
                for index, note_table in ipairs(notes_on) do
                    if note_table.pitch == val1 and note_table.ch == msg_ch then -- This pitch is on 
                        local new_val = offset_count + note_table.delta  
                        SetMIDIUnsorted(new_table,new_val,offset_count,msg,flags)
                        bol = true
                        table.remove(notes_on,index)                  
                        break
                    end
                end

                if not bol then -- if didnt catch in the notes on table
                    TableInsert(new_table,offset,offset_count,flags,msg)
                end
                
            end
        else
            local bol = false
            -- Move Meta Note Evnts
            if msg_type == 15 and text:sub(1,4) == 'NOTE' then 
                local ch, pitch = text:match('NOTE (%d+) (%d+)')
                for index, note_table in ipairs(notes_on) do
                    if note_table.pitch == tonumber(pitch) and note_table.offset_count == offset_count and note_table.ch == (tonumber(ch)+1) then 
                        local new_val = offset_count + note_table.delta  
                        SetMIDIUnsorted(new_table,new_val,offset_count,msg,flags)
                        bol = true
                        break
                    end
                end
            end 
            if not bol then
                TableInsert(new_table,offset,offset_count,flags,msg)
            end
        end
    end

    local new_str = PackPackedMIDITable(new_table)
    reaper.MIDI_SetAllEvts(take, new_str)
    reaper.MIDI_Sort(take)    
end


function PasteGrooveTakes(CopyList,GrooveInter)
    local midi_editor = reaper.MIDIEditor_GetActive()
    for take in enumMIDITakes(midi_editor, true) do 
        if CountSelectedNotes(take) > 0 then 
            PasteGroove(take,CopyList,GrooveInter)
        end
    end
    reaper.Undo_OnStateChange2( 0, 'Script: Paste MIDI Rythm' )
end

function AutoPaste(paste_function,InterVal,SaveCopy,CopyList)
    -- First paste the saved version, uses place holder to store the value
    paste_function(SaveCopy,1)
    -- Second paste with current configs
    paste_function(CopyList,InterVal)
end