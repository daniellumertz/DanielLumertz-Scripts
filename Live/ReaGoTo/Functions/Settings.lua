--@noindex

-------------
--- Settings Saved in a Json
-------------

--- UserConfigs and GuiSettings
-- Run when closing the script to save settings and ext state
function Save()
    SaveSettings(ScriptPath,SettingsFileName)
    SaveAllProjectSettings()
end

function Settings()
    local retval_load = false
    if reaper.file_exists( ScriptPath..SettingsFileName..'.json' ) then
        retval_load = LoadSettings(ScriptPath,SettingsFileName) -- it return retval based if the version of settings is the same as the current, if false then recreate with default settings
    end -- Create the settings file and load default
    if not retval_load then
        DefaultSettings()
        SaveSettings(ScriptPath,SettingsFileName)
    end
end

function DefaultSettings()
    UserConfigs = {
        only_focus_project = false, -- only checks the focused project
        compensate = 2, -- Compensate the defer instability. -- too much will have timing problems (can jump regions much early). Too little will have more artifacts (when the marker is at the attack of a transient (common scenario))
        add_markers = false, -- add markers every time alternator is trigger. for debugging/understanding when it triggers positions.
        trigger_when_paused = true, -- if true it will execute goto actions when paused. if false it will just leave triggered
        tooltips = false -- show le tooltip
    } -- Json file 

    GuiSettings = {
        Pin = true,
        docked = 0
    }
end



function SaveSettings(path,name)
    local settings = {
        UserConfigs = UserConfigs,
        GuiSettings = GuiSettings,
        Version = Version
    }
    save_json(path , name, settings)
end

function LoadSettings(path,name)
    local settings = load_json(path , name)
    local load_version = settings.Version
    if load_version ~= Version then return false end
    UserConfigs = settings.UserConfigs
    GuiSettings = settings.GuiSettings
    return true
end

-------------
---  Proj Settings saved in ext state
-------------

-- ProjectSettings


-- Saves all at the end of the script.
function SaveAllProjectSettings()
    for proj, project_table in pairs(ProjConfigs) do
        SaveProjectSettings(proj, project_table)
    end
end

---Save a specific project configs (after user changes)
---@param proj project reaper project 
---@param config_table table ProjConfig[proj]
function SaveProjectSettings(proj, config_table)
    local table_copy = TableDeepCopy(config_table)
    -- current playlist to 0
    for playlist_key, playlist in ipairs(table_copy.playlists) do 
        playlist.current = 0
    end
    -- remove triggers
    table_copy.is_triggered = false
    -- remove positions
    table_copy.oldpos = nil
    table_copy.oldisplay = nil
    table_copy.oldtime = nil
    SaveExtStateTable(proj, ScriptName, ExtKey, table_copy, true)
end

function LoadProjectSettings(proj)
    --- Check if have a config
    ProjConfigs[proj] = LoadExtStateTable(proj, ScriptName, ExtKey, true)
    --- Create a new Config
    if not ProjConfigs[proj] then 
        ProjConfigs[proj] = CreateProjectConfigTable(proj)
    end
    -- Dont need to validate Userdata, no userdata at the table
end

-------------
-- ExtState Functions
-------------

function LoadExtStateTable(proj, script_name, key, convert_GUID)
    local tabela = {} -- debug put as local
    local retval, table_string = reaper.GetProjExtState(proj, script_name, key)

    if retval == 1 and table_string ~= '' then
        tabela = table.load( table_string )
    else 
        return false
    end

    if convert_GUID then 
        tabela = ConvertGUIDToUserDataRecursive(proj, tabela)
    end
    return tabela
end

---Save at project ext state convert user data to guid
---@param proj Project Reaper project to save to 
---@param script_name string ext state will use the script name to store information
---@param key string ext state will use this key inside the script name area to store information
---@param tabela table table you want to save. User data Takes, Tracks, Items are converted user data to GUID. 
---@param convert_GUID any
function SaveExtStateTable(proj, script_name, key, tabela, convert_GUID)
    if convert_GUID then 
        tabela = CovertUserDataToGUIDRecursive(proj, tabela)
    end 
    local table_string = table.save( tabela )

    reaper.SetProjExtState( proj, script_name, key, table_string )
end

