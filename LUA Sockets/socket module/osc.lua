-- @noindex


----------------- Send
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

----------------- Receive
-- This is actually a UDP Receive function...
function ReceiveAll(udp) -- Will receive all values in that port. If there is a overflow it wont keep up in real time, as it gets one value per defer. 
	local data
	udp:settimeout(0.0001) -- udp:receive block until have a message or timeout. values like (1) will make REAPER laggy. 
	data = udp:receive()
	return data
end

function ReceiveNewest(udp) -- Get the newest message in the port. Might skip messages between defer cycles.
	local data
	udp:settimeout(0.0001) -- udp:receive block until have a message or timeout. values like (1) will make REAPER laggy.
	while true do
		local udp_message = udp:receive()
		if not udp_message then break end
		data = udp_message
	end
	return data
end