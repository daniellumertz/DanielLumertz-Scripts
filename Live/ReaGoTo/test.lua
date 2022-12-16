--@noindex

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
---@param t table
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



p = {
    a = 50,
    b = 60,
    10,
    20,
    30,
    40,
    50
}

newp = RandomizeTable(p)
print(newp)