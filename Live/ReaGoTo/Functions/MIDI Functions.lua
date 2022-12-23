-- @noindex
-- version: 0.6
-- add MIDI input
---------------------
----------------- Iterate
---------------------

---Iterate this function it will return the takes open in midi_editor window. editable_only == get only the editables 
---@param midi_editor midi_editor midi_editor window
---@param editable_only boolean If true get only takes that are editable in midi_editor 
---@return function iterate takes
function enumMIDITakes(midi_editor, editable_only)
    local i = -1
    return function()
        i = i + 1
        return reaper.MIDIEditor_EnumTakes(midi_editor, i, editable_only)
    end
end

--- This is the simple version that haves no filter besides the last event. Easy to understand and if you want to check the difference in performance with my IterateMIDI function. Or if you want to filter yourself. 
---@param MIDIstring string string with all MIDI events (use reaper.MIDI_GetAllEvts)
---@param filter_midiend boolean Filter Last MIDI message (reaper automatically add a message when item ends 'CC123')
---@return function
function IterateAllMIDI(MIDIstring,filter_midiend)
    -- Should it iterate the last midi 123 ? it just say when the item ends 
    local MIDIlen = MIDIstring:len()
    if filter_midiend then MIDIlen = MIDIlen - 12 end
    local iteration_stringPos = 1
    local offset_count = 0

    return function ()
        if iteration_stringPos < MIDIlen then 
            local offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, iteration_stringPos)
            iteration_stringPos = stringPos
            offset_count = offset + offset_count

            return  offset, offset_count, flags, msg, stringPos
        else -- Ends the iteration
            return nil 
        end 
    end    
end

---Iterate the MIDI messages inside the string out of  reaper.MIDI_GetAllEvts. Returns offset, flags, msg, offset_count, stringPos. offset is offset from last midi event. flags is midi message reaper option like muted, selected.... msg is the midi message. offset_count is the offset in ppq from the start of the iteration (the start of the MIDI item or at start.stringPos(start.ppq and start.event_n dont affect this count)). event_count is the event nº between all MIDI events. stringPos the position in the string for the next event. 
---@param MIDIstring string string with all MIDI events (use reaper.MIDI_GetAllEvts)
---@param miditype table Filter messages MIDI by message type. Table with multiple types or just a number. (Midi type values are defined in the firt 4 bits of the data byte ): Note Off = 8; Note On = 9; Aftertouch = 10; CC = 11; Program Change = 12; Channel Pressure = 13; Pitch Vend = 14; text = 15. 
---@param ch table Filter messages MIDI by chnnale. Table with multiple channel or just a number. 1 Based.
---@param selected boolean Filter messages MIDI if they are selected in MIDI editor. true = only selected; false = only not selected; nil = either. 
---@param muted boolean Filter messages MIDI if they are muted in MIDI editor. true = only muted; false = only not muted; nil = either. 
---@param filter_midiend boolean Filter Last MIDI message (reaper automatically add a message when item ends 'CC123')
---@param start table start is a table that determine where to start iterating in the midi evnts. The key determine the options: 'ppq','event_n','stringPos' the value determine the value to start. For exemple {ppq=960} will start at events that happen at and after 960 midi ticks after the start of the item. {event_n=5} will start at the fifth midi message (just count messages that pass the filters). {stringPos = 13} will start at the midi message in the 13 byte on the packed string.
---@param step number will only return every number of step midi message (will only count messages that passes the filters). 
---@return function -- offset, offset_count, flags, msg, event_count, stringPos
function IterateMIDI(MIDIstring,miditype,ch,selected,muted,filter_midiend,start,step)
    local MIDIlen = MIDIstring:len()
    if filter_midiend then MIDIlen = MIDIlen - 12 end
    -- start filter settings
    local iteration_stringPos = start and start.stringPos or 1 -- the same as if start and start.stringPos then iteration_stringPos = start.stringPos else iteration_stringPos = 1 end
    local event_n = 0 -- if start.event_n will count every message that passes all filters and will only start returning at event start.event_n
    local event_count = 0 -- event count will return the event count nº between all midi events
    local offset_count = 0
    ----
    local step_count = -1 -- only for using step
    return function ()
        while iteration_stringPos < MIDIlen do 
            local offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, iteration_stringPos)
            iteration_stringPos = stringPos -- set iteration_stringPos for next iteration
            offset_count = offset_count + offset -- this returns the distance in ppq from each message from the start of the midi item or the first stringPos used
            event_count = event_count +1

            -- Start ppq filters: 
            if start and start.ppq and offset_count < start.ppq   then -- events earlier than start.ppq
                goto continue
            end
            
            -- check midi type .
            if miditype then 
                local msg_type = msg:byte(1)>>4 -- moves last 4 bit into void. Rest only the first 4 bits that define midi type
                if type(miditype) == "table" then -- if miditype is a table with all types to get
                    if not TableHaveValue(miditype, msg_type) then goto continue end 
                else -- if is just a value
                    if not (msg_type == miditype) then goto continue end 
                end
            end
            
            -- check channel.
            if ch then  
                local msg_ch = msg:byte(1)&0x0F -- 0x0F = 0000 1111 in binary . msg is string. & is an and bitwise operation "have to have 1 in both to be 1". Will return channel as a decimal number. 0 based
                msg_ch = msg_ch + 1 -- makes it 1 based
                if type(ch) == "table" then -- if ch is a table with all ch to get
                    if not TableHaveValue(ch, msg_ch) then goto continue end 
                else -- if is just a value
                    if not (msg_ch == ch) then goto continue end 
                end
            end

            local msg_sel, msg_mute, msg_curve_shape
            if (selected ~= nil) or (muted ~= nil) or (msg_curve_shape ~= nil) then -- Only unpack if gonna use, and do it only once!
                msg_sel, msg_mute, msg_curve_shape = UnpackFlags(flags)
            end
            
            -- check selected
            if selected ~= nil and not (msg_sel == selected) then
                goto continue
            end

            -- check muted
            if muted ~= nil and not (msg_mute == muted) then
                goto continue
            end

            -- Start event n filter: --- it is at the end so will only count message that passed all other filters
            if start and start.event_n then 
                event_n = event_n + 1
                if event_n < start.event_n then goto continue end -- if the event_n count is smaller than the desired event to start returning just continue to next
            end

            -- Step filter
            if step then 
                step_count = step_count + 1                
                if step_count%step ~= 0 then goto continue end 
            end

            -- Passed All filters congrats!

            if true then -- hm I cant just put return in the middle of a function. But I decided to use goto as lua dont have continue. and if it is here it is allright. so if true then return end 
                return  offset, offset_count, flags, msg, event_count, stringPos
            end

            ::continue::
        end 
        return nil -- Ends the iteration
    end    
end

