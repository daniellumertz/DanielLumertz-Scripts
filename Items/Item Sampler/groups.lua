-- @noindex
BlankGroup = {} -- To create a group with all things it needs
BlankGroup.__index = BlankGroup
function BlankGroup:Create(name)
    local temp = {
        name = name or "New Group",
        Settings = {
            stretch = {
                is_stretch = false,
                min_stretch = 0.5,
                max_stretch = 2,
                original_stretch = 60
            },
            Erase = true,
            Is_trim_ItemEnd = true,
            Is_trim_StartNextNote = true,
            Is_trim_EndNote = true,
            Tips = true,
            Velocity = true,
            Vel_OriginalVal = 64,
            Vel_Min = -6,
            Vel_Max = 6,
            Pitch = true,
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

function BlankGroup.Create2(proj, settings, group_model, sources)
    local new_groups = {}
    local loop_sources
    if settings.is_one == 0 then
        loop_sources = {sources} -- loop_sources = {1 = {item, item, item}} -- a table with one entry with a table with all sources 
    else
        loop_sources = {}
        for k, source in ipairs(sources) do 
            loop_sources[#loop_sources+1] = {source} -- loop_sources = {1 = {item}, 2 = {item}, 3 = {item}} a table with each entry another source (inside a table)
        end
    end
    
    local start_pitch = settings.range.start_pitch
    for k, sourcetable in ipairs(loop_sources) do -- sourcetable is a table holding sources: {item} or {item, item, item}
        local new_group = table_copy(group_model)
        -- name
        local name 
        if reaper.ValidatePtr2(proj, sourcetable[1], 'MediaItem*') then
            local tk = reaper.GetActiveTake(sourcetable[1])
            _, name = reaper.GetSetMediaItemTakeInfo_String(tk, 'P_NAME', '', false)
            if name == '' then
                name = 'Item '..k
            end
        else
            _, name = reaper.GetSetMediaTrackInfo_String(sourcetable[1], 'P_NAME', '', false)
            if name == '' then
                name = 'Track #'..reaper.GetMediaTrackInfo_Value(sourcetable[1], 'IP_TRACKNUMBER')
            end
        end
        new_group.name = name
        -- sources
        new_group.list_sequence = table_copy(sourcetable)
        -- range
        if settings.is_one == 1 and settings.range.set_by_key then
            new_group.Settings.NoteRange.Min = start_pitch
            new_group.Settings.NoteRange.Max = start_pitch
            new_group.Settings.Pitch_Original = start_pitch
            start_pitch = start_pitch + 1
        end
        -- GUID
        new_group.Settings.GUID = reaper.genGuid()

        new_groups[#new_groups+1] = new_group
    end

    return new_groups
end

function BlankGroup.Duplicate(group)
    local new_group = table_copy(group)
    new_group.Settings.GUID = reaper.genGuid()

    return new_group
end
--[[ Groups = {}
Groups[1] = BlankGroup:Create('G1') ]]