-------------
--- Json functions
-------------

--Save function
function save_json(path, name,  var)
    local filepath = path .. "/" .. name .. ".json"
    local file = assert(io.open(filepath, "w+"))

    local serialized = json.encode(var)
    assert(file:write(serialized))

    file:close()
    return true
end

--Load function
function load_json(path, name)
    local filepath = path .. "/" .. name .. ".json"
    local file = assert(io.open(filepath, "rb"))

    local raw_text = file:read("*all")
    file:close()

    return json.decode(raw_text)
end

-------------
--- Convert GUIDS Functions
-------------


--- Recursive COnvert functions

function ConvertUserDataToGUID(proj, thing) -- Only Tracks, Items, Takes and LUA types.
    -- Userdata types = ReaProject*, MediaTrack*, MediaItem*, MediaItem_Take*, TrackEnvelope* and PCM_source*
    local tipo
    local guid
    local newthing
    local char = '#$$#'
    local char2 = '#$$$#'
    local retval
    if reaper.ValidatePtr2(proj, thing, 'MediaTrack*' ) then
        tipo = 'Track'
        retval, guid = reaper.GetSetMediaTrackInfo_String( thing, 'GUID', '', false )
        newthing = char..tipo..guid

    elseif reaper.ValidatePtr2(proj, thing, 'MediaItem*' ) then
        tipo = 'Item'
        retval, guid = reaper.GetSetMediaItemInfo_String( thing, 'GUID', '', false )
        newthing = char..tipo..guid

    elseif reaper.ValidatePtr2(proj, thing, 'MediaItem_Take*' ) then
        tipo = 'Take'
        retval, guid = reaper.GetSetMediaItemTakeInfo_String( thing, 'GUID', '', false )
        newthing = char..tipo..guid
    elseif type(thing) == 'userdata' then -- Userdata Removed or ReaProject*, TrackEnvelope* and PCM_source*
        newthing = char2..tostring(thing)
    else  -- Expect a LUA accetable type
        newthing = thing
    end
    return newthing --and newthing or thing
end
--'#$$$#userdata: XXXXX' Couldn't save. Without GUID Save with a tostring
--'#$$$#Track{GUID}'Couldn't Load the GUID. 
function ConvertGUIDToUserData(proj, str)
  if str:sub(1,4) == '#$$#' then -- Is a GUID
      local userdata
      local tipo = str:match('%a+') -- Get type name #$$#NAME{GUID}
      local guid = str:match('{.+}')

      if tipo == 'Track'  then
          userdata =  reaper.BR_GetMediaTrackByGUID(proj, guid ) --GetTrackByGUID(guid) 
      elseif tipo == 'Item' then
          userdata = reaper.BR_GetMediaItemByGUID(proj, guid)
      elseif tipo == 'Take' then
          userdata = reaper.GetMediaItemTakeByGUID(proj, guid)
      end

      if not userdata then -- Couldnt Find in the project
        userdata = string.gsub(str,"#$$#",'#$$$#')
      end

      return userdata
  else
      return str
  end
end

function CovertUserDataToGUIDRecursive(proj, thing) -- Only Tracks, Items, Takes and LUA types.
  -- If is reaper type
  if type(thing) == 'userdata' then
      thing = ConvertUserDataToGUID(proj, thing) -- It convert in a string starting with #$$#
      return thing
  end
  -- If is table
  if type(thing) == 'table' then
      local new_table = {}
      for k, v in pairs(thing) do
          local new_k = CovertUserDataToGUIDRecursive(proj, k)
          new_table[new_k] = CovertUserDataToGUIDRecursive(proj, v)
      end
      return new_table
  end
  -- If is other lua type
  return thing
end

function ConvertGUIDToUserDataRecursive(proj, thing)
  -- If is reaper type
  if type(thing) == 'string' then
      thing = ConvertGUIDToUserData(proj, thing) -- It checks if start with #$$# at the start
  end
  -- If is table
  if type(thing) == 'table' then
      local new_table = {}
      for k, v in pairs(thing) do
          local new_k = ConvertGUIDToUserDataRecursive(proj, k)
          new_table[new_k] = ConvertGUIDToUserDataRecursive(proj, v)
      end
      return new_table
  end
  -- If is lua type
  return thing
end

