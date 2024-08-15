--@noindex
--version: 0.1
-- Random Exp

DL = DL or {}
DL.num = {}

---------------------
----------------- Pure Numbers
---------------------

---Limit a number between min and max
---@param number number number to be limited
---@param min number? minimum number
---@param max number? maximum number
---@return number
function DL.num.Clamp(number,min,max)
    if min and number < min then return min end
    if max and number > max then return max end
    return number
end

---Remove the decimal part of a number
---@param number number number to be rounded
---@return number
function DL.num.Round(number)
    return math.floor(number + 0.5)
end

---Return a number to the closest quantize value, simillar to RoundNumber.
---@param num number number to be quantized
---@param quantize_value number quantize value
function DL.num.Quantize(num,quantize_value)
    if quantize_value == 0 then return num end
    local up_value = (num + (quantize_value/2))
    local low_quantize = ((up_value / quantize_value)//1)*quantize_value
    return low_quantize
end

---Quantize a number upwards
---@param number number value to be quantized
---@param step_size number setep size 
---@return number quantized_number
function DL.num.QuantizeUpwards(number, step_size)
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
function DL.num.Interpolate(val1,val2,inter)
	return (val1*inter)+(val2*(1-inter)) 
end

---Map/Scale Val between range 1 (min1 - max1) to range 2 (min2 - max2)
---@param value number Value to be mapped
---@param min1 number Range 1 min
---@param max1 number Range 1 max
---@param min2 number Range 2 min
---@param max2 number Range 2 max
---@return number
function DL.num.MapRange(value,min1,max1,min2,max2)
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
function DL.num.Slide(old_val,new_val,max_time_going_up, max_time_going_down,elapsed_time,min,max)
    local max_distance = max - min
    local is_going_up = new_val > old_val 
    local time  = (is_going_up and max_time_going_up) or max_time_going_down -- time it takes to go from 0to1 or 1to0, in seconds
    if time <= 0 then -- no slide
        return new_val
    else
        local speed = max_distance / time --speed of value/second
        speed = speed * elapsed_time
        speed = DL.num.Clamp(speed, min, max) -- just in case
        speed = is_going_up and speed or -speed
        local result = old_val + speed
        result = is_going_up and DL.num.Clamp(result, min, new_val) or DL.num.Clamp(result, new_val, max)
        return result
    end    
end

---Generate a random number between min and max.
---@param min number minimum value
---@param max number maximum value
---@param is_include_max boolean if true it can result on the max value
---@return number
function DL.num.RandomFloat(min,max,is_include_max)
    local max = is_include_max and (max - 10^-8) or max    
    return DL.num.MapRange(math.random(), 0, 1, min, max)
end

---Returns a random float number with exponential distribution. Usefull for generating frequencies and each octave has the same distribution.
---@param min number minimum number it can generate. Can't be <= 0.
---@param max number maximum number it can generate. Can't be <= 0.
---@param base number? base to use
---@return number
function DL.num.RandomFloatExp(min,max,base)
    if min <= 0 then
        error('DL.num.RandomFloatExp demmands that min > 0')
    elseif max <= 0 then
        error('DL.num.RandomFloatExp demmands that max > 0')
    end
    base = base or 2
    local min_exp = math.log(min,base)
    local max_exp = math.log(max,base)
    local r = min_exp + (math.random() * (max_exp-min_exp)) -- uniform random
    return base ^ r
end

---Generate a random number between min and max, quantize it.
---@param min number minimum value
---@param max number maximum value
---@param is_include_max boolean if true it can result on the max value
---@param quantize number quantize value
---@return number
function DL.num.RandomFloatQuantized(min,max,is_include_max,quantize)
    local num = DL.num.RandomFloat(min,max,is_include_max)
    return DL.num.Quantize(num, quantize)    
end

---Remove n `decimal_places` from the number
---@param num number
---@param decimal_places number
---@return number
function DL.num.RemoveDecimals(num,decimal_places)
    local int_num = math.floor(num * 10^decimal_places)
    return int_num / 10^decimal_places    
end

--- Return dbval in linear value. 0 = -inf, 1 = 0dB, 2 = +6dB, etc...
function DL.num.dBToLinear(dbval)
    return 10^(dbval/20) 
end

--- Return value in db. 0 = -inf, 1 = 0dB, 2 = +6dB, etc...
function DL.num.LinearTodB(value)
    return 20 * math.log(value,10)    
end

---Compare versions. Check and min versions must have the same amount of versions numbers. Like 0.7.2 and 0.7.0
---@param check_version string version to check 
---@param min_version string? min version
---@param max_version string? min version
---@param separator string? separatordefault is '.'
---@return boolean retval did it passed the filters? 
---@return string|nil why reason it didnt pass the filter. return 'min' or 'max'. if passed it will return nil
function DL.num.CompareVersion(check_version, min_version, max_version, separator)
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
function DL.num.IsRangeInRange(range1_start,range1_end,range2_start,range2_end,only_start_in_range,only_end_in_range)
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

---Return `num` formated as a string up to `spaces` decimal spaces
---@param num number number to be formated
---@param spaces number? number of decimal spaces. default 2
---@return string|?
function DL.num.FormatNumber(num, spaces, signal)
    if not num then return nil end 
    spaces = spaces or 2
    if num % 1 == 0 then
        return tostring(num) -- Return the integer as a string
    else
        return string.format("%"..(signal and '+.' or '.')..spaces.."f", num) -- Format the number with two decimal places
    end
end

---------------------
----------------- Bits
---------------------

DL.num.bit = {}


---transofrms num (a decimal number) as string.
---@param num number
---@param reverse boolean if false 2 = 01 if true 2 = 10. False = little endian (lsb comes first from left to right)
---@return string
function DL.num.bit.ToBitString(num,reverse)
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

---Get if the n bit(from right to left) of a number is 1. n is 0 based.
---@param number number
---@param n number bit from right to left, 0 based.
---@return boolean
function DL.num.bit.GetNbit(number,n)
    return ((number & (2^n)) >> (n)) == 1
end

---Change a bit value from a number.
---@param num number
---@param n number bit number, from right to left, 0 based 
---@param new_val number 0 or 1
---@return number new value
function DL.num.bit.ChangeBit(num, n, new_val)
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

---Can also use NF_Base64_Encode, which is faster!
---@param data string
---@return string
function DL.num.bit.EncoderBase64(data)
    local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
  end
  
---Can also use NF_Base64_Decode, which is faster!
---@param data string
---@return string
function DL.num.bit.DecoderBase64(data)
    local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
  end
  
