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