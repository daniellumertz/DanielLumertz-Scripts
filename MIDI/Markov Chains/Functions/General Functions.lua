--@noindex
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
    local up_value = (num + (quantize_value/2))
    local low_quantize = ((up_value / quantize_value)//1)*quantize_value
    return low_quantize
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

---Generate a random number between min and max.
---@param min number minimum value
---@param max number maximum value
---@param is_include_max boolean if true it can result on the max value
---@return number
function RandomNumberFloat(min,max,is_include_max)
    local sub = (is_include_max and 0) or -1 --  -1 because it cant never be the max value. Lets say we want to choose random between a and b a have 2/3 chance and b 1/3. If the random value is from 0 - 2(not includded) it is a, if the value is from 2 - 3(not includded) it is b. 
    local big_val = 1000000 -- the bigger the number the bigger the resolution. Using 1M right now
    local random = math.random(0,big_val-sub) -- Generating a very big value to be Scaled to the sum of the chances, for enabling floats.
    random = MapRange(random,0,big_val,min,max) -- Scale the random value to the sum of the chances

    return random
end

--- Return dbval in linear value. 0 = -inf, 1 = 0dB, 2 = +6dB, etc...
function dBToLinear(dbval)
    return 10^(dbval/20) 
end

--- Return value in db. 0 = -inf, 1 = 0dB, 2 = +6dB, etc...
function LinearTodB(value)
    return 20 * math.log(value,10)    
end