function IterateMIDIBackwards(MIDIstring,miditype,ch,selected,muted,filter_midiend,start,step)
    local t = {}
    for offset, offset_count, flags, msg, event_count, stringPos in IterateMIDI(MIDIstring,miditype,ch,selected,muted,filter_midiend,start,step) do
        t[#t+1] = {}
        t[#t].offset = offset
        t[#t].flags = flags
        t[#t].msg = msg
        t[#t].offset_count = offset_count
        t[#t].event_count = event_count
        t[#t].stringPos = stringPos
    end
    local i = #t+1
    return function ()
        i = i - 1
        if i == 0 then return nil end
        return t[i].offset,t[i].offset_count,t[i].flags,t[i].msg,t[i].event_count,t[i].stringPos
    end
end


function IterateMIDINotes(take)
    local retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
    local noteidx = -1
    return function ()
        noteidx = noteidx + 1
        local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, noteidx)
        if retval then 
            return selected, muted, startppqpos, endppqpos, chan, pitch, vel, noteidx
        else
            return nil
        end        
    end    
end

---------------------
----------------- MIDI Table 
---------------------


---This function get the midi_table and return it to string packed formated to be feeded at MIDI_SetAllEvts
---@param midi_table any
---@return string
function PackMIDITable(midi_table)
    local packed_table = {}
    for i, value in pairs(midi_table) do
        local packed_midi = PackMIDIMessage(midi_table[i].msg.type, midi_table[i].msg.ch, midi_table[i].msg.val1, midi_table[i].msg.val2,midi_table[i].msg.text) -- Pack MIDI not text
        local packed_flags = PackFlags(midi_table[i].flags.selected, midi_table[i].flags.muted, midi_table[i].flags.curve_shape)
        packed_table[#packed_table+1] = string.pack("i4Bs4", midi_table[i].offset, packed_flags, packed_midi) 
    end
    return table.concat(packed_table) -- I didnt remove the last val at CreateMIDITable so everything should be here! If remove add it here, calculating offset.
end

---This function get the packed midi_table(.msg and .flags are already packed) and return it to string packed formated to be feeded at MIDI_SetAllEvts
---@param midi_table table midi_table packed
---@return string
function PackPackedMIDITable(midi_table)
    local packed_table = {}
    for i, value in pairs(midi_table) do
        packed_table[#packed_table+1] = string.pack("i4Bs4", midi_table[i].offset, midi_table[i].flags, midi_table[i].msg) 
    end
    return table.concat(packed_table) -- I didnt remove the last val at CreateMIDITable so everything should be here! If remove add it here, calculating offset.
end


---------------------
----------------- MIDI Table Handling 
---------------------

---Insert MIDI and a placeholder At the end of the table. The midi will happen at ppq from the start of the item. The place holder will compensate back to position the table endded. table needs to have .offset_count
---@param midi_table table table with all midi events
---@param ppq number  when in ppq insert the message
---@param midi_msg string midi message.
---@param flags string flags message.
function InsertMIDIUnsorted(midi_table,ppq,midi_msg,flags)
    local last_offset_count
    if #midi_table > 0  then
        last_offset_count = midi_table[#midi_table].offset_count -- ppq position of the last element
    else
        last_offset_count = 0
    end
    local new_offset = ppq - last_offset_count -- Diference between desired position and end. 
    TableInsertWithPlaceHolder(midi_table,new_offset,ppq,new_offset,midi_msg,flags,nil) -- Insert with new_offset and insert placeholder with -new_offset
end

---Insert MIDI and a placeholder At the end of the table. If want to change the value of something that already was in the list the place holder need to be positioned to compensate the diference over the original ppq. Using InsertMIDIUnsorted will give the wrong result
---@param midi_table table table with all midi events
---@param ppq number  when in ppq insert the message
---@param original_ppq number  when in ppq was the original message
---@param midi_msg string midi message.
---@param flags string flags message.
function SetMIDIUnsorted(midi_table,ppq,original_ppq,midi_msg,flags,pos)
    local last_offset_count
    if #midi_table > 0  then
        last_offset_count = midi_table[#midi_table].offset_count -- ppq position of the last element
    else
        last_offset_count = 0
    end
    local new_offset = ppq - last_offset_count -- Diference between desired position and end. 
    local delta = ppq - original_ppq 
    TableInsertWithPlaceHolder(midi_table,new_offset,ppq,delta,midi_msg,flags,pos) -- Insert with new_offset and insert placeholder with -new_offset
end

---Insert in a table with a place holder. This is the way to delete events. Place holder is always one key after compensating the delta so the offset of the next message dont need to change, or even calculate! e.g: insert a message 960ppq after previous message. would make next message be 960ppq latter. This function will insert the message with offset = 960 and a placeholder with offset = -960, so next message already is with the right offset.  
---@param midi_table table with all midi events
---@param offset number offset from last message 
---@param offset_count number optional total offset
---@param delta number distance in ppq from place holder. Inserting delta = offset. Setting delta = offset - old_offset!  negative is the place holder happens after delta ppq. positive place holder happens before delta ppq. 
---@param midi_msg any --midi message, packed
---@param flags any --flags message, packed
---@param pos any -- optional position on the list to be insert. pos = 3 will insert this message at position 3 and Place holder at 4 else will be added at the end of the list. with pos this is slower, optionally you can always insert at the end and calculate the delta from the last element and insert it at the end! 
function TableInsertWithPlaceHolder(midi_table,offset,offset_count,delta,midi_msg,flags,pos)
    local message = {offset = offset ,msg = midi_msg, flags = flags, offset_count = offset_count}
    local offset_count_holder = offset_count and (offset_count - delta) or nil
    local holder = {offset = -delta ,msg = '', flags = 0, offset_count = offset_count_holder}
    if not pos then
        midi_table[#midi_table+1] = message -- new_offset = offset + delta. new  difference from last midi message 
        midi_table[#midi_table+1] = holder-- put a place holder nothing message that get deleted where this message originally was. so dont need to sort next midi message
    else
        table.insert(midi_table,pos,message)
        table.insert(midi_table,pos+1,holder)
    end
end

---Use to delete elements that existed previusly, without needing to change any offset. Can also use SetMIDIUnsorted with a '' (empty string) at the midi_msg value. Can insert it a table as last position or change some element to placeholder(that will get deleted) in the list. If going to change put the pos of the element and dont put offset and offset_count
---@param midi_table new midi table to insert this event
---@param offset number offset from last message 
---@param offset_count number optional total offset
---@param pos number optional position in the new list to be changed to a place holder.
function InsertPlaceHolder(midi_table,offset,offset_count,pos)
    if pos then
        offset = midi_table[pos].offset
        offset_count = midi_table[pos].offset_count
    end
    pos = pos or (#midi_table+1)
    local holder = {offset = offset ,msg = '', flags = 0, offset_count = offset_count}
    midi_table[#midi_table+1] = holder
end

---Insert in the table normally without changing nothing (just to make a nice abstraction)
---@param midi_table table with all midi events
---@param offset number offset from last message 
---@param offset_count number optional total offset
---@param flags number --flags message, packed
---@param msg string midi message packed
function TableInsert(midi_table,offset,offset_count,flags,msg)
    midi_table[#midi_table+1] = { offset = offset, offset_count = offset_count, flags = flags, msg = msg}
end

---------------------
----------------- MIDI Message Pack 
---------------------

---Unpack a packed string MIDI message in different values
---@param msg string midi as packed string
---@return number msg_type midi message type: Note Off = 8; Note On = 9; Aftertouch = 10; CC = 11; Program Change = 12; Channel Pressure = 13; Pitch Vend = 14; text = 15. 
---@return number msg_ch midi message channel 1 based (1-16)
---@return number data2 databyte1 -- like note pitch, cc num
---@return number data3 databyte2 -- like note velocity, cc val. Some midi messages dont have databyte2 and this will return nill. For getting the value of the pitchbend do databyte1 + databyte2
---@return string text if message is a text return the text
---@return table allbytes all bytes in a table in order, starting with statusbyte. usefull for longer midi messages like text
function UnpackMIDIMessage(msg)
    local msg_type = msg:byte(1)>>4
    local msg_ch = (msg:byte(1)&0x0F)+1 --msg:byte(1)&0x0F -- 0x0F = 0000 1111 in binary. this is a bitmask. +1 to be 1 based

    local text
    if msg_type == 15 then
        text = msg:sub(3)
    end

    local val1 = msg:byte(2)
    local val2 = (msg_type ~= 15) and msg:byte(3) -- return nil if is text
    return msg_type,msg_ch,val1,val2,text,msg
end

---Receives numbers(0-255). or strings. and return them in a string as bytes
---@param ... number
---@return string
function PackMessage(...)
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

---Pack a midi message in a string form. Each character is a midi byte. Can receive as many data bytes needed. Just join midi_type and midi_ch in the status bytes and thow it in PackMessage. 
---@param midi_type number midi message type: Note Off = 8; Note On = 9; Aftertouch = 10; CC = 11; Program Change = 12; Channel Pressure = 13; Pitch Vend = 14; text = 15.
---@param midi_ch number midi ch 1-16 (1 based.)
---@param ... number sequence of data bytes can be number (will be converted to string(a character with the equivalent byte)) or can be a string that will be added to the message (useful for midi text where each byte is a character).
function PackMIDIMessage(midi_type,midi_ch,...)
    local midi_ch = midi_ch - 1 -- make it 0 based
    local status_byte = (midi_type<<4)+midi_ch -- where is your bitwise operation god now?
    return PackMessage(status_byte,...)
end

---Unpack flags into selected, muted, curve_shape
---@param flag number
---@return boolean selected is selected
---@return boolean muted is muted
---@return integer curve_shape curve type 0square, 1linear, 2slow start/end, 3fast start, 4fast end, 5bezier
function UnpackFlags(flag)
    local selected =  flag&1 == 1   -- AND operation with  1 (1 in binary) (return the first bit val)
    local muted =  flag&2 == 2      -- AND operation with 10 (2 in binary) (return the second bit val + 1 bit as 0 I could also move it to the void)
    -- cc_string
    local curve_shape = flag>>4 -- Void the first 4 bits as they dont matter for cc curve and get the value. If is flags from something without curve shape like notes will just return 0, as square
        
    return selected, muted, curve_shape
end

---Pack options into flags
---@param selected boolean is selected
---@param muted boolean is muted
---@param curve_shape number curve type 0square, 1linear, 2slow start/end, 3fast start, 4fast end, 5bezier
---@return integer flags flags number
function PackFlags(selected, muted, curve_shape)
    local flags = curve_shape and curve_shape<<4 or 0
    flags = flags|(muted and 2 or 0)|(selected and 1 or 0) -- if selected or muted are true return number. this is a OR operation flags|2or0|1or0 (2 = 10 ; 1 = 1)
    return flags
end


---------------------
----------------- MIDI Ticks // PPQ
---------------------

function GetTakePPQ(take)
    local sourceStartQN = reaper.MIDI_GetProjQNFromPPQPos(take, 0)
    local ppq = (0.5 + reaper.MIDI_GetPPQPosFromProjQN(take, sourceStartQN + 1))//1 
    return ppq
end


---Return the measure number(0 Based) from a position in ticks. If is the tick that start the measure/ end previous measure, it will return the measure starting number
---@param take MediaTake 
---@param ppq_pos number position in ticks
---@return number measure measure number 0 Based
function GetMeasureNumberFromPPQPos(take, ppq_pos)
    local pos = reaper.MIDI_GetProjTimeFromPPQPos( take, ppq_pos )
    local retval, measures, cml, fullbeats, cdenom = reaper.TimeMap2_timeToBeats( 0, pos )
    return measures
end

-- Not tested much
function CreateTickTable() -- From JS Multitool THANKS THANKS THANKS!
    -- After creating use like print(tTimeFromTick[take][960]) if it dont already have the value it will create and return. 
    local tTimeFromTick = {} 
    local tTickFromTime = {}
    setmetatable(tTimeFromTick, {__index = function(t, take) t[take] = setmetatable({}, {__index = function(tt, tick) 
                                                                                                    local time = reaper.MIDI_GetProjTimeFromPPQPos(take, tick + 0) -- TODO Make it work with Start in source (Start offset) Originally this 0 did the trick
                                                                                                    tt[tick] = time
                                                                                                    tTickFromTime[take][time] = tick
                                                                                                    return time 
                                                                                                end
                                                                                        }) return t[take] end})
                                                                                        
    setmetatable(tTickFromTime, {__index = function(t, take) t[take] = setmetatable({}, {__index = function(tt, time) 
                                                                                                    local tick = reaper.MIDI_GetPPQPosFromProjTime(take, time) - 0 -- TODO Make it work with Start in source (Start offset) Originally this 0 did the trick
                                                                                                    tt[time] = tick
                                                                                                    tTimeFromTick[take][tick] = time
                                                                                                    return tick 
                                                                                                end
                                                                                        }) return t[take] end})

    return tTimeFromTick, tTickFromTime -- Return related to project time
end

function CreateQNTable() -- From JS Multitool THANKS THANKS THANKS!
    -- After creating use like print(tTimeFromTick[take][960]) if it dont already have the value it will create and return. 
    local tQNFromTick = {} 
    local tTickFromQN = {}
    setmetatable(tQNFromTick, {__index = function(t, take) t[take] = setmetatable({}, {__index = function(tt, tick) 
                                                                                                    local time = reaper.MIDI_GetProjQNFromPPQPos(take, tick + 0) -- TODO Make it work with Start in source (Start offset) Originally this 0 did the trick
                                                                                                    tt[tick] = time
                                                                                                    tQNFromTick[take][time] = tick
                                                                                                    return time 
                                                                                                end
                                                                                        }) return t[take] end})
                                                                                        
    setmetatable(tTickFromQN, {__index = function(t, take) t[take] = setmetatable({}, {__index = function(tt, time) 
                                                                                                    local tick = reaper.MIDI_GetPPQPosFromProjQN(take, time) - 0 -- TODO Make it work with Start in source (Start offset) Originally this 0 did the trick
                                                                                                    tt[time] = tick
                                                                                                    tTickFromQN[take][tick] = time
                                                                                                    return tick 
                                                                                                end
                                                                                        }) return t[take] end})

    return tQNFromTick, tTickFromQN -- Return related to project time
end

function CreateStartMeasureTable() -- From JS Multitool THANKS THANKS THANKS!
    -- After creating use like print(tTimeFromTick[take][960]) if it dont already have the value it will create and return. 
    local tTimeFromTick = {} 
    local tTickFromTime = {}
    setmetatable(tTimeFromTick, {__index = function(t, take) t[take] = setmetatable({}, {__index = function(tt, tick) 
                                                                                                    local time = reaper.MIDI_GetPPQPos_StartOfMeasure( take, tick ) 
                                                                                                    tt[tick] = time
                                                                                                    tTickFromTime[take][time] = tick
                                                                                                    return time 
                                                                                                end
                                                                                        }) return t[take] end})
                                                                                        


    return tTimeFromTick
end

---Return the same position in another take.
---@param take1 MediaTake Take that will return the new positon.
---@param take2 MediaTake Take that provide the ppqpos. 
---@param take2_ppqPos number ppqpos in take2.
function  GetPPQPosFromTake1_FromPPQPosFromTake2(take1, take2, take2_ppqPos)
    local proj_qn = reaper.MIDI_GetProjQNFromPPQPos( take2, take2_ppqPos )
    return math.floor(reaper.MIDI_GetPPQPosFromProjQN( take1, proj_qn )+0.5)
end

---------------------
----------------- MIDI Count
---------------------

---Count Selected notes in a midi take
---@param take take reaper take
function CountSelectedNotes(take)
    local cnt = 0

    local retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts( take )
    for i = 0, notecnt - 1 do 
        local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, i )
        if selected then
            cnt = cnt + 1
        end
    end
    return cnt
end


---------------------
----------------- Get MIDI
---------------------


--- Notes 

--- Return a table with selected notes info. Per Item pitch = selected pitches. .interval = interval between notes. .vel = velocities. .len = length of the notes. .rhythm = ppq difference between notes. .groove = tables for each measured with notes copied, ppq diference from measure start and each note.
---@param take any
---@param IsGap boolean is gap turned on? Gap = get together events as an event.
---@param Gap number gap size in ppq
---@param IgnoreMuted boolean ignore muted notes?
---@return table
function CopyMIDIParameters(take,IsGap,Gap,IgnoreMuted) 
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
    for selected, muted, startppqpos, endppqpos, chan, pitch, vel in IterateMIDINotes(take) do
        if selected then
            if not IgnoreMuted or (IgnoreMuted and not muted) then -- rule out muted notes if IgnoreMuted is true
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

---Create a table contaning all selected MIDI note events; This Function don't work well with looped MIDI items, because idk how would be a good design for that situation. Should it get the notes in the first loop info? or at the longer loop? or at the last loop? The only difference is time, if I decided add the offset start to the start position of each note and multiply the notes. 
---Table Structure :  selected = is selected? , muted = is muted? , offset_count = note start in ppq, endppqpos = note end in ppq, chan = chan, pitch = pitch, vel = vel, start_time = proj start_time in sec, start_qn = note start in project qn, end_qn = note end in project qn, measure_pos = ppq delta from start measure and note start, measure_pos_qn = delta from start measure and note start in proj QN. noteidx = noteidx
---@param is_selected boolean only get selected notes
---@param ignore_muted boolean if true will ignore muted notes
---@param is_combine_items boolean if true will combine all editable takes into one table. if false will return a table with each editable take as a table.
---@param take_list table if take list then it will use it instead of editable takes
function CreateNotesTable(is_selected,ignore_muted,is_combine_items,take_list)
    local midi_editor = reaper.MIDIEditor_GetActive()
    local takes_table = {}
    local tTimeFromTick, tTickFromTime = CreateTickTable()

    local takes 
    if take_list then 
        takes = take_list
    else
        takes = {}
        for take in enumMIDITakes(midi_editor,true) do
            takes[#takes+1] = take
        end
    end

    for k, take in ipairs(takes) do
        takes_table[#takes_table+1] = {}

        local item  = reaper.GetMediaItemTake_Item(take)
        local item_start = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
        -- get the ppqpos of the start of the take (if there is a midi message before the start of the item then this message is ppq 0 reaper wont play it tho, I will filter notes that ends before the start of the item)
        local ppq_true_start = tTickFromTime[take][item_start]//1
        ------------ API
        for  selected, muted, startppqpos, endppqpos, chan, pitch, vel, noteidx in IterateMIDINotes(take) do -- Its faster than using Get all events
            -- filters
            if is_selected and not selected then
                goto continue
            end

            if ignore_muted and muted then
                goto continue
            end

            if endppqpos < ppq_true_start then
                goto continue
            end
            --get the time of the start of the note as the start of the item (if it is before the start of the item ). Just cropping the time of the note to the start of the item
            if startppqpos < ppq_true_start then
                startppqpos = ppq_true_start
            end
            --
            local start_time = tTimeFromTick[take][startppqpos]
            -- get qn from the project 
            local start_qn = reaper.MIDI_GetProjQNFromPPQPos( take, startppqpos )
            local end_qn = reaper.MIDI_GetProjQNFromPPQPos( take, endppqpos )
            -- get the delta of the note start and the start of the measure
            local measure_start =  reaper.MIDI_GetPPQPos_StartOfMeasure( take, startppqpos )
            local measure_pos = startppqpos - measure_start
            -- get the measue pos in qn
            local measure_pos_qn = start_qn - reaper.MIDI_GetProjQNFromPPQPos( take, measure_start )

            table.insert(takes_table[#takes_table], {selected = selected, muted = muted, offset_count = startppqpos, endppqpos = endppqpos, chan = chan, pitch = pitch, vel = vel, start_time = start_time, start_qn = start_qn, end_qn = end_qn, measure_pos = measure_pos, measure_pos_qn = measure_pos_qn, take = take, noteidx = noteidx})

            ::continue::
        end     
    end
    -- sort notes between takes.
    if is_combine_items then
        local combine_takes = {}
        -- add all notes to combine_takes
        for i = 1, #takes_table do -- iterate takes
            for j = 1, #takes_table[i] do -- iterate notes 
                table.insert(combine_takes,takes_table[i][j])
            end
        end
        -- sort it
        table.sort(combine_takes,function (a,b) return a.start_time < b.start_time end)
        takes_table = {combine_takes} -- put it inside a table to follow the same structure as the takes_table. takes_table[Takes][notesidx] 
    end
    return takes_table
end

-- Take a table with midi events information, like the one returned in CreateNotesTable and return a table with the same MIDI events but put close MIDI together in a table as one thing. uses qn on start_qn inside the note table
-- midi_table structure) midi_table[idx] = {..., start_qn = project qn start, ...}
---comment
---@param midi_table any table to get the midi messages. each event in the midi table need to have a start_qn index with the start position project position in QN
---@param event_size number if is_event will put close notes in one event. if not is_event each note is one event. measured in QN.
---@param is_event boolean put close notes in events
---@return table table with the same structure as midi_table but with the events grouped together.
function EventTogether(midi_table,event_size,is_event)
    local new_table = {}
    for index, take_table in ipairs(midi_table) do
        local last_start
        for idx, note_table in ipairs(take_table) do
            if not is_event or not last_start or note_table.start_qn > last_start + event_size then -- add new event
                new_table[#new_table+1] = {note_table}
            else -- continue last event
                table.insert(new_table[#new_table], note_table)
            end
            last_start = note_table.start_qn
        end
    end
    -- sort notes table inside events. per position and then pitch(bottom up)
    for index, value in ipairs(new_table) do -- iterate the events
        table.sort(value,function (a,b) return a.start_qn < b.start_qn or (a.start_qn == b.start_qn and a.pitch < b.pitch) end)        
    end

    return new_table
end

--- Simillar function as CopyMIDIParameters but is to be used with EventTogether, simillar function return the list of  pitch, interval, rhythm, measure_pos , velocity, len, pos used. Pos, rhythm, measure_pos, len are also available in QN, project QN based, instead of calculating per item ppq, good for cases where one item is with different playbackrate. Usefull for mixing takes. 
---@param take_table table table with all events tables with all midi notes info to get the parameters from. this take table can actually be a mixture made in EventTogether. Created in CreateNotesTable. structure of each note table is : offset_count = note start in ppq, endppqpos = note end in ppq, chan = chan, pitch = pitch, vel = vel, start_time = proj start_time in sec
---@param mark_muted_pitch boolean mark the parameters that comes from muted notes for pitch/intervals. for intervals it will mark if the second note is muted. 
---@param mark_muted_rhythms boolean mark the parameters that comes from muted notes. for rhythms it will mark if the second note is muted. 
---@param mark_muted_len boolean mark the parameters that comes from muted notes. 
---@param mark_muted_vel boolean mark the parameters that comes from muted notes. 
---@param mark_muted_pos boolean mark the parameters that comes from muted notes.
---@param mute_mark string identifier to be added to muted parameters
---@return table copy_list  copy_list.pitch = {{60,64,67},{60},{59}}  C major followed by C B. copy_list.rhythm = {{0,25,60},{960,50,12},{1080},{1080}}. If rhythm or interval start with a event with more than one notes then the values between the notes of the event will be insert at [0] , copy_list.interval[0] = {{3,4}}, copy_list.interval[1] = {{2,3,4}}, copy_list.interval[2] = {{5}}, in this case it starts with a minor chord goes 2 semitones up do anothe minor chord and makes a note 5 semitones up. Two chords at the first two events distance between events starts is the first value in a event table, the other values are for notes inside one element. The is also interval, groove, velocity, len. 
function CopyMIDIParametersFromEventList(take_table, mark_muted_pitch,mark_muted_rhythms,mark_muted_len,mark_muted_vel, mark_muted_pos, mute_mark)
--  offset_count = note start in ppq,
--  endppqpos = note end in ppq,
--  chan = chan,
--  pitch = pitch,
--  vel = vel,
--  start_time = proj start_time in sec
    mute_mark = mute_mark or 'm'

    local copy_list = {}
    copy_list.pitch = {}
    copy_list.interval = {} -- number of elements = number of notes - 1 (insert only the difference)
    copy_list.vel = {}
    copy_list.len = {}
    copy_list.len_qn = {}
    copy_list.rhythm = {}   -- number of elements = number of notes - 1 (insert only the difference)
    copy_list.rhythm_qn = {}   -- number of elements = number of notes - 1 (insert only the difference)
    copy_list.measure_pos = {}
    copy_list.measure_pos_qn = {}
    copy_list.pos = {}
    copy_list.pos_qn = {}
    

    for event_idx, event_list in ipairs(take_table) do
        -- add a new event table on all parameters the copy_list
        copy_list.pitch[event_idx] = {}
        copy_list.vel[event_idx] = {}
        copy_list.len[event_idx] = {}
        copy_list.len_qn[event_idx] = {}
        copy_list.measure_pos[event_idx] = {}
        copy_list.measure_pos_qn[event_idx] = {}
        copy_list.pos[event_idx] = {}
        copy_list.pos_qn[event_idx] = {}

        -- will always add index 0, but if there isnt more than one note at the first event, then it wont add nothing in it.
        copy_list.rhythm[event_idx-1] = {}
        copy_list.rhythm_qn[event_idx-1] = {}

        for note_idx, note_list in ipairs(event_list) do
            -- pitch        
            local pitch = tostring(math.floor(note_list.pitch))
            if mark_muted_pitch and note_list.muted then
                pitch = pitch .. mute_mark
            end
            table.insert(copy_list.pitch[#copy_list.pitch],pitch) -- insert at the last event table on table copy_list.pitch

            -- velocity
            local vel = tostring(math.floor(note_list.vel))
            if mark_muted_vel and note_list.muted then
                vel = vel .. mute_mark
            end
            table.insert(copy_list.vel[#copy_list.vel],vel) 

            -- measure pos
            local measure_pos = tostring(math.floor(note_list.measure_pos))
            if mark_muted_rhythms and note_list.muted then
                measure_pos = measure_pos .. mute_mark
            end
            table.insert(copy_list.measure_pos[#copy_list.measure_pos],measure_pos)

            -- measure pos QN
            local measure_pos_qn = tostring(note_list.measure_pos_qn)
            if mark_muted_rhythms and note_list.muted then
                measure_pos_qn = measure_pos_qn .. mute_mark
            end
            table.insert(copy_list.measure_pos_qn[#copy_list.measure_pos_qn],measure_pos_qn)                

            -- length
            local len = tostring(math.floor(note_list.endppqpos-note_list.offset_count))
            if mark_muted_len and note_list.muted then
                len = len .. mute_mark
            end
            table.insert(copy_list.len[#copy_list.len],len)

            -- length_qn
            local len_qn = tostring(note_list.end_qn-note_list.start_qn)
            if mark_muted_len and note_list.muted then
                len_qn = len_qn .. mute_mark
            end
            table.insert(copy_list.len_qn[#copy_list.len_qn],len_qn)

            -- pos
            local pos = tostring(math.floor(note_list.offset_count))
            if mark_muted_pos and note_list.muted then
                pos = pos .. mute_mark
            end
            table.insert(copy_list.pos[#copy_list.pos],pos) 

            -- pos_qn
            local pos_qn = tostring(note_list.start_qn)
            if mark_muted_pos and note_list.muted then
                pos_qn = pos_qn .. mute_mark
            end
            table.insert(copy_list.pos_qn[#copy_list.pos_qn],pos_qn)

            --rhythm
            if event_idx > 1 and note_idx == 1 then -- insert the interval/rhythm between events
                -- in ppq
                local events_rhythm = note_list.offset_count - take_table[event_idx-1][1].offset_count -- diference between current note and first note on last event 
                events_rhythm = tostring(math.floor(events_rhythm))
                if mark_muted_rhythms and note_list.muted then
                    events_rhythm = events_rhythm .. mute_mark
                end
                table.insert(copy_list.rhythm[#copy_list.rhythm],events_rhythm) 
                -- in qn
                local events_rhythm_qn = note_list.start_qn - take_table[event_idx-1][1].start_qn -- diference between current note and first note on last event
                events_rhythm_qn = tostring(events_rhythm_qn)
                if mark_muted_rhythms and note_list.muted then
                    events_rhythm_qn = events_rhythm_qn .. mute_mark
                end
                table.insert(copy_list.rhythm_qn[#copy_list.rhythm_qn],events_rhythm_qn)

            elseif note_idx > 1 then -- if there is more notes in this event list
                local inside_rhythm =  note_list.offset_count - event_list[note_idx-1].offset_count
                inside_rhythm = tostring(math.floor(inside_rhythm))
                if mark_muted_rhythms and note_list.muted then
                    inside_rhythm = inside_rhythm .. mute_mark
                end
                table.insert(copy_list.rhythm[#copy_list.rhythm],inside_rhythm) 
                -- in qn
                local inside_rhythm_qn =  note_list.start_qn - event_list[note_idx-1].start_qn
                inside_rhythm_qn = tostring(inside_rhythm_qn)
                if mark_muted_rhythms and note_list.muted then
                    inside_rhythm_qn = inside_rhythm_qn .. mute_mark
                end
                table.insert(copy_list.rhythm_qn[#copy_list.rhythm_qn],inside_rhythm_qn)
            end
        end
    end

    -- sort the pitch table
    for event_idx, event_table in ipairs(copy_list.pitch) do
        table.sort(event_table, function(a,b)
            return tonumber(a:match('%d*')) < tonumber(b:match('%d*')) 
        end)        
    end 
    --  calculate intervals
    for event_idx, event_table in ipairs(copy_list.pitch) do
        -- will always add index 0, but if there isnt more than one note at the first event, then it wont add nothing in it.
        copy_list.interval[event_idx-1] = {}

        for note_idx, note_pitch in ipairs(event_table) do
            if event_idx > 1 and note_idx == 1 then -- insert the interval/rhythm between events
                -- get the number from the string in copy_list.pitch
                local last_pitch = copy_list.pitch[event_idx-1][note_idx]:match('%d*')
                local last_muted = copy_list.pitch[event_idx][note_idx]:match(mute_mark..'$') -- check if there is the mute mark at the end
                local note_pitch = note_pitch:match('%d*') -- current note
                local events_interval = math.floor(note_pitch - last_pitch) -- diference between current note and first note on last event. TODO get the number from copy_list.pitch[event_idx-1][1]  string else it will BUG
                if mark_muted_pitch and last_muted then
                    events_interval = events_interval .. mute_mark
                end
                table.insert(copy_list.interval[#copy_list.interval], events_interval)

            elseif note_idx > 1 then -- if there is more notes in this event list
                local last_pitch = event_table[note_idx-1]:match('%d*')
                local last_muted = event_table[note_idx]:match(mute_mark..'$') -- check if there is the mute mark at the end
                local note_pitch = note_pitch:match('%d*')
                local inside_interval = math.floor(note_pitch - last_pitch)
                if mark_muted_pitch and last_muted then
                    inside_interval = inside_interval .. mute_mark
                end
                table.insert(copy_list.interval[#copy_list.interval],inside_interval) 
            end
        end       
    end 


    return copy_list
end


---Make a list of all pitch classes, without repetition.
---@param is_selected boolean If true, only selected notes will be used.
---@param filter_mute boolean If true, muted notes will be ignored.
---@param take_list table optional pass a table with takes it will use it, else it will get the editables takes at the active MIDI Editor.
---@return table
function GetSelectedPitchClasses( is_selected,filter_mute,take_list)
    local takes 
    local midi_editor = reaper.MIDIEditor_GetActive()
    if take_list then 
        takes = take_list
    else
        takes = {}
        for take in enumMIDITakes(midi_editor,true) do
            takes[#takes+1] = take
        end
    end
    
    local pitch_classes = {}
    local added_values = {}
    for k, take in ipairs(takes) do
        for selected, muted, startppqpos, endppqpos, chan, pitch, vel, noteidx in IterateMIDINotes(take) do
            if (is_selected and selected) and ((not filter_mute) or (filter_mute and not muted)) then
                -- get pitch class
                local pitch_class = pitch % 12
                -- add pitch class to table
                if not added_values[pitch_class] then
                    table.insert(pitch_classes,pitch_class)
                    added_values[pitch_class] = true
                end
            end
        end
    end

    table.sort(pitch_classes)

    return pitch_classes    
end

---Make a list of all pitches, without repetition.
---@param is_selected boolean If true, only selected notes will be used.
---@param filter_mute boolean If true, muted notes will be ignored.
---@param take_list table optional pass a table with takes it will use it, else it will get the editables takes at the active MIDI Editor.
---@return table
function GetSelectedPitches(is_selected,filter_mute,take_list)
    local takes 
    local midi_editor = reaper.MIDIEditor_GetActive()
    if take_list then 
        takes = take_list
    else
        takes = {}
        for take in enumMIDITakes(midi_editor,true) do
            takes[#takes+1] = take
        end
    end

    local pitches = {}
    local added_values = {}
    for k, take in ipairs(takes) do
        for selected, muted, startppqpos, endppqpos, chan, pitch, vel, noteidx in IterateMIDINotes(take) do
            if ((not is_selected) or (is_selected and selected)) and ((not filter_mute) or (filter_mute and not muted)) then
                -- add pitch class to table
                if not added_values[pitch] then
                    table.insert(pitches,pitch)
                    added_values[pitch] = true
                end
            end
        end
    end

    table.sort(pitches)

    return pitches    
end

---------------------
----------------- Set MIDI
---------------------
--- Create an MIDI item at track and pos using the note events inside event_list, event_list are created with CreateNotesTable() and EventTogether() functions.
---@param track Track Track where the MIDI item will be created
---@param pos_qn number Position in QN where the MIDI item will be created
---@param event_list table Table with the note events to be created
function CreateMIDIItemFromEventList(event_list, track, pos_qn)
    local new_midi = {}
    local first_note_pos = event_list[1][1].start_qn
    local last_note_end = event_list[#event_list][#event_list[#event_list]].end_qn
    local first_note_offset_count = event_list[1][1].offset_count
    local len = last_note_end - first_note_pos
    local midi_item = reaper.CreateNewMIDIItemInProj( track, pos_qn, pos_qn + len, true )
    local take = reaper.GetActiveTake(midi_item)
    for ev_idx, event_table in ipairs(event_list) do -- Loop events
        for note_idx, note_table in ipairs(event_table) do -- Loop notes
            -- note on
            local msg_on = PackMIDIMessage(9,note_table.chan+1,note_table.pitch,note_table.vel)
            local pos_on = note_table.offset_count - first_note_offset_count -- use the first note ppq as an offset
            local flags = PackFlags(note_table.selected, note_table.muted)
            InsertMIDIUnsorted(new_midi, pos_on, msg_on, flags )
            -- note off
            local msg_off = PackMIDIMessage(8,note_table.chan+1,note_table.pitch,0)
            local pos_off = note_table.endppqpos -first_note_offset_count
            InsertMIDIUnsorted(new_midi, pos_off, msg_off, flags )
        end
    end

    local midi_str = PackPackedMIDITable(new_midi)
    reaper.MIDI_SetAllEvts(take, midi_str)
    reaper.MIDI_Sort(take)
end

---------------------
-- Get Meta Events --
---------------------

---Get the meta event msg of a noteidx in take.
---@param take take MediaTake
---@param noteidx number index of the note in the take. (0 based)
---@return string msg return the message of the meta event. If don't find any return nil.
function GetMIDINoteMetaEvents(take, noteidx)
    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, noteidx)
    local retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
    local meta_table = BinarySearch_MIDITxt(startppqpos, take, textsyxevtcnt) 
    if not meta_table then return nil end
    for index, meta in ipairs(meta_table) do
        if meta.msg ~= '' then
            local meta_ch, meta_pitch = meta.msg:match('NOTE (%d+) (%d+)')
            if tonumber(meta_ch) == chan and tonumber(meta_pitch) == pitch then
                return meta.msg
            end
        end
    end
    return nil
end

---
---Make a binary search in take, looking for the MIDISysex that happens at desired_ppqpos. 
---@param desired_ppqpos number time in ppq where should be an Sysex event.
---@param take take the MIDI take 
---@param textsyxevtcnt number the count of text sysex events in the take. returned by reaper.MIDI_CountEvts(take)
---@return table t return the table with the sysex messages that happens at desired_ppqpos. Each Sysex is inside a table contaning all their info from MIDI_GetTextSysexEvt {selected = selected, muted = muted, ppqpos = ppqpos, type = type, msg = msg}
function BinarySearch_MIDITxt(desired_ppqpos, take, textsyxevtcnt)
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

---------------------
----------------- MIDI MISC
---------------------

--- Reorder MIDI Notes ON/OFF that start/end at the same time.
---@param take MediaTake the MIDI take
---@param bottomup boolean if true, the notes with lower pitch will be first. If false, the notes with higher pitch will be first.
---@param sort boolean sort the MIDI at the end? If this is going to be used in the middle of another function makes sense to sort only once
function SortNotes(take,bottomup,sort) 
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
            InsertMIDIUnsorted(new_midi_table,value.offset_count,value.midimsg,value.flags)
            if value.meta then
                InsertMIDIUnsorted(new_midi_table,value.meta.offset_count,value.meta.midimsg,value.meta.flags)
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
    for offset, offset_count, flags, midimsg, stringPos in IterateAllMIDI(MIDIstr,false) do
        local msg_type,msg_ch,val1,val2,text,msg = UnpackMIDIMessage(midimsg)
        if msg_type == 9 and val2 > 0 then -- noteon

            wait_start, wait_end, last_start, new_table = try_to_add_to_table(new_table,offset_count,wait_start,wait_end,last_start)
            
            -- get metamessages
            local meta
            do 
                local offset2, flags2, msg2, stringPos2 = string.unpack("i4Bs4", MIDIstr, stringPos)
                if offset2 == 0 then
                    local msg_type2,msg_ch,val1,val2,text2,msg = UnpackMIDIMessage(msg2)
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
                InsertMIDIUnsorted(new_table,offset_count,midimsg,flags)
            end
        else
            if msg_type == 11 and val1 == 123 then -- all notes off
                sort_wait_table(wait_start,bottomup,new_table)
                sort_wait_table(wait_end,bottomup,new_table)
                InsertMIDIUnsorted(new_table,offset_count,midimsg,flags)
            else
                InsertMIDIUnsorted(new_table,offset_count,midimsg,flags)
            end
        end        
    end


    local new_str = PackPackedMIDITable(new_table)
    reaper.MIDI_SetAllEvts(take, new_str)
    if sort then
        reaper.MIDI_Sort(take)
    end
end

---------------------
----------------- Get MIDI Input
---------------------

---Get MIDI input. Use for get MIDI between defer loops.
---@param midi_last_retval number need to store the last MIDI retval from MIDI_GetRecentInputEvent. Start the script with `MIDILastRetval = reaper.MIDI_GetRecentInputEvent(0)` and feed it here. Optionally pass nill here and it will create a global variable called "MIDILastRetval_Hidden" and manage that alone. 
---@return table midi_table midi table with all the midi values. each index have another table = {msg = midi message, ts = time, device = midi device idx}
---@return number midi_last_retval updated reval number.
function GetMIDIInput(last_retval)
    local idx = 0
    local first_retval
    local midi_table = {}
    local is_save_hidden_retval -- if not last_retval then it will save it in a global variable MIDILastRetval_Hidden and use it later

    -- if last_retval == true then it will manage the retval alone.
    if not last_retval then
        if not MIDILastRetval_Hidden then
            MIDILastRetval_Hidden = reaper.MIDI_GetRecentInputEvent(0)
            last_retval = MIDILastRetval_Hidden
        else 
            last_retval = MIDILastRetval_Hidden
        end
        is_save_hidden_retval = true
    end
    -- Get all recent inputs
    while true do
        local retval, msg, ts, device_idx = reaper.MIDI_GetRecentInputEvent(idx)
        if idx == 0 then
            first_retval = retval
        end

        if retval == 0 or retval == last_retval then
            last_retval = first_retval
            if is_save_hidden_retval then 
                MIDILastRetval_Hidden = first_retval
            end
            return midi_table, last_retval
        end
        midi_table[#midi_table+1] = {msg = msg, ts = ts, device = device_idx}
        
        idx = idx + 1
    end
end



------------
----- Depreciated Cool Idea to make a table with all events, it was too slow, might try it again using the place holder technique to insert/set/delete events.
------ The current technique is slow because it first iterate all events make a list of all things then user iterate that and make changes using Insert Set Delete functions.
--- 2 problems
--- 1 and Worst: The  insert/set/delete dont use the place holder technique, instead they look for next event previous event for changing ppq. This is very slow, even using binary search. This could be improved by using the place holder technique.
--- 2 uncessary loops. Some things could be obtain in just one IterateAllMIDI. But maybe this compensates for easines.
------------

-- Receives MIDIstring and returns a table user use to insert, set, delete, modify events. 
-- Table structure:
-- .offset = offset from last event (dont try to change this directly! use insert, delete, set). When packing to set all events it will use this info to build the output MIDI
-- .offset_Count = offset from item start (dont try to change this directly! use insert, delete, set). Just for reference and using in insert midi, wont be used to build the outputed MIDI.
-- .flags = table with flags options unpacked 
    -- flags.selected is selected
    -- flags.muted is muted
    -- flags.curve_shape which curve shape  0square, 1linear, 2slow start/end, 3fast start, 4fast end, 5bezier
-- .msg = table with midi message unpacked 
    -- msg.type = midi message type 
    -- msg.ch = midi message channel
    -- msg.val1 = midi message databyte 1
    -- msg.val2 = midi message databyte 2
    -- msg.text = midi text
-- .stringPos
---@param MIDIstring any
---@return table
function CreateMIDITable(MIDIstring)
    local t = { }
    for offset, offset_count, flags, msg, stringPos in IterateAllMIDI(MIDIstring,false) do -- should I remove the last val? NO! User should avoid it. If remove when I pack back it would be missing, unless I always add the message there
        local type, ch, val1, val2, text = UnpackMIDIMessage(msg)
        local selected, muted, curve_shape = UnpackFlags(flags)
        t[#t+1] = {}
        t[#t].offset = offset 
        t[#t].offset_count = offset_count -- 
        t[#t].flags = {
            selected = selected,
            muted = muted,
            curve_shape = curve_shape
        }
        t[#t].msg = {
            type = type,
            ch = ch,
            val1 = val1,
            val2 = val2,
            text = text
        }
        t[#t].stringPos = stringPos -- just for the sake of it (probably wont going to use)
    end
    return t
end

function CreatePackedMIDITable(MIDIstring)
    local new_table = {}
    for offset, offset_count, flags, msg, stringPos in IterateAllMIDI(MIDIstring) do
        --Unpack MIDI
        new_table[#new_table+1] = {offset_count = offset_count , offset = offset ,msg = msg, flags = flags} -- new_offset = offset + delta. new  difference from last midi message
    end
    return new_table
end

---Perform a binary searach on the midi_table to find the message that comes before on in time with ppq argument.Return the last value: 0 if is before the first value, 1 if val1<=ppq<val2, 2 val<=ppq<val3. Insert the Midi message at index result+1.
---@param midi_table any
---@param ppq any
---@return number
function BinarySearchInMidiTable(midi_table,ppq)
    local floor = 1
    local ceil = #midi_table
    local i = math.floor(ceil/2)
    -- Try to get in the edges after the max value and before the min value
    if midi_table[#midi_table].offset_count <= ppq then return #midi_table end -- check if it is after the last midi_table value 
    if midi_table[1].offset_count > ppq then return 0 end --check if is before the first value. return 0 if it is
    -- Try to find in between values
    while true do
        -- check if is between midi_table and midi_table[i+1]
        if midi_table[i+1] and midi_table[i].offset_count <= ppq and ppq <= midi_table[i+1].offset_count then return i end -- check if it is in between two values

        -- change the i (this is not the correct answer)
        if midi_table[i].offset_count > ppq then
            ceil = i
            i = ((i - floor) / 2) + floor
            i = math.floor(i)
        elseif midi_table[i].offset_count < ppq then
            floor = i
            i = ((ceil - i) / 2) + floor
            i = math.ceil(i)
        end    
    end
end

---Calculate the ppq diference from ppq and midi_table[last_idx] and midi_table[last_idx+1] 
---@param midi_table table
---@param last_idx number
---@param ppq number
---@return number
---@return number
function CalculatePPQDifPrevNextEvnt(midi_table,last_idx,ppq)
    local dif_prev, dif_next
    if last_idx > 0 then -- calculate the difference of the previous message. check if there is a previous element
        dif_prev = ppq - midi_table[last_idx].offset_count -- alternative is to calculate using just offset of the next message - dif prev message. this way is faster
    else 
        dif_prev = ppq --return ppq as is the offset from the item start
    end

    if last_idx < #midi_table then --calculate the difference to the next message. check if there is a next element.
        dif_next = midi_table[last_idx+1].offset_count - ppq 
    else
        dif_next = 0
    end
    return dif_prev, dif_next
end

---Insert a midi midi_msg at ppq in the midi_table. Insert at the right index. And adjusting offsets. Slow. 
---@param midi_table table table with all midi events
---@param pqp number when in ppq insert the message
---@param midi_msg string midi message packed or not. 
---@param flags number flags packed or not
function InsertMIDI(midi_table,ppq,midi_msg,flags)
    --Get idx of prev event
    local last_idx, dif_prev, dif_next
    if #midi_table > 0 then
        last_idx = BinarySearchInMidiTable(midi_table,ppq)
        -- calculate dif of prev event and next evt 
        dif_prev, dif_next = CalculatePPQDifPrevNextEvnt(midi_table,last_idx,ppq)
    else
        dif_prev, dif_next = ppq, 0
        last_idx = 0
    end
    local insert_idx = last_idx + 1

    --create the midi midi_msg table. I used this before to always insert unpacked now I insert the same user insert here
    --[[     if type(midi_msg) == 'string' then -- If put midi msg packed. but please dont! 
            local midi_type, ch, val1, val2, text = UnpackMIDIMessage(midi_msg)
            midi_msg = {
                type = midi_type,
                ch = ch,
                val1 = val1,
                val2 = val2,
                text = text
            }
        end
        --create the midi midi_msg table
        if type(flags) == 'number' then -- If put flag packed. but please dont! 
            local selected, muted, curve_shape = UnpackFlags(flags)
            flags = {
                selected = selected,
                muted = muted,
                curve_shape = curve_shape
            }
        end ]]

    --create the msg table
    local msg_table = {
        offset = dif_prev,
        offset_count = ppq,
        flags = flags,
        msg  = midi_msg
    }
    --adjust next midi message offset
    if midi_table[last_idx+1] then
        midi_table[last_idx+1].offset = dif_next
    end
    --insert it 
    table.insert(midi_table,insert_idx,msg_table) -- dont need to return as it is using the same table 
end

---comment
---@param midi_table  table table with all midi events
---@param event_n number event number
function DeleteMIDI(midi_table,event_n)
    if midi_table[event_n+1] then
        midi_table[event_n+1].offset = midi_table[event_n].offset + midi_table[event_n+1].offset 
    end
    table.remove(midi_table,event_n)
end

function SetMIDI(midi_table,event_n,ppq,flags,midi_msg)
    if type(flags) == "table" then
        for key, value in pairs(flags) do
            midi_table[event_n].flags[key] = value
        end
    elseif type(flags) == "string" then -- packed insert everything
        midi_table[event_n].flags = flags
    end

    if type(midi_msg) == "table" then
        for key, value in pairs(midi_msg) do
            midi_table[event_n].msg[key] = value
        end
    elseif type(midi_msg) == "string" then -- packed insert everything
        midi_table[event_n].msg = midi_msg
    end

    if ppq then
        local midi_msg = midi_table[event_n].msg
        local flags = midi_table[event_n].flags
        DeleteMIDI(midi_table,event_n)
        InsertMIDI(midi_table,ppq,midi_msg,flags)
    end
end

