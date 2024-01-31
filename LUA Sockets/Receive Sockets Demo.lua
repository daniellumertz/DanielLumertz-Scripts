-- @noindex
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

local socket = require('socket.core')
require('osc') -- Load OSC help Functions for send/Receive

local udp = assert(socket.udp())
assert(udp:setsockname("127.0.0.1",9004)) -- Set IP and PORT

---- Functions
function print(val)
    reaper.ShowConsoleMsg('\n'..tostring(val))
end

local function Main()

  local val = ReceiveNewest(udp)
  --local val = ReceiveAll(udp)
  if val then
  	print(val)
  end

	reaper.defer(Main)
end


--- Script: 
Main()