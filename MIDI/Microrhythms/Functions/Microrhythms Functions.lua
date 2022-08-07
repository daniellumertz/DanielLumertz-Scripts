-- @noindex
function MakeRhythmTable(input,input_length)
    if not input or not input_length or  input == '' or input_length == '' then return end
    local separator = ','
    input = input..separator

    local table_rhythm_input = {}
    local total_len_ratio = 0 -- adds all values in ratio input
    for ratio in input:gmatch('(.-)'..separator) do
        local ratio_num = tonumber(ratio) -- return nil if not number. accepts decimal values
        if ratio_num then
            total_len_ratio = total_len_ratio + ratio_num
            table_rhythm_input[#table_rhythm_input+1] = ratio_num
        end
    end
    -- Put the ratio in the size of length
    input_length = tonumber(input_length)
    local ppq = 960 -- TODO look how not hardcode the ppq in the settings
    local total_ppq = input_length * ppq
    local table_rhythm = {}
    for index, ratio in ipairs(table_rhythm_input) do
        table_rhythm[#table_rhythm+1] = total_ppq*(ratio/total_len_ratio) --  (ratio/total_len_ratio) = how much this ratio is from the total. if ratio = 2 and len_ratio = 4 then it is 1/2 of the total. and it will have 1/2 of the total_ppq
    end
    local steady_val = total_ppq/#table_rhythm

    return table_rhythm, steady_val
end

function SetMicrorhythm(IsGap,Gap,RhythmTable,SteadyValue,IterValue) 
    local midi_editor = reaper.MIDIEditor_GetActive()
    for take in enumMIDITakes(midi_editor, true) do 
        if CountSelectedNotes(take) > 0 then 
            PasteRhythm(IsGap,Gap,take,RhythmTable,SteadyValue,IterValue)
        end
    end
    reaper.Undo_OnStateChange2( 0, 'Script: Paste MIDI MicroRythm' )
end


function PasteRhythm(IsGap,Gap,take,RhythmTable1,SteadyValue,RhythmInter)
    if not RhythmTable1 or not (RhythmTable1[1]) then return end -- There isnt anything saved
    local i = 0 -- To iterate over RhythmTable1 table eg = RhythmTable1[i][i_i]
    local notes_on = {}
    local last_start, last_new_start, last_new_event_start -- time of last note originally, new time of last note, time of start of last chord/event originally, new time of start of last chord/event
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
                    local new_val -- new note position
                    if (last_start < (offset_count-Gap)) or (not IsGap) then -- this note start a new event in the lists
                        --Reset i_i to get the first note in the table and go to next i. 
                        i = i + 1
                        i = ((i-1)%#RhythmTable1)+1 -- Make i loop around from 1 to #CopyList.rhythm
                        --- Get value
                        local val = RhythmTable1[i]-- New ppq difference. If dont find the = 0. In cases like i_i is big and dont have more info on chord rhythm just put at the same place                        
                        --- Iterpolate
                        val = math.floor(InterpolateBetween2(val,SteadyValue,RhythmInter)+0.5)-- Interpolation
                        -- new position
                        new_val = last_new_event_start + val
                        SetMIDIUnsorted(new_table,new_val,offset_count,msg,flags)
                        -- next loop
                        last_new_event_start = new_val
                        last_new_start = new_val
                    else-- Getting next note of a chord. Should move together with last event
                        local original_delta = offset_count - last_start 
                        new_val = last_new_start + original_delta
                        SetMIDIUnsorted(new_table,new_val,offset_count,msg,flags)
                        last_new_start = new_val
                    end

                    -- Add to notes on list to catch next note off
                    notes_on[#notes_on+1] = {pitch = val1, delta = new_val - offset_count, offset_count = offset_count, ch = msg_ch} -- delta is the difference between the new ppq and the old ppq position. negative it is earlier positive it went afterwards. offset count is the original ppq position to get meta events
                else -- First note wont add any rhythm 
                    TableInsert(new_table,offset,offset_count,flags,msg)
                    last_new_start = offset_count
                    last_new_event_start = offset_count
                end
                last_start = offset_count -- Original last note pos

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

