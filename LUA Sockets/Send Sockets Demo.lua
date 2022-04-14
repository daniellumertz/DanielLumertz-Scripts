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
    reaper.ShowConsoleMsg(tostring(val)..'\n')
end

-- Thanks CF ❤️
function align(size)
    local remain = size % 4
    if remain == 0 then return size end
    return size + 4 - (size % 4)
end
  
function osc_encode(address, ...)
    local args, format, data = { ... }, '>c%dc%d', { address, ',' }
  
    for i = 1, #args, 2 do
      local t, v, f = args[i], args[i + 1]
      assert(v, ('data field %d does not have a value'):format(math.ceil(i/2)))
  
      if     t == 'i' then f = 'i4'
      elseif t == 'f' then f = 'f'
      elseif t == 's' then f = ('c%d'):format(align(v:len() + 1))
      elseif t == 'b' then
        f = ('I4c%d'):format(align(v:len()))
        table.insert(data, v:len())
      else
        error(("unknown osc type '%s' for data field %d"):format(t, math.ceil(i/2)))
      end
  
      data[2] = data[2] .. t
      format = format .. f
      table.insert(data, v)
    end
  
    local addrlen = align(data[1]:len() + 1)
    local typelen = align(data[2]:len() + 1)
    return string.pack(format:format(addrlen, typelen), table.unpack(data))
end
  

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
local host, port = "localhost", 9005
-- load namespace
local socket = require('socket.core')
-- convert host name to ip address
local ip = assert(socket.dns.toip(host))
-- create a new UDP object
local udp = assert(socket.udp())
-- contact daytime host
--local m_byte = string.getBits32(message)
assert(udp:sendto(msg1, ip, port))
-- retrieve the answer and print results
--io.write(assert(udp:receive()))