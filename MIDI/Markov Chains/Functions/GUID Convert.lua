--@noindex
function ConvertUserDataToGUID(thing) -- Only Tracks, Items, Takes and LUA types.
    -- Userdata types = ReaProject*, MediaTrack*, MediaItem*, MediaItem_Take*, TrackEnvelope* and PCM_source*
    local tipo
    local guid
    local newthing
    local char = '#$$#'
    local char2 = '#$$$#'
    if reaper.ValidatePtr( thing, 'MediaTrack*' ) then
        tipo = 'Track'
        guid = reaper.GetTrackGUID(thing)
        newthing = char..tipo..guid

    elseif reaper.ValidatePtr( thing, 'MediaItem*' ) then
        tipo = 'Item'
        guid = reaper.BR_GetMediaItemGUID(thing)
        newthing = char..tipo..guid

    elseif reaper.ValidatePtr( thing, 'MediaItem_Take*' ) then
        tipo = 'Take'
        guid =  reaper.BR_GetMediaItemTakeGUID(thing)
        newthing = char..tipo..guid
    elseif type(thing) == 'userdata' then -- Userdata Removed or ReaProject*, TrackEnvelope* and PCM_source*
        newthing = char2..tostring(thing)
    else  -- Expect a LUA accetable type
        newthing = thing
    end
    return newthing and newthing or thing
end

--'#$$$#userdata: XXXXX' Couldn't save. Without GUID Save with a tostring
--'#$$$#Track{GUID}'Couldn't Load the GUID. 
function ConvertGUIDToUserData(str)
    if str:sub(1,4) == '#$$#' then -- Is a GUID
        local userdata
        local tipo = str:match('%a+') -- Get type name #$$#NAME{GUID}
        local guid = str:match('{.+}')

        if tipo == 'Track'  then
            userdata = GetTrackByGUID(guid) 
        elseif tipo == 'Item' then
            userdata = reaper.BR_GetMediaItemByGUID(0, guid)
        elseif tipo == 'Take' then
            userdata = reaper.GetMediaItemTakeByGUID(0, guid)
        end

        if not userdata then -- Couldnt Find in the project
            userdata = string.gsub(str,"#$$#",'#$$$#')
        end

        return userdata
    else
        return str
    end
end

function CovertUserDataToGUIDRecursive(thing) -- Only Tracks, Items, Takes and LUA types.
    -- If is reaper type
    if type(thing) == 'userdata' then
        thing = ConvertUserDataToGUID(thing) -- It convert in a string starting with #$$#
        return thing
    end
    -- If is table
    if type(thing) == 'table' then
        local new_table = {}
        for k, v in pairs(thing) do
            local new_k = CovertUserDataToGUIDRecursive(k)
            new_table[new_k] = CovertUserDataToGUIDRecursive(v)
        end
        return new_table
    end
    -- If is other lua type
    return thing
end

function ConvertGUIDToUserDataRecursive(thing)
    -- If is reaper type
    if type(thing) == 'string' then
        thing = ConvertGUIDToUserData(thing) -- It checks if start with #$$# at the start
    end
    -- If is table
    if type(thing) == 'table' then
        local new_table = {}
        for k, v in pairs(thing) do
            local new_k = ConvertGUIDToUserDataRecursive(k)
            new_table[new_k] = ConvertGUIDToUserDataRecursive(v)
        end
        return new_table
    end
    -- If is lua type
    return thing
end