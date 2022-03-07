-- @noindex
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

function LoadExtStateTable(script_name, key, convert_GUID)
    local tabela = {} -- debug put as local
    local retval, table_string = reaper.GetProjExtState(0, script_name, key)

    if retval == 1 and table_string ~= '' then
        tabela = table.load( table_string )
    else 
        return false
    end

    if convert_GUID then 
        tabela = ConvertGUIDToUserDataRecursive(tabela)
    end
    return tabela
end

function SaveExtStateTable(script_name, key, tabela, convert_GUID)
    if convert_GUID then 
        tabela = CovertUserDataToGUIDRecursive(tabela)
    end 
    local table_string = table.save( tabela )

    reaper.SetProjExtState( 0, script_name, key, table_string )
end