--@noindex
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

local t = {10,20,30,40,50}
for index, value in ipairs_reverse(t) do
    if index == 3 then
        table.remove(t,index)
    else
        print(index,value)
    end
end