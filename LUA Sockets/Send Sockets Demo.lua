-- @noindex
-- Load the socket module
local opsys = reaper.GetOS()
local extension 
if opsys:match('Win') then
  extension = 'dll'
else -- Linux and Macos
  extension = 'so'
end

local info = debug.getinfo(1, 'S');
local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]];
package.cpath = package.cpath .. ";" .. script_path .. "/socket module/?."..extension  -- Add current folder/socket module for looking at .dll (need for loading basic luasocket)
package.path = package.path .. ";" .. script_path .. "/socket module/?.lua" -- Add current folder/socket module for looking at .lua ( Only need for loading the other functions packages lua osc.lua, url.lua etc... You can change those files path and update this line)ssssssssssssssssssssssssssssssssssss

-- Functions
function print(...) 
  local t = {}
  for i, v in ipairs( { ... } ) do
      t[i] = tostring( v )
  end
  reaper.ShowConsoleMsg( table.concat( t, " " ) .. "\n" )
end

-- Get socket and osc modules
local socket = require('socket.core')
local osc = require('osc')

-- Define the udp, ip, port
local host, port = "localhost", 9005
-- convert host name to ip address
local ip = assert(socket.dns.toip(host))
-- create a new UDP object
local udp = assert(socket.udp())

-- Encoding some cool messages to send via OSC 
local msg1 = osc.encode('/track 1/fx parameters', 666, 3.14, 'hello world!')-- encoding osc message with the address `/track 1/fx parameters` the values are a random integer, a flot and a string
local msg2 = osc.encode('/project/0/number of tracks', reaper.CountTracks(0))

-- Send message
--udp:sendto(msg1, ip, port)
udp:sendto(msg2, ip, port)

