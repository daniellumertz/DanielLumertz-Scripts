--@noindex

---Return the octave
---@param note number Note (60 = middle C)
---@param central_octave number Central octave (4 = C4). Optional, if nil then = 4 
---@param octave_size number Size of the octave (12 = 12 notes per octave). Optional, default = 12
---@return number octave (4 = C4)
function GetOctave(note,central_octave,octave_size)
    local central_octave = central_octave or 4
    local octave_size = octave_size or 12
    local octave_offset = 5 - central_octave 
    return (((note)/octave_size)//1)-(octave_offset)
end

---Return the lowest and highest notes of the octave. ex octave 4 return 60, 71 from C4 to B4
---@param note number Note (60 = middle C)
---@param central_octave number Central octave (4 = C4). Optional, if nil then = 4 
---@param octave_size number Size of the octave (12 = 12 notes per octave). Optional, default = 12
---@return number low
---@return number high
function GetOctaveLowHighNote(octave,central_octave,octave_size)
    local central_octave = central_octave or 4
    local octave_size = octave_size or 12
    local octave_offset = 5 - central_octave 
    local low = (octave+octave_offset)*octave_size
    local high = ((octave+octave_offset)*octave_size) + (octave_size - 1)
    return low, high
end

---Given a note, return the closeset note with pitch class = "new_pitch_class". If the distance is equivalent between 2 octaves, return on the same octave. If is the same pitch class return the same note.
---@param note number starting note
---@param new_pitch_class number new pitch class note
---@param octave_size number size of the octave. (12 = 12 notes per octave). Optional, default = 12
---@return number new_note closest note from "note" with pitch class = new_pitch_class
function GetClosestNote(note,new_pitch_class,octave_size)
    octave_size = octave_size or 12
    local note_pitch_class = note % octave_size
    if note_pitch_class == new_pitch_class then return note end -- same pitch class, same note
    local distance = math.abs(new_pitch_class - note_pitch_class) -- distance between pitch classes. 
    if distance <= (octave_size/2) then -- closer note is in the same octave. If note is == octave_size/2 then will return on the same octave
        return (note - note_pitch_class) + new_pitch_class
    else -- need to be in anoter octave
        if new_pitch_class > note_pitch_class then  -- if new_pitch_class is higher than note_pitch_class
            return (note - note_pitch_class) + new_pitch_class - octave_size -- return a octave lower
        else
            return (note - note_pitch_class) + new_pitch_class + octave_size -- return a octave higher
        end
    end
end