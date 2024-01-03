--@noindex
--version: 0.11
-- get files names
---------------------
----------------- Debug/Prints 
---------------------
function print(...) 
    local t = {}
    for i, v in ipairs( { ... } ) do
        t[i] = tostring( v )
    end
    reaper.ShowConsoleMsg( table.concat( t, " " ) .. "\n" )
end

---Create/append a file with some string 
---@param path string path with a file name as : "C:\\Users\\DSL\\Downloads\\test files\\hello.txt"
---@param ... any something to print, it will be converted using tostring, pass as much arguments as needs, they will be concatenated with ' '
function filePrint(path,...)
    local t = {}
    for i, v in ipairs( { ... } ) do
        t[i] = tostring( v )
    end
    local txt =  table.concat( t, " " )

    -- Specify the file path and name
    local file_path = path

    -- Open the file for writing
    local file = io.open(file_path, "a")

    if file then
        -- Append at the file
        file:write('\n'..txt)
        
        -- Close the file
        file:close()
        --print("File created and data written successfully.")
        return true
    else
        --print("Error opening the file for writing.")
        return false
    end
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

function literalize(str)
    return str:gsub(
        "[%(%)%.%%%+%-%*%?%[%]%^%$]",
        function(c)
        return "%" .. c
        end
    )
end

function CalcTime(start)
    print(reaper.time_precise() - start)
end

---Return time as a string in hour:min:sec
function getTime()
    local time = os.date("*t")
    local hour = ("%02d:%02d:%02d"):format(time.hour, time.min, time.sec)
    return hour
end

