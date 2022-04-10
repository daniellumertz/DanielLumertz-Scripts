-- @noindex
function print(...)
    local iterate_char = '\n'
    for k,v in ipairs({...}) do

        if k == 1 and type(v) == 'string' then 
            if string.sub(v, 1,6) == '###ITC' then
                iterate_char = string.sub(v, 7)
                goto continue
            end 
        end

        reaper.ShowConsoleMsg(tostring(v)..iterate_char)
        ::continue::
    end
    reaper.ShowConsoleMsg("\n")
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

function log(str) reaper.ShowConsoleMsg('\n' .. tostring(str)) end



function TableValuesCompareNoOrder(table1,table2)
    if #table1 ~= #table2 then return false end
    local equal = false
    for key, item in pairs(table1) do
        for key2, item2 in pairs(table2) do
            if item == item2 then equal = true end
        end 
        if equal == false then return false end
    end
    local equal = false
    for key, item in pairs(table2) do
        for key2, item2 in pairs(table1) do
            if item == item2 then equal = true end
        end 
        if equal == false then return false end
    end

    return equal
end

function TablesHaveElementInCommon(table1,table2)
    for key, item in pairs(table1) do
        for key2, item2 in pairs(table2) do
            if item == item2 then 
                return true
            end
        end 
    end

    return false
end

-- JS API get char. Does not distinguish between upper/lwr 
-- hence +32
function get_char()
	local char = reaper.JS_VKeys_GetState(-1)
	for i = 1, 255 do
        if i == 17 or i == 16 or i == 18 or i == 91 or i == 92 then -- rule out all mod keys
            goto continue
        end
		if char:byte(i) ~= 0 then
			return i --+ 32
		end
        ::continue::
	end

	return nil
end

function get_char_group()
	local char = reaper.JS_VKeys_GetState(-1)
    local key_table = {}
	for i = 1, 255 do
		if char:byte(i) ~= 0 then
            table.insert(key_table,i)
			--return i --+ 32
		end
	end

	return key_table
end

function char_tostring(char)
	char = string.char(char):lower()
	-- BUG: This removes the 0, 1, or 2 from the keycode 
	-- I anticipate needign to change this to use GetMouseMods
	-- Or at the very least, sub %d for ''  ONLY if it's paired with 
	-- a char
	char = char:gsub('%d', '')
	return char
end


function reaperDoFile(file)
    local info = debug.getinfo(1,'S')
    ScriptPath = info.source:match[[^@?(.*[\/])[^\/]-$]]
    dofile(ScriptPath .. file)
end


-- convert pesky config file strings to bools and numbers
function convert_var(val)
	if val == 'true' then val = true 
	elseif val == 'false' then val = false 
	elseif val:match('%d+') then val = tonumber(val) 
	end
	return val
end


function is_in_str(a, b) return b:find(a) end

function is_in_start_str(a, b) -- is a the start of b string
    return b:match('^'..literalize(a))
end

function literalize(str)
    return str:gsub(
      "[%(%)%.%%%+%-%*%?%[%]%^%$]",
      function(c)
        return "%" .. c
      end
    )
end

function remove(ind, list) table.remove(list, ind) end

function GetKeycode(char)
    local char = string.upper(char)
    local Keycode = KeyCodeList()
    return Keycode[char]
end

function GetKeyName(code)
    local Keycode = KeyCodeList()
    for key, value in pairs(Keycode) do
        if code == value then return key end
    end
    return false
end

