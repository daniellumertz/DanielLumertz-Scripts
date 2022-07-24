-- @noindex
---------------------
----------------- Print/Debug
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

function PrintDeltaTime(start)
  print(reaper.time_precise()  - start)
end

---------------------
----------------- Table
---------------------

---It uses ipairs if want to use in a table with strings as keys change to pairs
---@param tab table table iterate to check values
---@param val any value to be checked
---@return boolean, any
function TableHaveValue(tab, val) -- Check if table have val in the values. (Uses) 
    for index, value in ipairs(tab) do
        if value == val then
            return true, index
        end
    end
    return false, false
end

function TablesCombine(table1,table2)
    for key, value in pairs(table1) do
        table.insert(table2,value)
    end
    return table2
end

---Simple Table Copy. Very Fast!. Dont return string keys ! Return Tables within tables! Dont return recursive tables. Dont know what it does with metatables
---@param t table
---@return table
function TableCopy(t) -- From http://lua-users.org/wiki/CopyTable
  return {table.unpack(t)}
end

function TablesCombineKeys(table1,table2) -- Presume the values inside keys are tables so I add them. If not I Convert to a table and add them 
    for key, value in pairs(table1) do
        if table2[key] then
            if type(table2[key]) ~= "table" then 
                local temp_value = table2[key] 
                table2[key] = {}
                table.insert(table2[key],temp_value)
            end
            if type(value) ~= 'table' then
                table.insert(table2[key],value)
            else
                table2[key] = TablesCombine(value,table2[key])
            end
        else
            table2[key] = value
        end  
    end
    return table2
end


function TableValuesCompareNoOrder(table1,table2) --  Check if both tables haves the same values. 
    if #table1 ~= #table2 then return false end
    local used_keys = {}
    for key, item in pairs(table1) do
        local bol = false -- if one item isnt found then break
        for key2, item2 in pairs(table2) do
            if not used_keys[key2] and (item == item2 or tostring(item) == tostring(item2) )then
                used_keys[key2] = true
                bol = true
                break
            end
        end 
        if not bol then return false end
    end
    if #used_keys == #table1 then return true else return false end
end

function TableLen(table)
    local c = 0
    for k,v in pairs(table) do 
        c = c + 1 
    end
    return c
end

function TableValuesCompareAtLeastOne(table1,table2) -- At least one in common
    for key, item in pairs(table1) do
        for key2, item2 in pairs(table2) do
            if item == item2 then return true end
        end 
    end
    return false
end

function TableValuesCompareCount(table1,table2) --Count values that are equal in both tables, wihtout order. Each repeated value is only considered once lie {2,6,4,6} and {6,6,6} will result in 1
    local used_keys = {}
    local cnt = 0
    for key, item in pairs(table1) do
        for key2, item2 in pairs(table2) do
            if not used_keys[key2] and (item == item2 or tostring(item) == tostring(item2) ) then
                used_keys[key2] = true
                cnt = cnt + 1
                break
            end
        end 
    end
    return cnt
end

--function to get randomly from a table
function GetFromTableRandom(t)
    local n = #t
    local r = math.random(n)
    return t[r]
  end

  -- lua remove repeated in a table
function TableRemoveRepeated(table)
    local new_table = {}
    for index, value in ipairs(table) do
        if not TableHaveValue(new_table, value) then
            new_table[#new_table+1] = value
        end
    end
    return new_table
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

---Get a table with all keys from a table.
---@param t table table to extract the keys
---@return table table with all keys as values.
function GetKeys(t)
    local t_keys = {}
    for key, value in pairs(t) do
        t_keys[#t_keys+1] = key
    end
    table.sort(t_keys)
    return t_keys
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

---Scale a number between a new min and max value
---@param input number number to be scaled
---@param min number ex-minimum number
---@param max number ex-maximum number
---@param new_min number new minimum number
---@param new_max number new maximum number
---@return number number scaled number
function ScaleNumber(input, min, max, new_min, new_max)
  return (((input - min) / (max - min)) * (new_max - new_min)) + new_min
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

---------------------
----------------- Windows
---------------------

---Usefull to set Last Touched Param
function MouseClick() 
    local x, y = reaper.GetMousePosition()
    local w = reaper.JS_Window_FromPoint(x, y)
    local x, y = reaper.JS_Window_ScreenToClient(w, x, y)
    reaper.JS_WindowMessage_Post(w, "WM_LBUTTONDOWN", 1, 0, x, y)
    reaper.JS_WindowMessage_Post(w, "WM_LBUTTONUP", 0, 0, x, y)
end

---------------------
----------------- Strings
---------------------

function literalize(str)
	return str:gsub(
		"[%(%)%.%%%+%-%*%?%[%]%^%$]",
		function(c)
			return "%" .. c
		end
	)
end

function SubString(big_string,sub) -- Iterator function that return matches of sub in big_string. More less like gmatch but allow soberpossed macheses like in "ababc" trying to get "ab." will retunr "aba","abc"
	local start_char = 1
	return function ()
		local match =string.match(big_string,sub,start_char) -- Check if there is a match after start_char
		if match then 
			local s, e =string.find(big_string,literalize(match),start_char)
			start_char = e

			return match
		end
		return nil -- break for loop        
	end
end
