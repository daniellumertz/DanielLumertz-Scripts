-- @noindex
-- Test Using Other .lua Sockets functions like url.lua
-- If you wont use the others .lua functions you can remove it!
-- HTTP is not working it seems to require another module for HTTPS: luasec
local opsys = reaper.GetOS()
local extension 
if opsys:match('Win') then
  extension = 'dll'
else
  extension = 'so'
end

local info = debug.getinfo(1, 'S');
local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]];
package.cpath = package.cpath .. ";" .. script_path .. "/socket module/?."..extension  -- Add current folder/socket module for looking at .dll (need for loading basic luasocket)
package.path = package.path .. ";" .. script_path .. "/socket module/?.lua" -- Add current folder/socket module for looking at .lua ( Only need for loading the other functions packages lua osc.lua, url.lua etc... You can change those files path and update this line)ssssssssssssssssssssssssssssssssssss


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
