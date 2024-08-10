-- @noindex

function open_url(url)
  local OS = reaper.GetOS()
  if (OS == "OSX32" or OS == "OSX64") or OS == 'macOS-arm64' then
    os.execute('open "" "' .. url .. '"')
  else
    os.execute('start "" "' .. url .. '"')
  end
end

function str_split(s, delimiter)
  result = {};
  for match in (s..delimiter):gmatch("(.-)"..delimiter) do
    table.insert(result, match);
  end
  return result;
end

function deepcopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[deepcopy(orig_key)] = deepcopy(orig_value)
    end
    setmetatable(copy, deepcopy(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
end

function print_table(node)
  local cache, stack, output = {},{},{}
  local depth = 1
  local output_str = "{\n"
  while true do
    local size = 0
    for k,v in pairs(node) do
      size = size + 1
    end
    local cur_index = 1
    for k,v in pairs(node) do
      if (cache[node] == nil) or (cur_index >= cache[node]) then
        if (string.find(output_str,"}",output_str:len())) then
          output_str = output_str .. ",\n"
        elseif not (string.find(output_str,"\n",output_str:len())) then
          output_str = output_str .. "\n"
        end
        table.insert(output,output_str)
        output_str = ""
        local key
        if (type(k) == "number" or type(k) == "boolean") then
          key = "["..tostring(k).."]"
        else
          key = "['"..tostring(k).."']"
        end
        if (type(v) == "number" or type(v) == "boolean") then
          output_str = output_str .. string.rep('\t',depth) .. key .. " = "..tostring(v)
        elseif (type(v) == "table") then
          output_str = output_str .. string.rep('\t',depth) .. key .. " = {\n"
          table.insert(stack,node)
          table.insert(stack,v)
          cache[node] = cur_index+1
          break
        else
          output_str = output_str .. string.rep('\t',depth) .. key .. " = '"..tostring(v).."'"
        end
        if (cur_index == size) then
          output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
        else
          output_str = output_str .. ","
        end
      else
        if (cur_index == size) then
          output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
        end
      end
      cur_index = cur_index + 1
    end
    if (size == 0) then
      output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
    end
    if (#stack > 0) then
      node = stack[#stack]
      stack[#stack] = nil
      depth = cache[node] == nil and depth + 1 or depth - 1
    else
      break
    end
  end
  table.insert(output,output_str)
  output_str = table.concat(output)
  p(output_str)
end