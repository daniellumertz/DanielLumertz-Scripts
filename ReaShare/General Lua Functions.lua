-- @noindex

---------------------
----------------- Print
---------------------

function print(...) 
    local t = {}
    for i, v in ipairs( { ... } ) do
      t[i] = tostring( v )
    end
    reaper.ShowConsoleMsg( table.concat( t, "\n" ) .. "\n" )
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

---------------------
----------------- Strings
---------------------

function literalize(str)
	return str:gsub(
		"[%(%)%.%%%+%-%*%?%[%]%^%$]",
		function(c)
			return "%" .. c
		end
	)
end

function SubString(big_string,sub) -- Iterator function that return matches of sub in big_string. More less like gmatch but allow soberpossed macheses like in "ababc" trying to get "ab." will retunr "aba","abc"
	local start_char = 1
	return function ()
		local match =string.match(big_string,sub,start_char) -- Check if there is a match after start_char
		if match then 
			local s, e =string.find(big_string,literalize(match),start_char)
			start_char = e

			return match
		end
		return nil -- break for loop        
	end
end

---------------------
----------------- Files
---------------------


---Read everything inside a file
---@param file any
---@return unknown
function readAll(file)
	local f = assert(io.open(file, "rb"))
	if not f then return end
	local content = f:read("*all")
	f:close()
	return content
end

function file_exists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
 end
