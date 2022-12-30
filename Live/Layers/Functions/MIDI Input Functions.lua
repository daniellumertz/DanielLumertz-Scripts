--@noindex
-- version 0.0.0
-- changelog

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



---------------------
----------------- Check with midi table 
---------------------


--- Check the MIDIInput input table if it triggered(same type, channel, device, and if cc then val2 > 60) with the values at midi_table. 
---@param midi_table table midi table with the values to check if match {device = idx, type = midi_type, val1 = note/cc, ch}. device, ch, val1 are optional.
---@param midi_input table table with midi input get at GetMIDIInput
---@return boolean
function CheckMIDITrigger(midi_table, midi_input)
    local midi_trigger = false
    if midi_table.type and #midi_input > 0 then
        for index, input_midi_table in ipairs(midi_input) do
            local msg_input = input_midi_table.msg
            local msg_type,msg_ch,val1,val2,text,msg = UnpackMIDIMessage(msg_input)
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
---@return boolean
function CheckMIDIInput(midi_table, midi_input)
    local midi_trigger = false
    if midi_table.type and #midi_input > 0 then
        for index, input_midi_table in ipairs(midi_input) do
            local msg_input = input_midi_table.msg
            local msg_type,msg_ch,val1,val2,text,msg = UnpackMIDIMessage(msg_input)
            if msg_type ~= midi_table.type then goto continue end
            if midi_table.val1 and val1 ~= midi_table.val1 then goto continue end
            if midi_table.ch and msg_ch ~= midi_table.ch then goto continue end
            if midi_table.device and input_midi_table.device ~= midi_table.device then goto continue end
            midi_trigger = val2
            break
            ::continue::
        end
    end
    return midi_trigger
end

---------------------
----------------- MIDI Learn GUI
---------------------

---Basic MIDI GUI for Popups. used at script : layers and Goto
---@param midi_table table midi table with the values to check if match {device = idx, type = midi_type, val1 = note/cc, ch}. device, ch, val1 are optional.
function MIDILearn(midi_table)
    reaper.ImGui_Text(ctx, 'MIDI:')
    local learn_text = midi_table.is_learn and 'Cancel' or 'Learn'
    if reaper.ImGui_Button(ctx, learn_text, -FLTMIN) then
        midi_table.is_learn = not midi_table.is_learn
    end
    ToolTip(UserConfigs.tooltips,'Control this parameter via MIDI.')

    if midi_table.is_learn then
        if MIDIInput[1] then
            local msg_type,msg_ch,val1 = UnpackMIDIMessage(MIDIInput[1].msg)
            if msg_type == 9 or msg_type == 11 or msg_type == 8 then 
                midi_table.type = ((msg_type == 9 or msg_type == 8) and 9) or 11
                midi_table.ch = msg_ch
                midi_table.val1 = val1
                midi_table.device = MIDIInput[1].device
                midi_table.is_learn = false
            end
        end
    end
    
    local w = reaper.ImGui_GetContentRegionAvail(ctx)
    local x_pos = w - 10 -- position of X buttons
    if midi_table.type then 
        local name_type = midi_table.type == 9 and 'Note' or 'CC'
        ImPrint(name_type..' : ',midi_table.val1)
        reaper.ImGui_SameLine(ctx,x_pos)
        if reaper.ImGui_Button(ctx, 'X##all') then
            midi_table.type = nil
            midi_table.ch = nil
            midi_table.val1 = nil
            midi_table.device = nil
            midi_table.is_learn = false
        end
        ToolTip(UserConfigs.tooltips,'Remove the MIDI follower.')
    end

    if midi_table.ch then 
        ImPrint('Channel : ',midi_table.ch)
        reaper.ImGui_SameLine(ctx,x_pos)
        if reaper.ImGui_Button(ctx, 'X##ch') then
            midi_table.ch = nil
        end
        ToolTip(UserConfigs.tooltips,'Remove the channel filter.')
    end  

    if midi_table.device then 
        local retval, device_name = reaper.GetMIDIInputName(midi_table.device, '')
        ImPrint('Device : ',device_name)
        reaper.ImGui_SameLine(ctx,x_pos)
        if reaper.ImGui_Button(ctx, 'X##dev') then
            midi_table.device = nil
        end
        ToolTip(UserConfigs.tooltips,'Remove the device filter.')
    end
    -- Optionally add a midi curve editor here
end
