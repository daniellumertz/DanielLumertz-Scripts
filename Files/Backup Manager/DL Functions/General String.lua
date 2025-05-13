--@noindex
--version: 0.0

DL = DL or {}
DL.str = {}

---Return `str` but scape special characters    
---@param str string 
---@return string
---@return number count count of modified characters
function DL.str.literalize(str)
    return str:gsub(
        "[%(%)%.%%%+%-%*%?%[%]%^%$]",
        function(c)
        return "%" .. c
        end
    )
end

---Count each character as one. using #str or str:len will count 'ç', 'ã' as two characters
---@param str any
---@return number
function DL.str.CountCharacters(str)
    -- Count UTF-8 characters
    local count = 0
    for _ in string.gmatch(str, ".") do
        count = count + 1
    end
    return count
end