---------------------
----------------- Strings 
---------------------
function table.subs(tbl, val) -- Insert something at the end of the table and remove the smalest index
    table.remove(tbl,1)
    table.insert(tbl,#tbl+1,val)
end



function SubString(big_string,sub) -- Iterator function that return matches of sub in big_string. More less like gmatch but allow soberpossed macheses like in "ababc" trying to get "ab." will retunr "aba","abc"
    local start_char = 1
    return function ()
        while true do
            local s, e =string.find(big_string,sub,start_char) -- Check if there is a match after start_char
            if s then
                start_char = s + 1
                return string.sub(big_string, s, e)
            else -- No more matches
                break
            end
        end
        return nil -- break for loop        
    end
end
---------------------
----------------- Tables
---------------------

---Check for indexes inside a table. ex: TableCheckValues(t, 1) checks if t[1]. TableCheckValues(t, 2,3,5) checks if t[2][3][5]. This function dont throw any erros. Like if you try to t[2][3][5] but t[2] or t[2][3] isnt a table, it will throw an  error.
---@param t table
---@param ... any numbers or strings indexes to check. 
---@return any return nil if it cant get the value. return the value if it can get to it
function TableCheckValues(t, ...) -- Made by CF
    for i = 1, select('#', ...) do -- Loop though all the arguments
        if type(t) ~= 'table' then return  end
        t = t[select(i, ...)] -- select(i, ...) will get the next value in the vararg list. (this function actually returns many values (from i to #...) but inside the [] of a table it will only get the first one )  array = array[select(i, ...)] will change array to be that new value
    end
    return t
end

---Insert a value in a table, can contain a inner table that didnt exist previouslly. like TableInsert(t, 1, 2, 3)
---@param t any
---@param ... any 
function TableInsert(t, ...)
    local n = select('#', ...)
    for i = 1, n - 2 do
        local k = select(i, ...)
        local v = t[k]
        if type(v) ~= 'table' then
            assert(not v)
            v = {}
            t[k] = v
        end
        t = v
    end
    t[select(n - 1, ...)] = select(n, ...)
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

---It uses ipairs if want to use in a table with strings as keys change to pairs with is_pairs(false by default)
---@param tab table table iterate to check values
---@param val any value to be checked
---@param is_pairs boolean if true will use pairs. else will use ipairs
---@return boolean, any
function TableHaveValue(tab, val, is_pairs) -- Check if table have val in the values. (Uses) 
    local func = is_pairs and pairs or ipairs
    for index, value in func(tab) do
        if value == val then
            return true, index
        end
    end
    return false, false
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

function TablesCombine(table1,table2)
    for key, value in pairs(table1) do
        table.insert(table2,value)
    end
    return table2
end

function TableiCopy(t)
    local t2 = {}
    for k,v in ipairs(t) do
        t2[k] = v
    end
    return t2
end

function TableCopy(t)
    local t2 = {}
    for k,v in pairs(t) do
        t2[k] = v
    end
    return t2
end

function TableDeepCopy(t)
    local t2 = {}
    for k,v in pairs(t) do
        if type(v) == "table" then
            t2[k] = TableDeepCopy(v)
        else
            t2[k] = v
        end
    end
    return t2
end

function TableHaveAnything(t)
    for k,v in pairs(t) do
        return true
    end
    return false
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

---Return a table with all keys inside a table
---@param t table
---@return table
function TableKeys(t)
    local new_table = {}
    for key, value in pairs(t) do
        new_table[#new_table+1] = key
    end
    return new_table
end

---Return a table with all keys inside a table
---@param t table
---@return table
function TableiKeys(t)
    local new_table = {}
    for key, value in ipairs(t) do
        new_table[#new_table+1] = key
    end
    return new_table
end


---Create a new table with the values keys randomized. Only randomize key that are numbers. String keys keep the same value.
---@param t any
---@return table
function RandomizeNewTable(t)
    local new_t = {}
    local keys =  TableiKeys(t) -- number keys
    for k, v in pairs(t) do
        if type(k) == 'number' then -- randomize position
            local random_idx = math.random(#keys)
            local new_k = keys[random_idx]
            new_t[new_k] = v
            table.remove(keys, random_idx)
        else -- just add equal
            new_t[k] = v
        end
    end

    return new_t
end

---Randomize keys from a table. Only randomize key that are numbers. String keys keep the same value.
---@param t table
function RandomizeTable(t)
    local old_table = TableDeepCopy(t)
    local keys = TableiKeys(t)
    for k, v in pairs(old_table) do
        if type(k) == 'number' then
            local random_idx = math.random(#keys)
            local new_k = keys[random_idx]
            t[new_k] = v
            table.remove(keys, random_idx)
        end
    end    
end



---Moves the values in a table to make it ascendent without gaps ex: t = {1 = 'a', 5 = 'c' ,9 = 'e'} will return {1 = 'a', 2 = 'c', 3 = 'e'}
---@param t table
---@return table
function TableRemoveSpaceKeys(t)
    local new_table = {}
    local keys_table = TableKeys(t)
    table.sort(keys_table)
    for index, key in ipairs(keys_table) do
        table.insert(new_table,t[key])
    end    
    return new_table
end


---Return the smaller and higher key from a table.
---@param t table
---@return number min, number max 
function TableMinMaxKeys(t)
    local min = math.huge
    local max = -math.huge
    for key, value in pairs(t) do
        if type(key) == 'number' then
            if key < min then
                min = key
            end
            if key > max then
                max = key
            end
        end   
    end
    return min,max
end

---Return a table with all values as strings
---@param t table
function TableConvertAllKeysToString(t)
    local new_table = {}
    for key, value in pairs(t) do
        new_table[tostring(key)] = value
    end
    return new_table    
end
    

---Return another table with all possible keys converted to numbers
---@param t table table to be converted
---@return table
function TableConvertKeyToNumbers(t)
    local new_table = {}
    for key, value in pairs(t) do
        local new_key =  tonumber(key) or key
        new_table[new_key] = value
    end
    return new_table
end

---Search in t table for the closest number from val.
---@param t table table to be searched
---@param val number value to be compared
---@return any closest_number_key key with the closest number
function TableGetKeyWithClosestNumber(t,val)
    local closest_number = math.huge
    local closest_number_key = nil
    for key, value in pairs(t) do
        if type(value) == 'number' then
            local dif = math.abs(value - val)
            if dif < closest_number then
                closest_number = dif
                closest_number_key = key
            end
        end
    end
    return closest_number_key
end

---Iterate function simillar as ipairs but on reverse
---@param t any
function ipairs_reverse(t)
    local i = #t 
    return function ()
        while i > 0 do 
            local key, value = i, t[i]
            i = i - 1 -- for next time
            return key, value
        end
        return nil
    end
end

---Return a key from a table randomly, if the value of a key is a table with a .weight key inside it then it will use that weight. ex: {{weight = 2, etc...},{weight = 2.7,etc...},'hello'}. This uses ipairs so the table values must have number indexes.
---@param t table
---
function TableRandomWithWeight(t)
    local function get_weight(v)
        if type(v) == 'table' then
            return v.weight or 1
        else 
            return 1
        end
    end

    local sum = 0
    for k,v in ipairs(t) do
        sum = sum + get_weight(v)
    end
    local random_number = RandomNumberFloat(0,sum,false)
    local sum_weights = 0
    for k, v in ipairs(t) do
        local w = get_weight(v)
        sum_weights = sum_weights + w
        if sum_weights > random_number then
            return k, v
        end
    end   
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
----------------- Numbers
---------------------

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

---Remove the decimal part of a number
---@param number number number to be rounded
---@return number
function RoundNumber(number)
    return math.floor(number + 0.5)
end

---Return a number to the closest quantize value, simillar to RoundNumber.
---@param num number number to be quantized
---@param quantize number quantize value
function QuantizeNumber(num,quantize_value)
    if quantize_value == 0 then return num end
    local up_value = (num + (quantize_value/2))
    local low_quantize = ((up_value / quantize_value)//1)*quantize_value
    return low_quantize
end

---Quantize a number upwards
---@param number number value to be quantized
---@param step_size number setep size 
---@return number quantized_number
function QuantizeUpwards(number, step_size)
    local remainder = number % step_size
    if remainder == 0 then
        return number
    else
        return number + (step_size - remainder)
    end
end

---When inter = 1 return val1 when inter = 0 return val2, use decimal values (0-1) to interpolate
---@param val1 number
---@param val2 number
---@param inter number
---@return number
function InterpolateBetween2(val1,val2,inter)
	return (val1*inter)+(val2*(1-inter)) 
end

---Map/Scale Val between range 1 (min1 - max1) to range 2 (min2 - max2)
---@param value number Value to be mapped
---@param min1 number Range 1 min
---@param max1 number Range 1 max
---@param min2 number Range 2 min
---@param max2 number Range 2 max
---@return number
function MapRange(value,min1,max1,min2,max2)
    return (value - min1) / (max1 - min1) * (max2 - min2) + min2
end

---Slide/Slope old_val in direction of new_val.
---@param old_val number old value
---@param new_val number value trying to be catched up
---@param max_time_going_up number time it takes to go from min to max. 0 is instantaneos 
---@param max_time_going_down number time it takes to go from max to min. 0 is instantaneos 
---@param elapsed_time number time passed (normally calculated from last call)
---@param min number minimum value
---@param max number maximum value
function Slide(old_val,new_val,max_time_going_up, max_time_going_down,elapsed_time,min,max)
    local max_distance = max - min
    local is_going_up = new_val > old_val 
    local time  = (is_going_up and max_time_going_up) or max_time_going_down -- time it takes to go from 0to1 or 1to0, in seconds
    if time <= 0 then -- no slide
        return new_val
    else
        local speed = max_distance / time --speed of value/second
        speed = speed * elapsed_time
        speed = LimitNumber(speed, min, max) -- just in case
        speed = is_going_up and speed or -speed
        local result = old_val + speed
        result = is_going_up and LimitNumber(result, min, new_val) or LimitNumber(result, new_val, max)
        return result
    end    
end

---Generate a random number between min and max.
---@param min number minimum value
---@param max number maximum value
---@param is_include_max boolean if true it can result on the max value
---@return number
function RandomNumberFloat(min,max,is_include_max)
    local sub = (is_include_max and 0) or 1 --  -1 because it cant never be the max value. Lets say we want to choose random between a and b a have 2/3 chance and b 1/3. If the random value is from 0 - 2(not includded) it is a, if the value is from 2 - 3(not includded) it is b. 
    local big_val = 1000000 -- the bigger the number the bigger the resolution. Using 1M right now
    local random = math.random(0,big_val-sub) -- Generating a very big value to be Scaled to the sum of the chances, for enabling floats.
    random = MapRange(random,0,big_val,min,max) -- Scale the random value to the sum of the chances

    return random
end

---Generate a random number between min and max, quantize it.
---@param min number minimum value
---@param max number maximum value
---@param is_include_max boolean if true it can result on the max value
---@param quantize number quantize value
---@return number
function RandomNumberFloatQuantized(min,max,is_include_max,quantize)
    local num = RandomNumberFloat(min,max,is_include_max)
    return QuantizeNumber(num, quantize)    
end

function RemoveDecimals(num,decimal_places)
    local int_num = math.floor(num * 10^decimal_places)
    return int_num / 10^decimal_places    
end

--- Return dbval in linear value. 0 = -inf, 1 = 0dB, 2 = +6dB, etc...
function dBToLinear(dbval)
    return 10^(dbval/20) 
end

--- Return value in db. 0 = -inf, 1 = 0dB, 2 = +6dB, etc...
function LinearTodB(value)
    return 20 * math.log(value,10)    
end

---Compare versions. Check and min versions must have the same amount of versions numbers. Like 0.7.2 and 0.7.0
---@param check_version string version to check 
---@param min_version string min version
---@param separator string separator
---@return boolean retval did it passed the filters? 
---@return string why reason it didnt pass the filter. return 'min' or 'max'. if passed it will return nil
function CompareVersion(check_version, min_version, max_version, separator)
    separator = separator or '.'
    local check_table = {}
    for version in check_version:gmatch('(%d+)'..separator..'?') do
        check_table[#check_table+1] = tonumber(version)
    end

    local min_table
    if min_version then
        min_table = {}
        for version in min_version:gmatch('(%d+)'..separator..'?') do
            min_table[#min_table+1] = tonumber(version)
        end
    end

    local max_table
    if max_version then
        max_table = {}
        for version in max_version:gmatch('(%d+)'..separator..'?') do
            max_table[#max_table+1] = tonumber(version)
        end
    end

    for index, check_v in ipairs(check_table) do
        -- check if is less than the min_version
        if min_table and check_v < (min_table[index] or 0) then
            return false, 'min'
        elseif min_table and check_v > (min_table[index] or 0) then -- bigger than the min version stop checking min_version
            min_table = nil
        end
        
        -- check if is more than the max_version
        if max_table and check_v > (max_table[index] or 0) then
            return false, 'max'
        elseif max_table and check_v < (max_table[index] or 0) then -- less than the max version stop checking max_version
            max_table = nil
        end    
    end

    return true, nil
end

---Returns if range 1 is in the range 2
---@param range1_start any
---@param range1_end any
---@param range2_start any
---@param range2_end any
---@param only_start_in_range boolean only if tange 1 start inside range 2 (includding the start point)
---@param only_end_in_range boolean only if tange 1 end inside range 2 (includding the end point)
---@return boolean bol checks if is in range using only_start and only_end arguments
---@return boolean is_before all range1 happens before range2 (includding if range1 end point == range2 start point)
---@return boolean is_after all range1 happens after range2 (includding if range1 start point == range2 end point)
function IsRangeInRange(range1_start,range1_end,range2_start,range2_end,only_start_in_range,only_end_in_range)
    local bol = false

    if range1_start >= range2_end then -- start after range (after this only items that start before range2 end point )
        return false, false, true
    end 
    
    if only_start_in_range and range1_start < range2_start then -- filter if only_start_in_range 
        local is_before = range1_end <= range2_start
        return false, is_before, false
    end    
    
    if only_end_in_range and range1_end > range2_end then -- filter if only_end_in_range
        local is_after = range1_start >= range2_end
        return false, false, is_after
    end 
    
    local is_in_range = range1_end > range2_start 
    return is_in_range, not is_in_range, false
end

---------------------
----------------- Numbers Bit operations
---------------------

---Get if the n bit(from right to left) of a number is 1. n is 0 based.
---@param number number
---@param n number bit from right to left, 0 based.
---@return boolean
function GetNbit(number,n)
    return ((number & (2^n)) >> (n)) == 1
end

---Change a bit value from a number.
---@param num number
---@param n number bit number, from right to left, 0 based 
---@param new_val number 0 or 1
---@return number new value
function ChangeBit(num, n, new_val)
    if type(new_val) == "boolean" then
        new_val = (new_val and 1) or 0
    end
    local mask = 1 << n
    if new_val == 0 then
        num = num & ~mask -- and operation with the opposite of the mask. (if an bite was 1 it will still be 1 unless its where the mask have an 0)
    else
        num = num | mask
    end
    return num
end

---------------------
----------------- Files
---------------------


---Returns file path, without file name
---@param file_path string
---@return string
function GetFilePath(file_path)
    return file_path:match('(.+)[\\?/?]')
end

---Return File name without extension
---@param file_path string
---@return string
function GetFileName(file_path)
    return file_path:match('.*[\\?/?](.+)%..+$')    
end

---Gets File path and return the extension, like "wav" or "avi". Without the dot!
---@param file_path string
---@return string
function GetFileExtension(file_path)
    return file_path:match('%.(.+)$')
end
