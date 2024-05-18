--@noindex
--version: 0.0

DL = DL or {}
DL.enum = {}

--------
----- Projects
--------

function DL.enum.Projects()
    local i = -1
    return function ()
        i = i +1
        return reaper.EnumProjects( i )
    end
end

--------
----- Tracks
--------

function DL.enum.Tracks(proj)
    local i = -1
    return function ()
        i = i + 1 
        return reaper.GetTrack(proj, i) -- get current selected item
    end
end

function DL.enum.SelectedTracks(proj)
    local i = -1
    return function ()
        i = i + 1
        return reaper.GetSelectedTrack(proj, i)
    end
end

function DL.enum.SelectedTracks2(proj,wantmaster)
    local i = -1
    return function ()
        i = i + 1 -- for next time
        return reaper.GetSelectedTrack2(proj, i, wantmaster)
    end
end

--------
----- Items
--------

---@return function -item
function DL.enum.SelectedMediaItem(proj)
    local i = -1
    return function ()
        i = i + 1 -- for next time
        return reaper.GetSelectedMediaItem(proj, i)
    end
end

---@return function -item
function DL.enum.MediaItem(proj)
    local i = -1
    return function ()
        i = i + 1 -- for next time
        return reaper.GetMediaItem(proj, i) 
    end
end

---@return function -item
function DL.enum.TrackMediaItem(track)
    local i = -1
    return function ()
        i = i + 1 -- for next time
        return reaper.GetTrackMediaItem( track, i )
    end
end

--------
----- Takes
--------

---@return function -take
function DL.enum.Takes(item)
    local i = -1
    return function ()
        i = i + 1
        return reaper.GetTake(item, i)
    end
end

---Return the active MIDI takes from selected Items
---@return function - take
function DL.enum.SelectedMIDITakes(proj)
    local i = -1
    return function ()
        while true do
            i = i + 1 -- for next time
            local item = reaper.GetSelectedMediaItem(proj, i) 
            if not item then return nil end
            local take = reaper.GetActiveTake(item)
            if reaper.TakeIsMIDI(take) then
                return take
            end
        end
    end
end

---@return function - retval, name, color
function DL.enum.TakeMarkers(take)
    local i = -1
    return function ()
        i = i + 1
        local retval, name, color = reaper.GetTakeMarker( take, i )
        if retval == -1 then
            return nil
        else
            return retval, name, color
        end
    end
end

--- Takes open on the midi Editor.  editable_only == get only the editables 
---@param midi_editor HWND midi_editor window
---@param editable_only boolean If true get only takes that are editable in midi_editor 
---@return function iterate takes
function DL.enum.MIDIEditorTakes(midi_editor, editable_only)
    local i = -1
    return function()
        i = i + 1
        return reaper.MIDIEditor_EnumTakes(midi_editor, i, editable_only)
    end
end

--------
----- Envelopes
--------

---@return function - envelope
function DL.enum.TrackEnvelopes(track)
    local i = -1
    return function ()
        i = i + 1 -- for next time
        return reaper.GetTrackEnvelope( track, i )
    end
end

---@return function - envelope
function DL.enum.TakeEnvelopes(take)
    local i = -1
    return function ()
        i = i + 1 -- for next time
        return reaper.GetTakeEnvelope( take, i )
    end
end

--------
----- Envelopes
--------

---@return function -retval, time, value, shape, tension, selected, i
function DL.enum.EnvelopePointEx(env, autoitem_idx)
    local i = -1
    return function ()
        i = i + 1
        local retval, time, value, shape, tension, selected = reaper.GetEnvelopePointEx( env, autoitem_idx, i )
        if not retval then 
            return nil 
        else
            return retval, time, value, shape, tension, selected, i
        end
    end
end

--------
----- Markers
--------
---Iterate fuction returns retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber using EnumProjectMarkers2
---@param proj ReaProject|nil|0
---@param only_marker 1|2|3|? 0 = both, 1 = only marker, 2 = only region. 1 is the default
---@return function iterate retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber
function DL.enum.ProjectMarkers2(proj, only_marker)
    if not only_marker then only_marker = 1 end
    local i = -1
    return function ()
        while true do
            i = i + 1
            local retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers2( proj, i )
            if retval == 0 then 
                return nil
            else
                if (only_marker == 0) or (only_marker == 1 and not isrgn) or (only_marker == 2  and isrgn) then -- filter
                    return retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber, i
                end
            end
        end
    end
end

