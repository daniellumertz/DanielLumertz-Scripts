--@noindex
-- If you want to ship the sockets files within your script
local info = debug.getinfo(1, 'S');
local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]];
package.cpath = package.cpath .. ";" .. script_path .. "?.dll"  -- Add current folder for looking at .dll
package.path = package.path .. ";" .. script_path .. "/lua/?.lua" -- Add current folder/lua for looking at .lua (where mobdebug is)

-- if you want to load the sockets from Mavroq repository
--package.cpath = package.path .. ";" .. reaper.GetResourcePath() .. '\\Scripts\\Mavriq ReaScript Repository\\Various\\Debugging\\?.dll' 
--package.path = package.path .. ";" .. reaper.GetResourcePath() .. '\\Scripts\\Mavriq ReaScript Repository\\Various\\Debugging\\?.lua'


function print(val)
    reaper.ShowConsoleMsg('\n'..tostring(val))
end

local socket = require('socket.core')
local udp = assert(socket.udp())
assert(udp:setsockname("127.0.0.1",9004)) -- Set IP and PORT


function ReceiveAll() -- Will receive all values in that port. If there is a overflow it wont keep up in real time, as it gets one value per defer. 
	local data
	udp:settimeout(0.0001) -- udp:receive block until have a message or timeout. values like (1) will make REAPER laggy. 
	data = udp:receive()
	return data
end

function ReceiveNewest() -- Get the newest message in the port. Might skip messages between defer cycles.
	local data
	udp:settimeout(0.0001) -- udp:receive block until have a message or timeout. values like (1) will make REAPER laggy.
	while true do
		local udp_message = udp:receive()
		if not udp_message then break end
		data = udp_message
	end
	return data
end


local function Main()


    -- Start the coroutine, or resume from where it was paused
    -- Returns the value passed to coroutine.yield, above.
    local val = ReceiveNewest()
    if val then
		print(val)
    end

	reaper.defer(Main)

end

Main()