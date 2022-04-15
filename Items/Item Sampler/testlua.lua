function print( ...) 
  local t = {}
  for i, v in ipairs( { ... } ) do
    t[i] = tostring( v )
  end
  reaper.ShowConsoleMsg( table.concat( t, "\n" ) .. "\n" )
end

-- Load the json functions
package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
local json = require ("./core.dll")

print(package.path)