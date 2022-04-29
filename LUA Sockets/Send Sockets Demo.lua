-- @noindex
function print(val)
  reaper.ShowConsoleMsg(tostring(val)..'\n')
end

-- If you want to ship the sockets files within your script uncomment these lines (it is recommended to use Mavriq repository with his dll and so files this way user will have the latest version without you needing to update. Also will avoid confusion with multiple binaries files.)
--[=[ local info = debug.getinfo(1, 'S');
local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]];
package.cpath = package.cpath .. ";" .. script_path .. "/socket module/?.dll"  -- Add current folder/socket module for looking at .dll (need for loading basic luasocket)
package.cpath = package.cpath .. ";" .. script_path .. "/socket module/?.so"  -- Add current folder/socket module for looking at .so (need for loading basic luasocket)
package.path = package.path .. ";" .. script_path .. "/socket module/?.lua" -- Add current folder/socket module for looking at .lua ( Only need for loading the other functions packages lua osc.lua, url.lua etc... You can change those files path and update this line) ]=]

-- if you want to load the sockets from Mavriq repository:
package.cpath = package.cpath .. ";" .. reaper.GetResourcePath() ..'/Scripts/Mavriq ReaScript Repository/Various/Mavriq-Lua-Sockets/?.dll'    -- Add current folder/socket module for looking at .dll
package.cpath = package.cpath .. ";" .. reaper.GetResourcePath() ..'/Scripts/Mavriq ReaScript Repository/Various/Mavriq-Lua-Sockets/?.so'    -- Add current folder/socket module for looking at .so
package.path = package.path .. ";" .. reaper.GetResourcePath() ..'/Scripts/Mavriq ReaScript Repository/Various/Mavriq-Lua-Sockets/?.lua'    -- Add current folder/socket module for looking at .so


-- load namespace
local socket = require('socket.core')
require('osc')

-- Defnining some cool messages to send via OSC 
local msg1 = osc_encode('/oscillator/4/frequency', 'f', 440.0)
local msg2 = osc_encode('/foo', 'i', 1000, 'i', -1, 's', 'hello', 'f', 1.234, 'f', 5.678) -- Sending many Values types
---msg3 = nº selected items 
local cnt = reaper.CountSelectedMediaItems(0)
local msg3 = osc_encode('/items/cnt', 'i', cnt)
--msg4 = Send item path
local path
if cnt > 0 then
    local item = reaper.GetSelectedMediaItem(0, 0)
    local take = reaper.GetMediaItemTake(item, 0)
    local source =  reaper.GetMediaItemTake_Source( take )
    path = reaper.GetMediaSourceFileName( source )
    msg4 = osc_encode('/items/path', 's', path)
end
--

-- Send message
-- change here to the host an port you want to contact
local host, port = "localhost", 9004
-- convert host name to ip address
local ip = assert(socket.dns.toip(host))
-- create a new UDP object
local udp = assert(socket.udp())
-- contact daytime host
--local m_byte = string.getBits32(message)
assert(udp:sendto(msg1, ip, port))
-- retrieve the answer and print results
--io.write(assert(udp:receive()))