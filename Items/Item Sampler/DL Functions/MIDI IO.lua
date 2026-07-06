--@noindex
--version: 0.0

DL = DL or {}
DL.midi_io = {}

---------------------
----------------- Get MIDI Input
---------------------

local last_retval
---Get MIDI input. Use for get MIDI between defer loops.
---@return table midi_table midi table with all the return values from MIDI_GetRecentInputEvent. Each index have another table = {retval = retval, msg = midi message, ts = time, device = midi device idx, proj_time = project time or -1, proj_loop = proj_loop}. First index is the most recent message second is the next etc... 
function DL.midi_io.GetInput()
    local idx = 0
    local first_retval
    local midi_table = {}

    last_retval = last_retval or reaper.MIDI_GetRecentInputEvent(0)

    -- Get all recent inputs
    while true do
        local retval, msg, ts, device_idx, proj_time, proj_loop = reaper.MIDI_GetRecentInputEvent(idx)
        if idx == 0 then
            first_retval = retval
        end

        if retval == 0 or retval == last_retval then
            last_retval = first_retval
            return midi_table
        end
        midi_table[#midi_table+1] = {msg = msg, ts = ts, device = device_idx, proj_time = proj_time, proj_loop = proj_loop, retval = retval}
        
        idx = idx + 1
    end
end

---------------------
----------------- Check with midi table 
---------------------

--- Check the MIDIInput input table if it triggered(same type, channel, device, and if cc then val2 > 60) with the values at midi_table. 
---@param midi_table table midi table with the values to check if match {device = idx, type = midi_type, val1 = note/cc, ch}. device, ch, val1 are optional.
---@param midi_input table table with midi input get at GetMIDIInput
---@return boolean
function DL.midi_io.TriggerCheck(midi_table, midi_input)
    local midi_trigger = false
    if midi_table.type and #midi_input > 0 then
        for index, input_midi_table in ipairs(midi_input) do
            local msg_input = input_midi_table.msg
            local msg_type,msg_ch,val1,val2,text,msg = DL.midi.UnpackMIDIMessage(msg_input)
            if msg_type ~= midi_table.type then goto continue end
            if msg_type == 11 and val2 < 60 then goto continue end
            if midi_table.val1 and val1 ~= midi_table.val1 then goto continue end
            if midi_table.ch and msg_ch ~= midi_table.ch then goto continue end
            if midi_table.device and input_midi_table.device ~= midi_table.device then goto continue end
            midi_trigger = true
            break
            ::continue::
        end
    end
    return midi_trigger
end

--- Check the MIDIInput input table if it triggered(same type, channel, device) with the values at midi_table. Return the midi value 
---@param midi_table table midi table with the values to check if match {device = idx, type = midi_type, val1 = note/cc, ch}. device, ch, val1 are optional.
---@param midi_input table table with midi input get at GetMIDIInput
---@return boolean retval found some input?
---@return number? databyte2 databyte2
---@return table? msg_t midi table that triggered it {msg = msg, ts = ts, device = device_idx, proj_time = proj_time, proj_loop = proj_loop, retval = retval}. If more than one will return only the sooner.
function DL.midi_io.InputCheck(midi_table, midi_input)
    local retval, databyte2, msg_t = false, nil, nil
    if midi_table.type and #midi_input > 0 then
        for index, input_midi_table in ipairs(midi_input) do
            local msg_input = input_midi_table.msg
            local msg_type,msg_ch,val1,val2,text = DL.midi.UnpackMIDIMessage(msg_input)
            if msg_type ~= midi_table.type then goto continue end
            if midi_table.val1 and val1 ~= midi_table.val1 then goto continue end
            if midi_table.ch and msg_ch ~= midi_table.ch then goto continue end
            if midi_table.device and input_midi_table.device ~= midi_table.device then goto continue end
            msg_t = input_midi_table
            databyte2 = val2
            retval = true
            break
            ::continue::
        end
    end
    return retval, databyte2, msg_t
end


