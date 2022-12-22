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

print(QuantizeUpwards(2.23, 0.5))