function KeyCodeList() -- https://cherrytree.at/misc/vk.htm , http://www.kbdedit.com/manual/low_level_vk_list.html , https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
    local Keycode = {}
    -- Mouse
    Keycode['LBUTTON']   =	1	
    Keycode['RBUTTON']   =	2	
    Keycode['CANCEL']    =	3	
    Keycode['MBUTTON']   =	4
    Keycode['XBUTTON1']  =	5
    Keycode['XBUTTON2']  =	6
    -- Things
    Keycode['BACK']	    =   8	--BACKSPACE key
    Keycode['TAB']	    =   9	--TAB key
    Keycode['CLEAR']	    =   12	--CLEAR key
    Keycode['RETURN']    =   13
    Keycode['CAPITAL']   =   20 -- Capslock
    Keycode['ESC']    =   27 -- ESC

    Keycode['SPACE']	    = 32	--SPACEBAR
    Keycode['PRIOR']	    = 33	--PAGE UP key
    Keycode['NEXT']	    = 34	--PAGE DOWN key
    Keycode['END']	    = 35	--END key
    Keycode['HOME']	    = 36	--HOME key
    Keycode['LEFT']	    = 37	--LEFT ARROW key
    Keycode['UP']	    = 38	--UP ARROW key
    Keycode['RIGHT']	    = 39	--RIGHT ARROW key
    Keycode['DOWN']	    = 40	--DOWN ARROW key
    Keycode['SELECT']    = 41	--SELECT key
    Keycode['PRINT']	    = 42	--PRINT key
    Keycode['EXECUTE']	= 43	--EXECUTE key
    Keycode['SNAPSHOT']	= 44	--PRINT SCREEN key
    Keycode['INSERT']	= 45	--INS key
    Keycode['DELETE']	= 46	--DEL key
    Keycode['HELP']	    = 47    --Help Key
    -- ModKeys
    Keycode['CTRL']         =   17  -- SHIFT
    Keycode['SHIFT']        =   16 -- CONTROL
    Keycode['ALT']          =   18 -- MENU
    
    Keycode['LWIN']      =	91 -- Left Windows key (Microsoft® Natural® keyboard)
    Keycode['RWIN']      =	92 -- Right Windows key (Natural keyboard)
    
	
    --Numbers
    Keycode['0'] = 48
    Keycode['1'] = 49
    Keycode['2'] = 50
    Keycode['3'] = 51
    Keycode['4'] = 52
    Keycode['5'] = 53
    Keycode['6'] = 54
    Keycode['7'] = 55
    Keycode['8'] = 56
    Keycode['9'] = 57
    --Letters
    Keycode['A'] = 65
    Keycode['B'] = 66
    Keycode['C'] = 67
    Keycode['D'] = 68
    Keycode['E'] = 69
    Keycode['F'] = 70
    Keycode['G'] = 71
    Keycode['H'] = 72
    Keycode['I'] = 73
    Keycode['J'] = 74
    Keycode['K'] = 75
    Keycode['L'] = 76
    Keycode['M'] = 77
    Keycode['N'] = 78
    Keycode['O'] = 79
    Keycode['P'] = 80
    Keycode['Q'] = 81
    Keycode['R'] = 82
    Keycode['S'] = 83
    Keycode['T'] = 84
    Keycode['U'] = 85
    Keycode['V'] = 86
    Keycode['W'] = 87
    Keycode['X'] = 88
    Keycode['Y'] = 89
    Keycode['Z'] = 90
    --Numlock
    Keycode['N0'] =	96
    Keycode['N1'] =	97
    Keycode['N2'] =	98
    Keycode['N3'] =	99
    Keycode['N4'] =	100
    Keycode['N5'] =	101
    Keycode['N6'] =	102
    Keycode['N7'] =	103
    Keycode['N8'] =	104
    Keycode['N9'] =	105

    Keycode['N*']	=   106 --	Multiply key
    Keycode['N+']	    =   107 --	Add key
    Keycode['SEPARATOR']	=   108 --	Separator key
    Keycode['N-']	=   109 --	Subtract key
    Keycode['N,']	=   110 --	Decimal key
    Keycode['N.']	=   194 --	Comma key
    Keycode['N/']	=   111 --	Divide key
    --- F
    Keycode['F1']    =	112 --	F1 key
    Keycode['F2']    =	113 --	F2 key
    Keycode['F3']    =	114 --	F3 key
    Keycode['F4']    =	115 --	F4 key
    Keycode['F5']    =	116 --	F5 key
    Keycode['F6']    =	117 --	F6 key
    Keycode['F7']    =	118 --	F7 key
    Keycode['F8']    =	119 --	F8 key
    Keycode['F9']    =	120 --	F9 key
    Keycode['F10']   =	121 --	F10 key
    Keycode['F11']   =	122 --	F11 key
    Keycode['F12']   =	123 --	F12 key
    Keycode['F13']   =	124 --	F13 key
    Keycode['F14']   =	125 --	F14 key
    Keycode['F15']   =	126 --	F15 key
    Keycode['F16']   =	127 --	F16 key
    -- Dots
    Keycode['Ç'] =  	186 --	Windows 2000: For the US standard keyboard, the ';:ç' key
    Keycode['+'] =   187 --	Windows 2000: For any country/region, the '+' key
    Keycode[','] =  188 --	Windows 2000: For any country/region, the ',' key
    Keycode['-'] =  189 --	Windows 2000: For any country/region, the '-' key
    Keycode['.'] = 190 --	Windows 2000: For any country/region, the '.' key
    Keycode['/'] =  	191 --	Windows 2000: For the US standard keyboard, the '/?' key
    Keycode['`'] =  	192 --	Windows 2000: For the US standard keyboard, the '`~' key
    Keycode['?'] =  	193 --	Windows 2000: For the US standard keyboard, the '`~' key

    Keycode['['] =  	219 --	Windows 2000: For the US standard keyboard, the '[{' key
    Keycode['\\'] =  	220 --	Windows 2000: For the US standard keyboard, the '\\|' key
    Keycode[']'] =  	221 --	Windows 2000: For the US standard keyboard, the ']}' key
    Keycode['\''] =  	222 --	Windows 2000: For the US standard keyboard, the 'single-quote/double-quote' key
    Keycode['OEM_8'] =  	223 --	???
    Keycode['OEM_102'] =    226 --	Windows 2000: Either the angle bracket key or the backslash key on the RT 102-key keyboard

    -- Others
