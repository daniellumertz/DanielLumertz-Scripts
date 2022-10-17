--@noindex
---Drop the resolution of the parameters
---@param pitch_settings table table with the pitch settings 
---@param rhythm_settings table table with the rhythm settings
---@param vel_settings table table with the velocity settings
---@param parameters table table with the events tables with the parameters
function DropResolution(pitch_settings,rhythm_settings,vel_settings,param_table,mute_symbol)
    if pitch_settings.drop  then -- if drop resolution and mode == 1  will drop the resolution to pitch classes 0 based (0 - pitch_settings.drop)
        if pitch_settings.mode == 1 then 
            for event_idx, event_table in ipairs(param_table.pitch) do
                local used_pitch = {}
                for pitch_idx, pitch in ipairs(event_table) do
                    local pitch, is_mute = ParameterStringToVals(pitch,mute_symbol)
                    local new_pitch  = pitch % pitch_settings.drop
                    if not TableHaveValue(event_table,new_pitch) then -- In case there is more than one pitch of the same class.
                        if is_mute then 
                            new_pitch = new_pitch..mute_symbol
                        end
                        table.insert(used_pitch,new_pitch)
                        event_table[pitch_idx] = new_pitch
                    end
                end
            end
        elseif pitch_settings.mode == 2 then
            for event_idx, event_table in ipairs(param_table.interval) do
                for int_idx, interval in ipairs(event_table) do
                    local interval, is_mute = ParameterStringToVals(interval,mute_symbol)
                    local is_negative = interval < 0
                    interval = (math.abs(interval) % pitch_settings.drop) * ((is_negative and -1) or 1)
                    if is_mute then 
                        interval = interval..mute_symbol
                    end
                    event_table[int_idx] = interval
                end
            end
        end
    end

    if rhythm_settings.drop then
        local function quantize_rhythm(rhythm_qn)
            local rhythm_qn, is_mute = ParameterStringToVals(rhythm_qn,mute_symbol)
            local new_rhythm_qn = QuantizeNumber(rhythm_qn,rhythm_settings.drop)
            if is_mute then 
                new_rhythm_qn = new_rhythm_qn..mute_symbol
            end
            return new_rhythm_qn
        end

        if rhythm_settings.mode == 1 then
            for event_idx, event_table in ipairs(param_table.rhythm_qn) do
                for rhythm_idx, rhythm_qn in ipairs(event_table) do
                    local new_rhythm_qn = quantize_rhythm(rhythm_qn)
                    event_table[rhythm_idx] = new_rhythm_qn
                end
            end
        elseif rhythm_settings.mode == 2 then
            for event_idx, event_table in ipairs(param_table.measure_pos_qn) do
                for rhythm_idx, rhythm_qn in ipairs(event_table) do
                    local new_rhythm_qn = quantize_rhythm(rhythm_qn)
                    event_table[rhythm_idx] = new_rhythm_qn
                end
            end
        end
    end

    if vel_settings.drop and vel_settings.mode == 1 then
        local function VelocityTableClosestValue(velocity,vel_settings)
            local older_low, older_high
            for idx, group in ipairs(vel_settings.drop) do
                if older_low and velocity < group.low and velocity > older_low then -- In between the two groups : return closest
                    if (velocity - older_high) <= (group.low - velocity) then -- the lowest group
                        return idx-1
                    else -- the current group
                        return idx
                    end
                end
                if velocity >= group.low and velocity <= group.high then -- Inside a group
                    return idx
                end
                older_low, older_high = group.low, group.high
            end
        end
        for event_idx, event_table in ipairs(param_table.vel) do
            for vel_idx, vel in ipairs(event_table) do
                local vel, is_mute = ParameterStringToVals(vel,mute_symbol)
                local group = VelocityTableClosestValue(vel,vel_settings)
                event_table[vel_idx] = group
            end
        end
    end
end

