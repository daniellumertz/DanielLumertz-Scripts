--@noindex
--version: 0.0

DL = DL or {}
DL.t = {}
---------------------
----------------- Tables
---------------------
--- Insert something at the end of the table and remove the smalest index
---@param tbl table
---@param val any
function DL.t.Sub(tbl, val) 
    table.remove(tbl,1)
    table.insert(tbl,#tbl+1,val)
end

---Check for indexes inside a table. ex: TableCheckValues(t, 1) checks if t[1]. TableCheckValues(t, 2,3,5) checks if t[2][3][5]. This function dont throw any erros. Like if you try to t[2][3][5] but t[2] or t[2][3] isnt a table, it will throw an  error.
---@param t table
---@param ... any numbers or strings indexes to check. 
---@return any return nil if it cant get the value. return the value if it can get to it
function DL.t.Check(t, ...) -- Made by CF
    for i = 1, select('#', ...) do -- Loop though all the arguments
        if type(t) ~= 'table' then return  end
        t = t[select(i, ...)] -- select(i, ...) will get the next value in the vararg list. (this function actually returns many values (from i to #...) but inside the [] of a table it will only get the first one )  array = array[select(i, ...)] will change array to be that new value
    end
    return t
end

---Insert a value in a table, can contain a inner table that didnt exist previouslly. like TableInsert(t, 1, 2, 3)
---@param t any
---@param ... any 
function DL.t.Insert(t, ...)
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

---Return true if at least one value is in common, use pairs
---@param table1 table
---@param table2 table
---@return boolean
function DL.t.ValuesCompareAtLeastOne(table1,table2) 
    for key, item in pairs(table1) do
        for key2, item2 in pairs(table2) do
            if item == item2 then return true end
        end 
    end
    return false
end

function DL.t.ValuesCompareCount(table1,table2) --Count values that are equal in both tables, wihtout order. Each repeated value is only considered once like {2,6,4,6} and {6,6,6} will result in 1
    local used_keys = {}
    local cnt = 0
    for key, item in pairs(table1) do
        for key2, item2 in pairs(table2) do
            if not used_keys[key2] and (item == item2 or tostring(item) == tostring(item2)) then
                used_keys[key2] = true
                cnt = cnt + 1
                break
            end
        end 
    end
    return cnt
end

---Check if `t`have `val`. Return boolean and it's index, if any. It uses ipairs by default, set `is_pairs` to true to use pairs.
---@param t table table iterate to check values
---@param val any value to be checked
---@param is_pairs boolean|? if true will use pairs. else will use ipairs
---@return boolean, any
function DL.t.HaveValue(t, val, is_pairs)
    local func = is_pairs and pairs or ipairs
    for index, value in func(t) do
        if value == val then
            return true, index
        end
    end
    return false, nil
end

---Check if tables have the same values, ignoring the keys.
---@param table1 table
---@param table2 table
---@return boolean
function DL.t.ValuesCompareNoOrder(table1,table2) 
    if #table1 ~= #table2 then return false end
    local used_keys = {}
    for key, item in pairs(table1) do
        local bol = false -- if one item isnt found then break
        for key2, item2 in pairs(table2) do
            if not used_keys[key2] and (item == item2 or tostring(item) == tostring(item2))then
                used_keys[key2] = true
                bol = true
                break
            end
        end 
        if not bol then return false end
    end
    if #used_keys == #table1 then return true else return false end
end

---Get the size of table using pairs.
---@param table table
---@return number
function DL.t.Len(table)
    local c = 0
    for k,v in pairs(table) do 
        c = c + 1 
    end
    return c
end

--- Adds all keys values from table1 to table2, usinge the same keys. If table2 already have the key, make its value a table (if not already) and insert the values inside it
---@param table1 table
---@param table2 table
---@return table table2 
function DL.t.CombineKeys(table1,table2)
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
                table2[key] = DL.t.Combine(value,table2[key])
            end
        else
            table2[key] = value
        end  
    end
    return table2
end

function DL.t.Combine(table1,table2)
    for key, value in pairs(table1) do
        table.insert(table2,value)
    end
    return table2
end

---Makes a copy of `t` using ipairs
---@param t table
---@return table new_t
function DL.t.iCopy(t)
    local t2 = {}
    for k,v in ipairs(t) do
        t2[k] = v
    end
    return t2
end

---Makes a copy of `t` using pairs
---@param t table
---@return table new_t
function DL.t.Copy(t)
    local t2 = {}
    for k,v in pairs(t) do
        t2[k] = v
    end
    return t2
end

---Makes a deep copy of `t`. 
---@param t table
---@return table new_t
function DL.t.DeepCopy(t)
    local t2 = {}
    for k,v in pairs(t) do
        if type(v) == "table" then
            t2[k] = DL.t.DeepCopy(v)
        else
            t2[k] = v
        end
    end
    return t2
end

---Check if `t` have anything.
---@param t table 
---@param is_ipairs boolean? default is false. use ipairs to check
---@param is_false boolean? default is true. if true will consider a table value == false a something and return true. If is_false = false then it wont consider false a something. 
---@return boolean
function DL.t.HaveAnything(t, is_ipairs, is_false)
    if is_false == nil then
        is_false = true
    end
    local func = is_ipairs and ipairs or pairs
    for k,v in func(t) do
        if is_false or v then 
            return true
        end
    end
    return false
end

---Get an value randomly, from the integers keys. 
---@param t any
---@return any
function DL.t.GetRandom(t)
    local n = #t
    local r = math.random(n)
    return t[r]
end

-- Remove repeated values in a table, uses ipairs.
function DL.t.RemoveDup(table)
    local new_table = {}
    for index, value in ipairs(table) do
        if not DL.t.HaveValue(new_table, value) then
            new_table[#new_table+1] = value
        end
    end
    return new_table
end

---Return a table with all keys from `t` as values. Uses pairs by default, set is_ipairs to true to use ipairs.
---@param t table
---@param is_ipairs boolean|? false by default
---@return table
function DL.t.GetKeys(t, is_ipairs)
    local new_table = {}
    local func = is_ipairs and ipairs or pairs
    for key, value in func(t) do
        new_table[#new_table+1] = key
    end
    return new_table
end

---Create a new table with the values keys randomized. Only randomize keys that are numbers. String keys keep the same value.
---@param t table
---@return table new_table
function DL.t.RandomNewTable(t)
    local new_t = {}
    local keys =  DL.t.GetKeys(t, true) -- number keys
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


---Create a new table moving the values in a table to make it ascendent without gaps ex: t = {1 = 'a', 5 = 'c' ,9 = 'e'} will return {1 = 'a', 2 = 'c', 3 = 'e'}
---@param t table
---@return table
function DL.t.RemoveSpaces(t)
    local new_table = {}
    local keys_table = DL.t.GetKeys(t)
    table.sort(keys_table)
    for index, key in ipairs(keys_table) do
        table.insert(new_table,t[key])
    end    
    return new_table
end


---Return the smaller and higher key from a table. Go throught gaps.
---@param t table
---@return number min, number max 
function DL.t.MinMaxKeys(t)
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

---Return a new table with all values as strings
---@param t table
function DL.t.KeysToString(t)
    local new_table = {}
    for key, value in pairs(t) do
        new_table[tostring(key)] = value
    end
    return new_table    
end
    

---Return a new table table with all possible keys converted to numbers
---@param t table table to be converted
---@return table
function DL.t.KeysToNumbers(t)
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
---@return number? closest_key key with the closest number
---@return number? closest_value
function DL.t.GetKeyWithClosestNumber(t,val)
    local closest_number = math.huge
    local closest_key = nil
    for key, value in pairs(t) do
        if type(value) == 'number' then
            local dif = math.abs(value - val)
            if dif < closest_number then
                closest_number = dif
                closest_key = key
            end
        end
    end
    return closest_key, closest_number
end

---Iterate function simillar as ipairs but on reverse
---@param t any
function DL.t.ipairs_reverse(t)
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
---@param w_srt string|? string to be used with the weight, by default is weight.
---@return any key
---@return any value
function DL.t.RandomValueWithWeight(t, w_srt)
    w_srt = w_srt or 'weight'
    local function get_weight(v)
        if type(v) == 'table' then
            return v[w_srt] or 1
        else 
            return 1
        end
    end

    local sum = 0
    for k,v in ipairs(t) do
        sum = sum + get_weight(v)
    end
    local random_number = DL.num.RandomFloat(0,sum,false)
    local sum_weights = 0
    for k, v in ipairs(t) do
        local w = get_weight(v)
        sum_weights = sum_weights + w
        if sum_weights > random_number then
            return k, v
        end
    end
end