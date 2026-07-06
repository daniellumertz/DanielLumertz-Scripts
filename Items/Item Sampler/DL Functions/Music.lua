--@noindex
--version: 0.0

DL = DL or {}
DL.m = {}

-----------
-- Pitches
-----------
---Get a `number` returns a string with the note name, 12 EDO.
---@param number number
---@param is_sharp boolean? default is true
---@param is_octave boolean? default is true. Returns the octave with the note name: C#4
---@param center_c_octave number? default is 4
---@return string
function DL.m.NumberToPitchClass(number, is_sharp, is_octave, center_c_octave) -- Number, boolean(optional), boolean(optional), number(optional)
    center_c_octave = center_c_octave or 4
    if is_sharp == nil then
        is_sharp = true
    end
    if is_octave == nil then
        is_octave = true
    end

    local note_names_sharp = {'C','C#','D','D#','E','F','F#','G','G#','A','A#','B'}
    local note_names_flat = {'C','Db','D','Eb','E','F','Gb','G','Ab','A','Bb','B'}
    local note_names = is_sharp and note_names_sharp or note_names_flat
    local pitch_class = note_names[(number % 12)+1] 
    if is_octave then
        local octave_number = math.floor((number / 12) - (5-center_c_octave))
        pitch_class = pitch_class..octave_number
    end

    return pitch_class
end

---Gets a string with note name, returns a number with the MIDI note. 12 EDO.
---@param note string
---@param center_c_octave number? default is 4
---@return number|boolean
function DL.m.PitchClassToNumber(note,center_c_octave) -- Number, number(optional)
    center_c_octave = center_c_octave or 4
    
    local pitch_class_step = note:sub(1,1)
    local pitch_class_step = pitch_class_step:upper() -- to match
    local steps_names = {C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11}
    local pitch_class_number = steps_names[pitch_class_step]
    if not pitch_class_number then return false end

    local octave_number = string.match(note, "[%-%d]+") 
    local accidents = note:match(pitch_class_step..'(.*)'..(octave_number or ''))
    
    octave_number = octave_number or center_c_octave
    octave_number = tonumber(octave_number) or center_c_octave
    octave_number = octave_number + (5-center_c_octave)
    
    if accidents then
        for accident in accidents:gmatch('.') do
            if accident == '#' then
                pitch_class_number = pitch_class_number + 1
            elseif accident:lower() == 'b' then
                pitch_class_number = pitch_class_number - 1
            end
        end
    end

    local number = pitch_class_number + (12 * octave_number)
    return number
end

---Return the octave
---@param note number Note (60 = middle C)
---@param central_octave number Central octave (4 = C4). Optional, if nil then = 4 
---@param octave_size number Size of the octave (12 = 12 notes per octave). Optional, default = 12
---@return number octave (4 = C4)
function DL.m.GetOctave(note,central_octave,octave_size)
    local central_octave = central_octave or 4
    local octave_size = octave_size or 12
    local octave_offset = 5 - central_octave 
    return (((note)/octave_size)//1)-(octave_offset)
end

---Return the lowest and highest notes of the octave. ex octave 4 return 60, 71 from C4 to B4
---@param octave number Which octave
---@param central_octave number Central octave (4 = C4). Optional, if nil then = 4 
---@param octave_size number Size of the octave (12 = 12 notes per octave). Optional, default = 12
---@return number low
---@return number high
function DL.m.GetOctaveLowHighPitchClass(octave,central_octave,octave_size)
    local central_octave = central_octave or 4
    local octave_size = octave_size or 12
    local octave_offset = 5 - central_octave 
    local low = (octave+octave_offset)*octave_size
    local high = ((octave+octave_offset)*octave_size) + (octave_size - 1)
    return low, high
end

---Given a note, return the closeset note number with some pitch class. If the interval between `note` and `new_pitch_class` is a tritone, return on the same octave. If is the same pitch class return the same note.
---@param note number starting note
---@param new_pitch_class number new pitch class note
---@param octave_size number size of the octave. (12 = 12 notes per octave). Optional, default = 12
---@return number new_note closest note from "note" with pitch class = new_pitch_class
function DL.m.GetClosestNote(note,new_pitch_class,octave_size)
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

----- Diatonic Scales / Circle of Fifths
---Get note in chromatic order c = 0, c# = 1... and return in circle of fifths order F = -1, C = 0, G = 1
---@param note number chromatic note (0 to 11)
---@param circle_root number optional number that is the 0 at the circle f = -1, 0 = c, 1 = g etc
---@return number note circle of fifths number (-5 to 6)
function DL.m.ChromaticToCircleOfFifths(note, circle_root)
    circle_root = circle_root or 0
    note = (note * 7) % 12 -- (0-11) put in the circle of fifths order ... F = 11, C = 0, G = 1...
    note = (note - circle_root)  % 12
    if note > 6 then
        note = note - 12
    end

    return note
end
