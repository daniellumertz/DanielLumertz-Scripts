--@noindex
Clouds = Clouds or {}
Clouds.convert = {}

--- Recursive COnvert functions
function Clouds.convert.ConvertUserDataToGUID(proj, thing) -- Only Tracks, Items, Takes, Envelopes and LUA types.
    -- Userdata types = ReaProject*, MediaTrack*, MediaItem*, MediaItem_Take*, TrackEnvelope* and PCM_source*
    local char = '#$$#'
    local char2 = '#$$$#'
    if type(thing) ~= 'userdata' then
        return thing    
    elseif reaper.ValidatePtr2(proj, thing, 'MediaTrack*' ) then
        local tipo = 'Track'
        local retval, guid = reaper.GetSetMediaTrackInfo_String( thing, 'GUID', '', false )
        return char..tipo..guid

    elseif reaper.ValidatePtr2(proj, thing, 'MediaItem*' ) then
        local tipo = 'Item'
        local retval, guid = reaper.GetSetMediaItemInfo_String( thing, 'GUID', '', false )
        return char..tipo..guid

    elseif reaper.ValidatePtr2(proj, thing, 'MediaItem_Take*' ) then
        local tipo = 'Take'
        local retval, guid = reaper.GetSetMediaItemTakeInfo_String( thing, 'GUID', '', false )
        return char..tipo..guid
    
    elseif reaper.ValidatePtr2(proj, thing, 'TrackEnvelope*' ) then
        local tipo = 'Envelope'
        local guid = Clouds.convert.GetEnvelopeGUID(thing)
        return char..tipo..guid

    else -- Userdata Removed or ReaProject* and PCM_source*
        return char2..tostring(thing)

    end
end

--'#$$$#userdata: XXXXX' Couldn't save. Without GUID Save with a tostring
--'#$$$#Track{GUID}'Couldn't Load the GUID. 
function Clouds.convert.ConvertGUIDToUserData(proj, str)
    local char = '#$$#'
    local char2 = '#$$$#'
    if str:sub(1,4) == char then -- Is a GUID
        local userdata
        local tipo = str:match('%a+') -- Get type name #$$#NAME{GUID}
        local guid = str:match('{.+}')

        if tipo == 'Track'  then
            userdata =  reaper.BR_GetMediaTrackByGUID(proj, guid ) --GetTrackByGUID(guid) 
        elseif tipo == 'Item' then
            userdata = reaper.BR_GetMediaItemByGUID(proj, guid)
        elseif tipo == 'Take' then
            userdata = reaper.GetMediaItemTakeByGUID(proj, guid)
        elseif tipo == 'Envelope' then
            userdata = DL.env.GetByGUID(proj, guid, 2)
        end

        if not userdata then -- Couldnt Find in the project
            userdata = string.gsub(str,char,char2)
        end

        return userdata
    else
        return str
    end
end

function Clouds.convert.CovertUserDataToGUIDRecursive(proj, thing) -- Only Tracks, Items, Takes and LUA types.
  -- If is reaper type
  if type(thing) == 'userdata' then
      thing = Clouds.convert.ConvertUserDataToGUID(proj, thing) -- It convert in a string starting with #$$#
      return thing
  end
  -- If is table
  if type(thing) == 'table' then
      local new_table = {}
      for k, v in pairs(thing) do
          local new_k = Clouds.convert.CovertUserDataToGUIDRecursive(proj, k)
          new_table[new_k] = Clouds.convert.CovertUserDataToGUIDRecursive(proj, v)
      end
      return new_table
  end
  -- If is other lua type
  return thing
end

function Clouds.convert.ConvertGUIDToUserDataRecursive(proj, thing)
  -- If is reaper type
  if type(thing) == 'string' then
      thing = Clouds.convert.ConvertGUIDToUserData(proj, thing) -- It checks if start with #$$# at the start
  end
  -- If is table
  if type(thing) == 'table' then
      local new_table = {}
      for k, v in pairs(thing) do
          local new_k = Clouds.convert.ConvertGUIDToUserDataRecursive(proj, k)
          new_table[new_k] = Clouds.convert.ConvertGUIDToUserDataRecursive(proj, v)
      end
      return new_table
  end
  -- If is lua type
  return thing
end

