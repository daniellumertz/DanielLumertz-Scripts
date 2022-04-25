-- @noindex
-- Test Using Other .lua Sockets functions like url.lua
-- If you wont use the others .lua functions you can remove it!
-- HTTP is not working it seems to require another module for HTTPS: luasec
-- If you want to ship the sockets files within your script
local info = debug.getinfo(1, 'S');
local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]];
package.cpath = package.cpath .. ";" .. script_path .. "/socket module/?.dll"  -- Add current folder/socket module for looking at .dll (need for loading basic luasocket)
package.cpath = package.cpath .. ";" .. script_path .. "/socket module/?.so"  -- Add current folder/socket module for looking at .so (need for loading basic luasocket)
package.path = package.path .. ";" .. script_path .. "/socket module/?.lua" -- Add current folder/socket module for looking at .lua ( Only need for loading the other functions packages lua osc.lua, url.lua etc... You can change those files path and update this line)

-- if you want to load the sockets from Mavriq repository (User will need to download Mavriq project from reapack, and will receive updates as Mavriq update his repository)
--[[ package.cpath = package.cpath .. ";" .. reaper.GetResourcePath() ..'/Scripts/Mavriq ReaScript Repository/Various/Mavriq-Lua-Sockets/?.dll'    -- Add current folder/socket module for looking at .dll
package.cpath = package.cpath .. ";" .. reaper.GetResourcePath() ..'/Scripts/Mavriq ReaScript Repository/Various/Mavriq-Lua-Sockets/?.so'    -- Add current folder/socket module for looking at .so
package.path = package.path .. ";" .. reaper.GetResourcePath() ..'/Scripts/Mavriq ReaScript Repository/Various/Mavriq-Lua-Sockets/?.lua'    -- Add current folder/socket module for looking at .so
 ]]

function print(val)
    reaper.ShowConsoleMsg('\n'..tostring(val))
end

local url = require("url")

local parse = url.parse('https://www.reaper.fm/')

for k, v in pairs(parse) do
  print('k :')
  print(k)
  print('v :')
  print(v)
  print('      ---      ')
  
end
