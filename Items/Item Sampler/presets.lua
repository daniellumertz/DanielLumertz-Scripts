-- @noindex
-- Utils functions for presets

function file_exists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
 end

-- Load the json functions
package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
local json = require ("./utils.json")


--Save function
function save_json(path, name,  var)
    local filepath = path .. "/" .. name .. ".json"
    local file = assert(io.open(filepath, "w+"))

--[[     if type(var) == 'table' then
      for index, value in pairs(var) do
        local max = 0
        if type(index) == "number" then
          local max = math.max(index,max)
        end
        
        for i = 1, max do
          if var[i] == nil then
            var[1] = true
          end
        end

      end
    end  ]]

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

---

local function exportstring( s )
    s = string.format( "%q",s )
    -- to replace
    s = string.gsub( s,"\\\n","\\n" )
    s = string.gsub( s,"\r","\\r" )
    s = string.gsub( s,string.char(26),"\"..string.char(26)..\"" )
    return s
  end
--// The Save Function
function table.save(  tbl,filename )
  local charS,charE = "   ","\n"
  local file,err
  -- create a pseudo file that writes to a string and return the string
  if not filename then
    file =  { write = function( self,newstr ) self.str = self.str..newstr end, str = "" }
    charS,charE = "",""
  -- write table to tmpfile
  elseif filename == true or filename == 1 then
    charS,charE,file = "","",io.tmpfile()
  -- write table to file
  -- use io.open here rather than io.output, since in windows when clicking on a file opened with io.output will create an error
  else
    file,err = io.open( filename, "w" )
    if err then return _,err end
  end
  -- initiate variables for save procedure
  local tables,lookup = { tbl },{ [tbl] = 1 }
  file:write( "return {"..charE )
  for idx,t in ipairs( tables ) do
    if filename and filename ~= true and filename ~= 1 then
      file:write( "-- Table: {"..idx.."}"..charE )
    end
    file:write( "{"..charE )
    local thandled = {}
    for i,v in ipairs( t ) do
      thandled[i] = true
      -- escape functions and userdata
      if type( v ) ~= "userdata" then
        -- only handle value
        if type( v ) == "table" then
          if not lookup[v] then
            table.insert( tables, v )
            lookup[v] = #tables
          end
          file:write( charS.."{"..lookup[v].."},"..charE )
        elseif type( v ) == "function" then
          file:write( charS.."loadstring("..exportstring(string.dump( v )).."),"..charE )
        else
          local value =  ( type( v ) == "string" and exportstring( v ) ) or tostring( v )
          file:write(  charS..value..","..charE )
        end
      end
    end
    for i,v in pairs( t ) do
      -- escape functions and userdata
      if (not thandled[i]) and type( v ) ~= "userdata" then
        -- handle index
        if type( i ) == "table" then
          if not lookup[i] then
            table.insert( tables,i )
            lookup[i] = #tables
          end
          file:write( charS.."[{"..lookup[i].."}]=" )
        else
          local index = ( type( i ) == "string" and "["..exportstring( i ).."]" ) or string.format( "[%d]",i )
          file:write( charS..index.."=" )
        end
        -- handle value
        if type( v ) == "table" then
          if not lookup[v] then
            table.insert( tables,v )
            lookup[v] = #tables
          end
          file:write( "{"..lookup[v].."},"..charE )
        elseif type( v ) == "function" then
          file:write( "loadstring("..exportstring(string.dump( v )).."),"..charE )
        else
          local value =  ( type( v ) == "string" and exportstring( v ) ) or tostring( v )
          file:write( value..","..charE )
        end
      end
    end
    file:write( "},"..charE )
  end
  file:write( "}" )
  -- Return Values
  -- return stringtable from string
  if not filename then
    -- set marker for stringtable
    return file.str.."--|"
  -- return stringttable from file
  elseif filename == true or filename == 1 then
    file:seek ( "set" )
    -- no need to close file, it gets closed and removed automatically
    -- set marker for stringtable
    return file:read( "*a" ).."--|"
  -- close file and return 1
  else
    file:close()
    return 1
  end
end

