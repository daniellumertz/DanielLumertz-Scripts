-- @noindex
BlankGroup = {} -- To create a group with all things it needs
BlankGroup.__index = BlankGroup
function BlankGroup:Create(name)
    local temp = {
        name = name or "New Group",
        Settings = {
            Erase = true,
            Is_trim_ItemEnd = true,
            Is_trim_StartNextNote = true,
            Is_trim_EndNote = true,
            Tips = true,
            Velocity = false,
            Vel_OriginalVal = 64,
            Vel_Min = -6,
            Vel_Max = 6,
            Pitch = false,
            Pitch_Original = 60,
            Check = true, -- If passes all checks it will be pasted, else it will fail
            NoteRange = {
                Min = 0,
                Max = 127
            },
            VelocityRange = {
                Min = 0,
                Max = 127
            },
            GUID = reaper.genGuid()
        },
        list_sequence = {},
        Targets = {},
        Selected = true
    }
    setmetatable(temp,BlankGroup)
    return temp
end

--[[ Groups = {}
Groups[1] = BlankGroup:Create('G1') ]]