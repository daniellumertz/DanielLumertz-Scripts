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

-- Get UDP
local udp = assert(socket.udp())
assert(udp:setsockname("127.0.0.1",9004)) -- Set IP and PORT
udp:settimeout(0.0001) -- Dont forget to set a low timeout! udp:receive block until have a message or timeout. values like (1) will make REAPER laggy.


-- Main function
local function Main()
  local method = 1 -- change the method to get the osc. 

  if method == 1 then -- using the OSC iterator function
    for address, values in osc.enumReceive(udp) do
      print('address: ', address)
      print('This message haves '..#values..' values:')
      for k, v in ipairs(values) do
        print('    ', v)
      end
    end

  elseif method == 2 then -- getting OSC as a table
    local t = osc.Receive(udp)
    for k, v in ipairs(t) do
      print('address: ', v.address)
      print('This message haves '..#v.values..' values:')
      for k2, v2 in ipairs(v.values) do
        print('    ', v2)
      end
    end
  
  elseif method == 3 then -- using the UDP iterator function
    for msg in osc.UDP_enumReceive(udp) do
      local address, values = osc.decode(msg)
      print('address: ', address)
      print('This message haves '..#values..' values:')
      for k, v in ipairs(values) do
        print('    ', v)
      end
    end
  
  elseif method == 4 then -- getting all UDP messages as a table
    local t = osc.UDP_Receive(udp)
    for k, v in ipairs(t) do
      local address, values = osc.decode(v)
      print('address: ', address)
      print('This message haves '..#values..' values:')
      for k, v in ipairs(values) do
        print('    ', v)
      end
    end

  elseif method == 5 then -- Getting just the newest udp message and cleaning the buffer
    local msg = osc.UDP_ReceiveNewest(udp)
    if msg then
      local address, values = osc.decode(msg)
      print('address: ', address)
      print('This message haves '..#values..' values:')
      for k, v in ipairs(values) do
        print('    ', v)
      end
    end
    
  end

	reaper.defer(Main)
end

--- Script: 
Main()