--// The Load Function
function table.load( sfile )
  local tables, err, _
  -- catch marker for stringtable
  if string.sub( sfile,-3,-1 ) == "--|" then
    tables,err = load( sfile )
  else
    tables,err = loadfile( sfile )
  end
  if err then return _,err
  end
  tables = tables()
  for idx = 1,#tables do
    local tolinkv,tolinki = {},{}
    for i,v in pairs( tables[idx] ) do
      if type( v ) == "table" and tables[v[1]] then
        table.insert( tolinkv,{ i,tables[v[1]] } )
      end
      if type( i ) == "table" and tables[i[1]] then
        table.insert( tolinki,{ i,tables[i[1]] } )
      end
    end
    -- link values, first due to possible changes of indices
    for _,v in ipairs( tolinkv ) do
      tables[idx][v[1]] = v[2]
    end
    -- link indices
    for _,v in ipairs( tolinki ) do
      tables[idx][v[2]],tables[idx][v[1]] =  tables[idx][v[1]],nil
    end
  end
  return tables[1]
end



--- Recursive COnvert functions

--- Recursive COnvert functions

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
      newthing = char2..'userdata'
  else  -- Expect a LUA accetable type
      newthing = thing
  end
  return newthing and newthing or thing
end

function ConvertGUIDToUserData(str)
  if str:sub(1,4) == '#$$#' then -- Is a GUID
      local userdata
      local tipo = str:match('%a+') -- Get type name #$$#NAME{GUID}
      local guid = str:match('{.+}')

      if tipo == 'Track'  then
          userdata = reaper.BR_GetMediaTrackByGUID(0, guid)
      elseif tipo == 'Item' then
          userdata = reaper.BR_GetMediaItemByGUID(0, guid)
      elseif tipo == 'Take' then
          userdata = reaper.GetMediaItemTakeByGUID(0, guid)
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

---+-----





function LoadPreset(table_preset)
    local settings = {}
    for key, value in pairs(table_preset) do
        settings[key] = value
    end
    return settings
end


function LoadInitialPreset() -- Here is set the default settings For the Simple Sampler
    if file_exists(script_path .. "/" .. 'user_presets' .. ".json") == false then -- If there is no json file
        UserPresets = {}
        UserPresets.Default = {
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
            Pitch_Original = 60
        }
        save_json(script_path, 'user_presets', UserPresets)
    else
        UserPresets = load_json(script_path, 'user_presets')
    end
    if UserPresets.LS_Hide then
        Settings = LoadPreset(UserPresets.LS_Hide)
    else  
        Settings = LoadPreset(UserPresets.Default)
    end   
end

function LoadInitialPreseetGroups()
    local project_path = GetProjectPath()
    local  retval, val = reaper.GetProjExtState(0, 'ItemSampler', 'Groups')
    if val ~= '' then
        local load_table = table.load(val)
        load_table = ConvertGUIDToUserDataRecursive(load_table)
        Groups = load_table.Groups
        Settings = load_table.Settings
        UserPresets = load_table
    else
        UserPresets ={}
        Settings = {}
        Settings.Tips = true
        Groups = {}
        Groups[1] = BlankGroup:Create('G1') -- If there is no json file
        UserPresets.Settings = Settings
        UserPresets.Groups = Groups
        UserPresets['Default'] = {
          Setting = table_copy(Settings),
          Groups = table_copy(Groups)
        }
    end   

    if file_exists(script_path .. "/" .. 'user_presets_complete' .. ".json") == false then
      GlobalPresets = {}
    else
      GlobalPresets = load_json(script_path, 'user_presets_complete')
    end
end


function SaveUserPreset() -- Sampler Complete Function

    UserPresets.Groups = Groups
    UserPresets.Settings = Settings
    local save = CovertUserDataToGUIDRecursive(UserPresets)
    local save = table.save(save)
    reaper.SetProjExtState( 0, 'ItemSampler', 'Groups', save )
  
end

-- User Preset (I am saving and loading this)
  -- Groups
  -- Settings
    -- Tips
    -- ListMidi
  -- Presets
    -- k = Name
        --Groups
        --Settings
    -- ...
  