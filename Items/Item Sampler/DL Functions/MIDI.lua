--@noindex
--version: 0.0

DL = DL or {}
DL.midi = {}

---------------------
----------------- MIDI Message Pack 
---------------------
---Unpack a packed string MIDI message in different values
---@param msg string midi as packed string
---@return number msg_type midi message type: Note Off = 8; Note On = 9; Aftertouch = 10; CC = 11; Program Change = 12; Channel Pressure = 13; Pitch Vend = 14; text = 15. 
---@return number msg_ch midi message channel 1 based (1-16)
---@return number data2 databyte1 -- like note pitch, cc num
---@return number|boolean data3 databyte2 -- like note velocity, cc val. Some midi messages dont have databyte2 and this will return nill. For getting the value of the pitchbend do databyte1 + databyte2
---@return string text if message is a text return the text
function DL.midi.UnpackMIDIMessage(msg)
    local msg_type = msg:byte(1)>>4
    local msg_ch = (msg:byte(1)&0x0F)+1 --msg:byte(1)&0x0F -- 0x0F = 0000 1111 in binary. this is a bitmask. +1 to be 1 based

    local text
    if msg_type == 15 then
        text = msg:sub(3)
    end

    local val1 = msg:byte(2)
    local val2 = (msg_type ~= 15) and msg:byte(3) -- return false if is text
    return msg_type,msg_ch,val1,val2,text
end

---Pack a midi message in a string form. Each character is a midi byte. Can receive as many data bytes needed. Just join midi_type and midi_ch in the status bytes and thow it in PackMessage. 
---@param midi_type number midi message type: Note Off = 8; Note On = 9; Aftertouch = 10; CC = 11; Program Change = 12; Channel Pressure = 13; Pitch Vend = 14; text = 15.
---@param midi_ch number midi ch 1-16 (1 based.)
---@param ... number sequence of data bytes can be number (will be converted to string(a character with the equivalent byte)) or can be a string that will be added to the message (useful for midi text where each byte is a character).
function DL.midi.PackMIDIMessage(midi_type,midi_ch,...)
    local midi_ch = midi_ch - 1 -- make it 0 based
    local status_byte = (midi_type<<4)+midi_ch -- where is your bitwise operation god now?
    return DL.midi.PackMessage(status_byte,...)
end

---Receives numbers(0-255). or strings. and return them in a string as bytes
---@param ... number
---@return string
function DL.midi.PackMessage(...)
    local msg = ''
    for i, v in ipairs( { ... } ) do
        local new_val
        if type(v) == 'number' then 
            new_val = string.char(v) 
        elseif type(v) == 'string' then -- In case it is a string (useful for midi text where each byte is a character)
            new_val = v
        elseif not v then -- in case some of the messages is nil. No problem! This is useful as PackMIDITable will send .val2 and .text. not all midi have val2 and not all midi have .text
            new_val = ''
        end
        msg = msg..new_val
    end
    return msg
end

---Unpack flags into selected, muted, curve_shape
---@param flag number
---@return boolean selected is selected
---@return boolean muted is muted
---@return integer curve_shape curve type 0square, 1linear, 2slow start/end, 3fast start, 4fast end, 5bezier
function DL.midi.UnpackFlags(flag)
    local selected =  flag&1 == 1   -- AND operation with  1 (1 in binary) (return the first bit val)
    local muted =  flag&2 == 2      -- AND operation with 10 (2 in binary) (return the second bit val + 1 bit as 0 I could also move it to the void)
    -- cc_string
    local curve_shape = flag>>4 -- Void the first 4 bits as they dont matter for cc curve and get the value. If is flags from something without curve shape like notes will just return 0, as square
        
    return selected, muted, curve_shape
end

---Pack options into flags
---@param selected boolean is selected
---@param muted boolean is muted
---@param curve_shape number? curve type 0square, 1linear, 2slow start/end, 3fast start, 4fast end, 5bezier
---@return integer flags flags number
function DL.midi.PackFlags(selected, muted, curve_shape)
    local flags = curve_shape and curve_shape<<4 or 0
    flags = flags|(muted and 2 or 0)|(selected and 1 or 0) -- if selected or muted are true return number. this is a OR operation flags|2or0|1or0 (2 = 10 ; 1 = 1)
    return flags
end

---------------------
----------------- MIDI Table 
---------------------
DL.midi.t = {}

