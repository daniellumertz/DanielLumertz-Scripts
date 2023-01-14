--@noindex
function GetNbit(number,n)
    return ((number & (2^n)) >> (n)) == 1
end

---Change a bit value from a number.
---@param num number
---@param n number bit number, from right to left, 0 based 
---@param new_val number 0 or 1
---@return number new value
function ChangeBit(num, n, new_val)
    local mask = 1 << n
    if new_val == 0 then
        num = num & ~mask -- and operation with the opposite of the mask. (if an bite was 1 it will still be 1 unless its where the mask have an 0)
    else
        num = num | mask
    end
    return num
end

print(ChangeBit(8, 0, 1))