---Iterate fuction returns retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber using EnumProjectMarkers2
---@param proj ReaProject|nil|0
---@param only_marker 0|1|2|? 0 = both, 1 = only marker, 2 = only region. 1 is the default
---@return function iterate retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber, color, i
function DL.enum.ProjectMarkers3(proj, only_marker)
    if not only_marker then only_marker = 1 end
    local i = -1
    return function ()
        while true do
            i = i + 1
            local retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3( proj, i )
            if retval == 0 then 
                return nil
            else
                if (only_marker == 0) or (only_marker == 1 and not isrgn) or (only_marker == 2  and isrgn) then -- filter
                    return retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber, color, i
                end
            end
        end
    end
end

---Iterate function that return all MIDI Outputs: `for idx, is_online, midiname in enumMIDIOutput() do`
---@return function -- i, retval, nameout (idx, if is connected, name)
function DL.enum.MIDIOutputs()
    local i = -1
    return function ()
        i = i + 1
        local retval, nameout = reaper.GetMIDIOutputName(i, '')
        if nameout ~= '' then
            return i, retval, nameout
        end
    end
end

---Iterate function that return all MIDI Inputs: `for idx, is_online, midiname in enumMIDIOutput() do`
---@return function -- i, retval, nameout (idx, if is connected, name)
function DL.enum.MIDIInput()
    local i = -1
    return function ()
        i = i + 1
        local retval, nameout = reaper.GetMIDIInputName(i, '')
        if nameout ~= '' then
            return i, retval, nameout
        end
    end
end

---Enumerate files inside a directory
function DL.enum.Files(path)
    local i = -1
    return function ()
        i = i + 1
        return reaper.EnumerateFiles( path, i ) 
    end    
end

-------------
---- MIDI
-------------


--- This is the simple version that haves no filter besides the last event. Easy to understand and if you want to check the difference in performance with my IterateMIDI function. Or if you want to filter yourself. 
---@param MIDIstring string string with all MIDI events (use reaper.MIDI_GetAllEvts)
---@param filter_midiend boolean? default is false. Filter Last MIDI message (reaper automatically add a message when item ends 'CC123')
---@return function
function DL.enum.AllMIDI(MIDIstring, filter_midiend)
    -- Should it iterate the last midi 123 ? it just say when the item ends 
    local MIDIlen = MIDIstring:len()
    if filter_midiend then MIDIlen = MIDIlen - 12 end
    local iteration_stringPos = 1 ---@type number|nil
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
function DL.enum.MIDI(MIDIstring,miditype,ch,selected,muted,filter_midiend,start,step)
    local MIDIlen = MIDIstring:len()
    if filter_midiend then MIDIlen = MIDIlen - 12 end
    -- start filter settings
    local iteration_stringPos = start and start.stringPos or 1---@type number|nil -- the same as if start and start.stringPos then iteration_stringPos = start.stringPos else iteration_stringPos = 1 end
    local event_n = 0 -- if start.event_n will count every message that passes all filters and will only start returning at event start.event_n
    local event_count = 0 -- event count will return the event count nº between all midi events
    local offset_count = 0
    ----
    local step_count = -1 -- only for using step
    return function ()
        while iteration_stringPos < MIDIlen do 
            local offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, iteration_stringPos) ---@cast msg string
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
                    if not DL.t.HaveValue(miditype, msg_type) then goto continue end 
                else -- if is just a value
                    if not (msg_type == miditype) then goto continue end 
                end
            end
            
            -- check channel.
            if ch then  
                local msg_ch = msg:byte(1)&0x0F -- 0x0F = 0000 1111 in binary . msg is string. & is an and bitwise operation "have to have 1 in both to be 1". Will return channel as a decimal number. 0 based
                msg_ch = msg_ch + 1 -- makes it 1 based
                if type(ch) == "table" then -- if ch is a table with all ch to get
                    if not DL.t.HaveValue(ch, msg_ch) then goto continue end 
                else -- if is just a value
                    if not (msg_ch == ch) then goto continue end 
                end
            end

            local msg_sel, msg_mute, msg_curve_shape
            if (selected ~= nil) or (muted ~= nil) or (msg_curve_shape ~= nil) then -- Only unpack if gonna use, and do it only once!
                msg_sel, msg_mute, msg_curve_shape = DL.midi.UnpackFlags(flags)
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

function DL.enum.MIDIReverse(MIDIstring,miditype,ch,selected,muted,filter_midiend,start,step)
    local t = {}
    for offset, offset_count, flags, msg, event_count, stringPos in DL.enum.MIDI(MIDIstring,miditype,ch,selected,muted,filter_midiend,start,step) do
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

function DL.enum.MIDINotes(take)
    local noteidx = -1
    return function ()
        noteidx = noteidx + 1
        local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, noteidx)
        if retval then 
            return selected, muted, startppqpos, endppqpos, chan, pitch, vel, noteidx
        end        
    end    
end