---This function gets a midi_table and return it to string packed formated to be feeded at MIDI_SetAllEvts
---@param midi_table table midi_table {{msg = '', flags = '', offset = n}}. Messages and flags can also be unpacked, in this case turn on  `is_pack_msg` and `is_pack_flags`: {{msg = {type = n, ch = n, val1? = n, val2? = n, text? = ''}, flags = {selected = bool, muted = bool, curve_shape = n}, offset = n}}
---@return string
function DL.midi.t.Pack(midi_table)
    local packed_table = {}
    for i, value in pairs(midi_table) do
        local packed_midi =  (type(midi_table[i].msg) ~= table and midi_table[i].msg) or DL.midi.PackMIDIMessage(midi_table[i].msg.type, midi_table[i].msg.ch, midi_table[i].msg.val1, midi_table[i].msg.val2,midi_table[i].msg.text) 
        local packed_flags = (type(midi_table[i].flags) ~= table and midi_table[i].flags) or DL.midi.PackFlags(midi_table[i].flags.selected, midi_table[i].flags.muted, midi_table[i].flags.curve_shape)
        packed_table[#packed_table+1] = string.pack("i4Bs4", midi_table[i].offset, packed_flags, packed_midi) 
    end
    return table.concat(packed_table) -- I didnt remove the last val at CreateMIDITable so everything should be here! If remove add it here, calculating offset.
end

---------------------
----------------- MIDI Table Handling 
---------------------

---Insert in the table normally without changing position (just to make a nice abstraction)
---@param midi_table table with all midi events
---@param offset number offset from last message 
---@param offset_count number optional total offset
---@param flags any --flags message
---@param msg any midi message
function DL.midi.t.Put(midi_table,offset,offset_count,flags,msg)
    midi_table[#midi_table+1] = { offset = offset, offset_count = offset_count, flags = flags, msg = msg}
end

---Insert in a table changing the original positions.
---@param midi_table table with all midi events
---@param new_ppqpos number new ppqpos 
---@param old_ppqpos number old ppqpos
---@param old_offset number old offset
---@param midi_msg any --midi message
---@param flags any --flags message
function DL.midi.t.Set(midi_table,new_ppqpos,old_ppqpos,old_offset,midi_msg,flags)
    local delta = (old_ppqpos - new_ppqpos)
    local message = {offset = old_offset - delta ,msg = midi_msg, flags = flags, offset_count = new_ppqpos}
    local holder = {offset = delta ,msg = '', flags = 0, offset_count = old_ppqpos}

    midi_table[#midi_table+1] = message -- new_offset = offset + delta. new  difference from last midi message 
    midi_table[#midi_table+1] = holder-- put a place holder nothing message that get deleted where this message originally was. so dont need to sort next midi message
end

---Add a new MIDI to a table 
---@param midi_table table table with all midi events
---@param ppqpos number  when in ppq insert the message
---@param midi_msg any midi message.
---@param flags any flags message.
function DL.midi.t.Add(midi_table,ppqpos,midi_msg,flags)
    local last_offset_count
    if #midi_table > 0  then
        last_offset_count = midi_table[#midi_table].offset_count -- ppq position of the last element
    else
        last_offset_count = 0
    end
    local delta = ppqpos - last_offset_count
    local message = {offset = delta ,msg = midi_msg, flags = flags, offset_count = ppqpos}
    local holder = {offset = -delta ,msg = '', flags = 0, offset_count = last_offset_count}

    midi_table[#midi_table+1] = message -- new_offset = offset + delta. new  difference from last midi message 
    midi_table[#midi_table+1] = holder-- put a place holder nothing message that get deleted where this message originally was. so dont need to sort next midi message
end

---Use to delete elements that existed previusly, without needing to change any offset.
---@param midi_table table midi table to insert this event
---@param offset number offset from last message 
---@param offset_count number total offset
function DL.midi.t.Remove(midi_table,offset,offset_count)
    local holder = {offset = offset ,msg = '', flags = 0, offset_count = offset_count}
    midi_table[#midi_table+1] = holder
end

---------------------
----------------- MIDI Ticks // PPQ
---------------------

---Get the ppq resolution from a take.
---@param take MediaItem_Take 
function DL.midi.GetTakePPQ(take)
    local sourceStartQN = reaper.MIDI_GetProjQNFromPPQPos(take, 0)
    local ppq = (0.5 + reaper.MIDI_GetPPQPosFromProjQN(take, sourceStartQN + 1))//1 
    return ppq
end

---Return the measure number(0 Based) from a position in ticks. If is the tick that start the measure/ end previous measure, it will return the measure starting number
---@param take MediaItem_Take 
---@param ppq_pos number position in ticks
---@return number measure measure number 0 Based
function DL.midi.GetMeasureNumberFromPPQPos(take, ppq_pos)
    local pos = reaper.MIDI_GetProjTimeFromPPQPos( take, ppq_pos )
    local retval, measures, cml, fullbeats, cdenom = reaper.TimeMap2_timeToBeats( 0, pos )
    return measures ---@diagnostic disable-line
end

---Return the same project time position in another take.
---@param take1 MediaItem_Take Take that will return the new positon.
---@param take2 MediaItem_Take Take that provide the ppqpos. 
---@param take2_ppqPos number ppqpos in take2.
function DL.midi.TransposePPQPos(take1, take2, take2_ppqPos)
    local proj_qn = reaper.MIDI_GetProjQNFromPPQPos( take2, take2_ppqPos )
    return math.floor(reaper.MIDI_GetPPQPosFromProjQN( take1, proj_qn )+0.5)
end

---------------------
-- Get Meta Events --
---------------------

---For CC Meta-messages Gets all the midi text message like 'CCBZ  \�B�' and returns the bezier type and the tension.
---@param text string all midi text, as returned by UnpackMIDIMessage
---@return number bezier_type normally 0
---@return number tension float 
function DL.midi.UnpackCCBZ(text)
    local bezier_type = text:sub(6,6):byte()
    local tension = string.unpack('f', text:sub(7,10)) 

    return bezier_type, tension
end


---
---Make a binary search in take, looking for the MIDISysex that happens at desired_ppqpos. 
---@param desired_ppqpos number time in ppq where should be an Sysex event.
---@param take MediaItem_Take the MIDI take 
---@param textsyxevtcnt number the count of text sysex events in the take. returned by reaper.MIDI_CountEvts(take)
---@return table|nil t return the table with the sysex messages that happens at desired_ppqpos. Each Sysex is inside a table contaning all their info from MIDI_GetTextSysexEvt {selected = selected, muted = muted, ppqpos = ppqpos, type = type, msg = msg}
local function binary_search_MIDITxt(desired_ppqpos, take, textsyxevtcnt)
    -- lowest idx
    local low = 0
    -- highest idx
    local high = textsyxevtcnt - 1
    -- if find the interval 
    local idx 
    local t = {}
    while low <= high do
        -- mid idx between lowest and highest
        local mid = math.floor((low + high) / 2)
        local retval, selected, muted, test_ppqpos, type, msg = reaper.MIDI_GetTextSysexEvt( take, mid )
        if test_ppqpos == desired_ppqpos then
            t[#t+1] =  {selected = selected, muted = muted, ppqpos = test_ppqpos, type = type, msg = msg}
            idx = mid
            break 
        elseif test_ppqpos < desired_ppqpos then
            low = mid + 1
        else
            high = mid - 1
        end
    end

    if idx then
        --check each idx before and after the found idx to see if there is a Sysex event at the same position. If so, add it to the table.
        if idx > 0 then
            for i = idx-1, 0, -1 do
                local retval, selected, muted, test_ppqpos, type, msg = reaper.MIDI_GetTextSysexEvt( take, i )
                if test_ppqpos == desired_ppqpos then
                    t[#t+1] =  {selected = selected, muted = muted, ppqpos = test_ppqpos, type = type, msg = msg}
                else
                    break
                end
            end
        end

        if idx < textsyxevtcnt-1 then
            for i = idx+1, textsyxevtcnt-1 do
                local retval, selected, muted, test_ppqpos, type, msg = reaper.MIDI_GetTextSysexEvt( take, i )
                if test_ppqpos == desired_ppqpos then
                    t[#t+1] =  {selected = selected, muted = muted, ppqpos = test_ppqpos, type = type, msg = msg}
                else
                    break
                end
            end
        end

        return t
        
    else
        return nil -- havent found any value that match desired_ppqpos
    end
end

---Get the meta event msg of a noteidx in take.
---@param take MediaItem_Take MediaTake
---@param noteidx number index of the note in the take. (0 based)
---@return string|boolean msg return the message of the meta event. If don't find any return nil.
function DL.midi.GetNoteMetaEvents(take, noteidx)
    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, noteidx)
    local retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
    local meta_table = binary_search_MIDITxt(startppqpos, take, textsyxevtcnt) 
    if not meta_table then return false end
    for index, meta in ipairs(meta_table) do
        if meta.msg ~= '' then
            local meta_ch, meta_pitch = meta.msg:match('NOTE (%d+) (%d+)')
            if tonumber(meta_ch) == chan and tonumber(meta_pitch) == pitch then
                return meta.msg
            end
        end
    end
    return false
end



---------------------
----------------- MIDI MISC
---------------------

--- Reorder MIDI Notes ON/OFF that start/end at the same time.
---@param take MediaItem_Take the MIDI take
---@param bottomup boolean if true, the notes with lower pitch will be first. If false, the notes with higher pitch will be first.
---@param sort boolean sort the MIDI at the end? If this is going to be used in the middle of another function makes sense to sort only once
function DL.midi.SortNotes(take,bottomup,sort) 
    bottomup = (bottomup == nil and true) or bottomup
    ---- Sort wait table and add to the new midi table
    local function sort_wait_table(wait_table,bottomup,new_midi_table)
        -- sort table 
        if bottomup then
            table.sort(wait_table, function(a,b) return a.pitch < b.pitch end) -- TODO need to if same pitch whoever came first goes first  .offset_count have the position 
        else
            table.sort(wait_table, function(a,b) return a.pitch > b.pitch end)
        end
        --add to new table
        for index, value in ipairs(wait_table) do
            DL.midi.t.Add(new_midi_table,value.offset_count,value.midimsg,value.flags)
            if value.meta then
                DL.midi.t.Add(new_midi_table,value.meta.offset_count,value.meta.midimsg,value.meta.flags)
            end
        end
    end

    local function try_to_add_to_table(new_table,offset_count,wait_start,wait_end,last_start)
        if last_start and last_start ~= offset_count then -- new position add all notes at wait table
            sort_wait_table(wait_end,bottomup,new_table)
            sort_wait_table(wait_start,bottomup,new_table)

            --reset table
            wait_start = {}
            wait_end = {}
            last_start = offset_count -- set the new value
        end
        return wait_start, wait_end, last_start, new_table
    end
    

    local new_table = {}
    local retval, MIDIstr = reaper.MIDI_GetAllEvts(take)
    -------- Looop through all events
    local last_start, last_end = 0,0
    local wait_start, wait_end = {},{} -- table to add the notes waiting
    for offset, offset_count, flags, midimsg, stringPos in DL.enum.AllMIDI(MIDIstr,false) do
        local msg_type,msg_ch,val1,val2,text,msg = DL.midi.UnpackMIDIMessage(midimsg)
        if msg_type == 9 and val2 > 0 then -- noteon

            wait_start, wait_end, last_start, new_table = try_to_add_to_table(new_table,offset_count,wait_start,wait_end,last_start)
            
            -- get metamessages
            local meta
            do 
                local offset2, flags2, msg2, stringPos2 = string.unpack("i4Bs4", MIDIstr, stringPos)
                if offset2 == 0 then
                    local msg_type2,msg_ch,val1,val2,text2,msg = DL.midi.UnpackMIDIMessage(msg2) ---@diagnostic disable-line
                    if  msg_type2 == 15 and text2:sub(1,4) == 'NOTE' then
                        meta = {offset = offset, offset_count = offset_count, flags = flags2, midimsg = msg2}
                    end
                end
            end

            -- ad to wait table
            wait_start[#wait_start+1] = {offset = offset, offset_count = offset_count, flags = flags, midimsg = midimsg, stringPos = stringPos, pitch = val1, meta = meta}
        elseif msg_type == 8 or (msg_type == 9 and val2 == 0) then  --noteoff

            wait_start, wait_end, last_start, new_table = try_to_add_to_table(new_table,offset_count,wait_start,wait_end,last_start)

            -- ad to wait table
            wait_end[#wait_end+1] = {offset = offset, offset_count = offset_count, flags = flags, midimsg = midimsg, stringPos = stringPos, pitch = val1}
        elseif msg_type == 15 then
            if text:sub(1,4) ~= 'NOTE' then -- already adding them
                DL.midi.t.Add(new_table,offset_count,midimsg,flags)
            end
        else
            if msg_type == 11 and val1 == 123 then -- all notes off
                sort_wait_table(wait_start,bottomup,new_table)
                sort_wait_table(wait_end,bottomup,new_table)
                DL.midi.t.Add(new_table,offset_count,midimsg,flags)
            else
                DL.midi.t.Add(new_table,offset_count,midimsg,flags)
            end
        end        
    end

    local new_str = DL.midi.t.Pack(new_table)
    reaper.MIDI_SetAllEvts(take, new_str)
    if sort then
        reaper.MIDI_Sort(take)
    end
end
