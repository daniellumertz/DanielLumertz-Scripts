-- @noindex
local OSC = {}

-------------
----encode / decode
-------------

---Encode an OSC message with address and values using the OSC format: `address ,types values`. 
---@param address string OSC address
---@param ... number|string the values to send in this message
---@return string osc_message return the address and values as the osc message 
function OSC.encode(address,...)
  -- append \0 at the end of the string. https://opensoundcontrol.stanford.edu/spec-1_0-examples.html. for 'data' (4bytes) it adds 4, for 'osc'(3bytes) it adds 1. Return the 
  ---@param str string string 
  ---@return string string the appended string, like \0\0\0\0
  ---@return number nul_count count of null added
  local function append(str) 
    local len = str:len()
    local nul = '\0'
    local n = 4 - (len%4)
    return str..nul:rep(n), n
  end
  local values = {...}

  local types_str, val_str = ',', ''
  for k, v in ipairs(values) do
    if type(v) == 'number' then
      if math.type(v) == 'integer' then
        types_str = types_str..'i'
        val_str = val_str .. string.pack('>i',v)
      else --float
        types_str = types_str..'f'
        val_str = val_str .. string.pack('>f',v)
      end
    elseif type(v) == 'string' then -- string
      types_str = types_str..'s'
      val_str = val_str .. append(v)
    end
  end
  local osc = append(address)
  types_str = append(types_str)
  return osc..types_str..val_str
end

---Gets an UDP message with the OSC format and return the address and the values
---@param msg string udp message
---@return string address the address of the message
---@return table values the values from this message
function OSC.decode(msg)
  local addr = msg:match('(.-)\0')
  local types, values_msg = msg:match(',(%a*)(.*)') -- get the types in a string, always after the comma. can be "i","f","s","b".
  local prepend_size = 4 - ((types:len() + 1) % 4) -- +1 because need to consider the comma at types
  values_msg = values_msg:sub(prepend_size + 1) -- remove the prepend \0 from the types 
  if addr == '' or types == '' then return 'error: no address or types' end  
  local values = {}
  for type in types:gmatch('.') do
    local value
    if     type == 'i' then 
      value = string.unpack('>i', values_msg)
      values_msg = values_msg:sub(5)
    elseif type == 'f' then 
      value = string.unpack('>f', values_msg)
      values_msg = values_msg:sub(5)
    elseif type == 's'or type == 'b' then 
      value = values_msg:match('(.-)\0')
      local len = value:len()
      local append = 4 - (len % 4) -- number of nulls after string 
      values_msg = values_msg:sub(len + append + 1)
    else
      return 'error: message contains an unknown osc type: '..type
      -- error(("unknown osc type '%s'"):format(type)) -- alternative 
    end
    values[#values+1] = value
  end
  return addr, values
end

------------
-------- Receive UDP
-------------
---Return all UDP Messages in the buffer inside a table, from olderst to newest
---@param udp udp
---@return table messages {msgA, msgB}
function OSC.UDP_Receive(udp) -- Go through the buffer and return all messages in a table. 
  local messages = {}
	--udp:settimeout(0.0001) -- udp:receive block until have a message or timeout. values like (1) will make REAPER laggy.
	while true do
		local udp_message = udp:receive()
		if not udp_message then break end
		messages[#messages+1] = udp_message
	end
	return messages
end

---Go through the buffer and just return the newest message. Might skip messages between defer cycles.
---@param udp udp
---@return string message udp message
function OSC.UDP_ReceiveNewest(udp) 
	local data
	--udp:settimeout(0.0001) -- udp:receive block until have a message or timeout. values like (1) will make REAPER laggy.
	while true do
		local udp_message = udp:receive()
		if not udp_message then break end
		data = udp_message
	end
	return data
end

---Iterator function to go through all UDP messages on the buffer, from oldest to newest.
---@param udp udp
---@return function
function OSC.UDP_enumReceive(udp)
  return function ()
    --udp:settimeout(0.0001) -- udp:receive block until have a message or timeout. values like (1) will make REAPER laggy.
    local udp_message = udp:receive()
    if not udp_message then return end
    return udp_message
  end  
end

------------
-------- Receive OSC
-------------

---Iterator function to go through the message buffer. Return the address and the values. Start at the oldest and go to the newest message. ex:`for addr, values in osc.enumReceive do` ....
---@param udp udp
---@return function
function OSC.enumReceive(udp)
  return function ()
    local udp_message = udp:receive()
    if not udp_message then return end
    local address, values = OSC.decode(udp_message)
    return address, values
  end  
end

---Receive All OSC messages in the buffer. Return inside a table. 
---@param udp udp udp address
---@return table osc_messages each value in the table is a osc message. 1 key for the oldest message, 2 for the next oldest etc... inside each value is another table {address = string, values = {10,20,30,"values from the osc message here"}}
function OSC.Receive(udp)
  local t = {}
  for address, values in OSC.enumReceive(udp) do
    t[#t+1] = {address = address, values = values}
  end
  return t
end

return OSC