---Enhance the resolution of pitch and velocity of all sequence. Rhythm stay quantized
---@param pitch_sequence any
---@param pos_sequence any
---@param vel_sequence any
---@param pitch_sequence any
---@param pos_sequence any
---@param vel_sequence any
function EnhanceResolution(pitch_sequence,pos_sequence,vel_sequence, pitch_settings, rhythm_settings, vel_settings, link_settings, original_notes,mute_symbol)
    local is_linked = link_settings.pitch and link_settings.order and link_settings.order > 1
    if pitch_settings.drop and pitch_settings.mode == 1 and TableCheckValues(pitch_sequence, 'sequence') then -- if drop resolution and mode == 1  will drop the resolution to pitch classes 0 based (0 - pitch_settings.drop)
        local new_sequence = {}
        local last_note -- used to compare the next closest note
        -- If keep start add the start from original. as the new sequence is pitch class, it lost the octave information
        if pitch_settings.keep_start or (is_linked and link_settings.keep_start)  then -- Get original notes that start the selected notes (they are already at the pitch_sequence.sequence but are in the pitch class form)
            local order = ( is_linked and link_settings.order ) or pitch_settings.order -- link_settings.order or pitch_settings.order
            for i = 1, order do
                for note_idx, note_table in ipairs(original_notes[i]) do
                    if not new_sequence[i] then new_sequence[i] = {} end
                    table.insert(new_sequence[i], note_table.pitch)
                end
            end
        else
            last_note = original_notes[1][1].pitch -- add the first note of the first event. Just to get the octave latter wont really add this pitch
        end
        -- Add the new Notes
        for event_idx, event_table in ipairs(pitch_sequence.sequence) do
            if event_idx <= #new_sequence then -- event already added  at keep start
                last_note = new_sequence[event_idx][1]
            else
                if not new_sequence[event_idx] then new_sequence[event_idx] = {} end
                for pitch_idx, pitch_class in ipairs(event_table) do
                    local pitch_class, is_mute = ParameterStringToVals(pitch_class,mute_symbol)
                    local new_note = GetClosestNote(last_note,pitch_class,pitch_settings.drop)
                    local new_note_str = new_note..((is_mute and mute_symbol) or "")
                    table.insert(new_sequence[event_idx],new_note_str)
                    last_note = new_note
                end
            end
        end
        pitch_sequence.sequence = new_sequence
    end

    if rhythm_settings.drop then -- Do fucking nothing is just a quantize at the drop, there is no enhance 
    end

    if vel_settings.drop and vel_settings.mode == 1 and TableCheckValues(vel_sequence, 'sequence') then
        local new_sequence = {}
        -- If keep start add the start from original. as the new sequence is pitch class, it lost the octave information
        if vel_settings.keep_start or (is_linked and link_settings.keep_start)  then -- Get original notes that start the selected notes (they are already at the pitch_sequence.sequence but are in the pitch class form)
            local order = ( is_linked and link_settings.order ) or vel_settings.order -- link_settings.order or pitch_settings.order
            for i = 1, order do
                if not TableCheckValues(original_notes,i) then return end -- order is bigger then the order_notes length
                for note_idx, note_table in ipairs(original_notes[i]) do
                    if not new_sequence[i] then new_sequence[i] = {} end
                    table.insert(new_sequence[i], note_table.vel)
                end
            end
        end
        -- Add the new Notes
        for event_idx, event_table in ipairs(vel_sequence.sequence) do
            if event_idx > #new_sequence then -- to rule out events already added  at keep start (above)
                if not new_sequence[event_idx] then new_sequence[event_idx] = {} end
                for vel_idx, vel_group in ipairs(event_table) do
                    local vel_group, is_mute = ParameterStringToVals(vel_group,mute_symbol)
                    -- random value on that group
                    local new_vel = math.random(vel_settings.drop[vel_group].low,vel_settings.drop[vel_group].high)
                    local new_vel_str = new_vel..((is_mute and mute_symbol) or "")
                    table.insert(new_sequence[event_idx],new_vel_str)
                end
            end
        end
        vel_sequence.sequence = new_sequence
    end
end


function EnchanceResolutionMarkovTable(last_pitch, new_value_pc, pitch_settings)
    local is_linked = link_settings.pitch and link_settings.order and link_settings.order > 1
    if pitch_settings.drop and pitch_settings.mode == 1  then -- if drop resolution and mode == 1  will drop the resolution to pitch classes 0 based (0 - pitch_settings.drop)
        
    
    end
end