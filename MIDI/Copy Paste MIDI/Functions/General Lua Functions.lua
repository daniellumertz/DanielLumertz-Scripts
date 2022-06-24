-- @noindex
---------------------
----------------- Print
---------------------

function print(...) 
    local t = {}
    for i, v in ipairs( { ... } ) do
      t[i] = tostring( v )
    end
    reaper.ShowConsoleMsg( table.concat( t, "\n" ) .. "\n" )
end

function tprint (tbl, indent)
    if not indent then indent = 0 end
    for k, v in pairs(tbl) do
      formatting = string.rep("  ", indent) .. tostring(k) .. ": "
      if type(v) == "table" then
        print(formatting)
        tprint(v, indent+1)
      elseif type(v) == 'boolean' then
        print(formatting .. tostring(v))      
      else
        print(formatting .. tostring(v))
      end
    end
end

---------------------
----------------- Table
---------------------

---It uses ipairs if want to use in a table with strings as keys change to pairs
---@param tab table table iterate to check values
---@param val any value to be checked
---@return boolean
function TableHaveValue(tab, val) -- Check if table have val in the values. (Uses) 
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

---Simple Table Copy. Very Fast!. Dont return string keys ! Return Tables within tables! Dont return recursive tables. Dont know what it does with metatables
---@param t table
---@return table
function TableCopy(t) -- From http://lua-users.org/wiki/CopyTable
  return {table.unpack(t)}
end

---Create a copy of the tablee with all children tables new as well. 
---@param thing any
---@return table
function table_copy_regressive(thing)
  if type(thing) == 'table' then
      local new_table = {}
      for k , v in pairs(thing) do
          local new_v = table_copy_regressive(v)
          local new_k = table_copy_regressive(k)
          new_table[new_k] = new_v
      end
      return new_table
  else 
      return thing
  end
end

---Perform a binary search in a sorted table and return the index of the closest value smaller than val  
---@param t table the table values needs to be sorted. And only using integers as indexes, without gaps 
---@param val number
---@return number
function BinarySearchInTable(t,val)
  local floor = 1
  local ceil = #t
  local i = math.floor(ceil/2)
  -- Try to get in the edges after the max value and before the min value
  if t[#t] <= val then return #t end -- check if it is after the last t value 
  if t[1] > val then return 0 end --check if is before the first value. return 0 if it is
  -- Try to find in between values
  while true do
      -- check if is between t and t[i+1]
      if t[i+1] and t[i] <= val and val <= t[i+1] then return i end -- check if it is in between two values

      -- change the i (this is not the correct answer)
      if t[i] > val then
          ceil = i
          i = ((i - floor) / 2) + floor
          i = math.floor(i)
      elseif t[i] < val then
          floor = i
          i = ((ceil - i) / 2) + floor
          i = math.ceil(i)
      end    
  end
end
---------------------
----------------- Bit
---------------------

---transofrms num (a decimal number) as string.
---@param num number
---@param reverse boolean if false 2 = 01 if true 2 = 10. False = little endian (lsb comes first from left to right)
---@return string
function ToBits(num,reverse)
    local t={}
    while num>0 do
        local rest=math.floor(num%2)
        table.insert(t,rest)
        num=(num-rest)/2
    end 
    if #t == 0 then table.insert(t,0) end
    local binary_string = table.concat(t)
    if reverse then binary_string = binary_string:reverse() end
    return binary_string
end


function BitTabtoStr2(t, len) -- transform an BitTab in a String 
    local s = ""
    local i = 1;
    while i <= len do
      s = (tostring(t[i] or "0"))..s
      i = i + 1
    end
    return s
end

---------------------
----------------- Numbers
---------------------

---When inter = 1 return val1 when inter = 0 return val2, use decimal values (0-1) to interpolate
---@param val1 number
---@param val2 number
---@param inter number
---@return number
function InterpolateBetween2(val1,val2,inter)
	return (val1*inter)+(val2*(1-inter)) 
end

---Limit a number between min and max
---@param number number number to be limited
---@param min number minimum number
---@param max number maximum number
---@return number
function LimitNumber(number,min,max)
	if min and number < min then return min end
	if max and number > max then return max end
	return number
end

---------------------
----------------- MISC
---------------------

function open_url(url)
  local OS = reaper.GetOS()
  if OS == "OSX32" or OS == "OSX64" then
    os.execute('open "" "' .. url .. '"')
  else
    os.execute('start "" "' .. url .. '"')
  end
end