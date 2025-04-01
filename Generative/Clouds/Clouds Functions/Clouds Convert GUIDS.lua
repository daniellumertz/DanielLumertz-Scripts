--@noindex
Clouds = Clouds or {}
Clouds.convert = {}

---------------------------------- Tied to Clouds
function Clouds.convert.ConvertUserDataToGUID_Manually(proj, ct)
    local n_ct = DL.t.DeepCopy(ct)
    -- cloud, technically dont need, as it will subscribed when loading
    if n_ct.cloud then
        if reaper.ValidatePtr2(proj, n_ct.cloud, 'MediaItem*' )  then
            local retval, guid = reaper.GetSetMediaItemInfo_String( n_ct.cloud, 'GUID', '', false )
            n_ct.cloud = guid
        end
    end

    -- items
    local new_items_t = {} 
    for k, v in ipairs(n_ct.items) do
        if reaper.ValidatePtr2(proj, n_ct.items[k].item, 'MediaItem*' )  then
            local retval, guid = reaper.GetSetMediaItemInfo_String( n_ct.items[k].item, 'GUID', '', false )
            if guid then
                new_items_t[#new_items_t+1] = n_ct.items[k] 
                new_items_t[#new_items_t].item = guid
            end
        end
    end
    n_ct.items = new_items_t

    -- Tracks
    local new_tracks_t = {}
    new_tracks_t.self = n_ct.tracks.self
    for k, v in ipairs(n_ct.tracks) do
        local track = n_ct.tracks[k].track
        if reaper.ValidatePtr2(proj, track, 'MediaTrack*') then
            local retval, guid = reaper.GetSetMediaTrackInfo_String(track, 'GUID', '', false )
            if guid then
                new_tracks_t[#new_tracks_t+1] = n_ct.tracks[k]
                new_tracks_t[#new_tracks_t].track = guid
            end
        end
    end
    n_ct.tracks = new_tracks_t

    return n_ct
end

function Clouds.convert.ConvertGUIDtoUserData_Manually(proj, ct)
    -- cloud
    if ct.cloud then
        ct.cloud = Clouds.convert.UpdateFormat(ct.cloud)
        local item = reaper.BR_GetMediaItemByGUID(proj, ct.cloud)
        if reaper.ValidatePtr2(proj, item, 'MediaItem*') then
            ct.cloud = item
        end
    end

    --items
    local new_items_t = {}
    for k, v in ipairs(ct.items) do
        v.item = Clouds.convert.UpdateFormat(v.item)
        local item = reaper.BR_GetMediaItemByGUID(proj, v.item)
        if reaper.ValidatePtr2(proj, item, 'MediaItem*') then
            new_items_t[#new_items_t+1] = v
            new_items_t[#new_items_t].item = item
        end
    end
    ct.items = new_items_t

    --tracks
    local new_tracks_t = {}
    new_tracks_t.self = ct.tracks.self
    for k, v in ipairs(ct.tracks) do
        v.track = Clouds.convert.UpdateFormat(v.track)
        local track = reaper.BR_GetMediaTrackByGUID(proj, v.track)
        if reaper.ValidatePtr2(proj, track, 'MediaTrack*') then
            new_tracks_t[#new_tracks_t+1] = v
            new_tracks_t[#new_tracks_t].track = track
        end
    end
    ct.tracks = new_tracks_t

    return ct
end

-- Before 1.2.0 I was using the recursive convertion, which adds $##$ to the start of each item/track guid. After v 1.2.0 I am manually changing each of the guids to userdata. Without adding #$$#.
-- This function serves the purpose to handle older cloud tables 
function Clouds.convert.UpdateFormat(string)
    if string:match('^#%$%$#') then 
        return string:match('({.+})') 
    else
        return string
    end
end
--------------------------------- Recursive (slow)
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