--[[     Keycode['LSHIFT'] =	160 --	Left SHIFT key
    Keycode['RSHIFT'] =	161 --	Right SHIFT key
    Keycode['LCONTROL'] =	162 --	Left CONTROL key
    Keycode['RCONTROL'] =	163 --	Right CONTROL key
    Keycode['LMENU'] =	164 --	Left MENU key
    Keycode['RMENU'] =	165 --	Right MENU key
    Keycode['BROWSER_BACK'] =	166 --	Windows 2000: Browser Back key
    Keycode['BROWSER_FORWARD'] =	167 --	Windows 2000: Browser Forward key
    Keycode['BROWSER_REFRESH'] =	168 --	Windows 2000: Browser Refresh key
    Keycode['BROWSER_STOP'] =	169 --	Windows 2000: Browser Stop key
    Keycode['BROWSER_SEARCH'] =	170 --	Windows 2000: Browser Search key
    Keycode['BROWSER_FAVORITES'] =	171 --	Windows 2000: Browser Favorites key
    Keycode['BROWSER_HOME'] =	172 --	Windows 2000: Browser Start and Home key
    Keycode['VOLUME_MUTE'] =	173 --	Windows 2000: Volume Mute key
    Keycode['VOLUME_DOWN'] =	174 --	Windows 2000: Volume Down key
    Keycode['VOLUME_UP'] =	175 --	Windows 2000: Volume Up key
    Keycode['MEDIA_NEXT_TRACK'] =	176 --	Windows 2000: Next Track key
    Keycode['MEDIA_PREV_TRACK'] =	177 --	Windows 2000: Previous Track key
    Keycode['MEDIA_STOP'] =	178 --	Windows 2000: Stop Media key
    Keycode['MEDIA_PLAY_PAUSE'] =	179 --	Windows 2000: Play/Pause Media key
    Keycode['LAUNCH_MAIL'] =	180 --	Windows 2000: Start Mail key
    Keycode['LAUNCH_MEDIA_SELECT'] =	181 --	Windows 2000: Select Media key
    Keycode['LAUNCH_APP1'] =	182 --	Windows 2000: Start Application 1 key
    Keycode['LAUNCH_APP2'] =	183 --	Windows 2000: Start Application 2 key  ]]

    return Keycode    
end