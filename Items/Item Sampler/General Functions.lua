-- @noindex
function TableLen(table)
    local c = 0
    for k,v in ipairs(table) do 
        c = c + 1 
    end
    return c
end

function TableLen2(table)
    local c = 0
    for k,v in pairs(table) do 
        c = c + 1 
    end
    return c
end

function NumberToNote(number, is_sharp)
    local note_names_sharp = {'C','C#','D','D#','E','F','F#','G','G#','A','A#','B'}
    return note_names_sharp[(number % 12)+1] 
end

function TrimEnd(item, amount, pos, is_pos)
    local start = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
    local len = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
    if is_pos == true then
        local start = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
        amount = (len + start) - pos
    end
    local take = reaper.GetMediaItemTake(item, 0)
    if reaper.TakeIsMIDI( take ) == true then
        reaper.MIDI_SetItemExtents( item,  reaper.TimeMap2_timeToQN( 0,start ),  reaper.TimeMap2_timeToQN( 0,start+len-amount) )
    else
        reaper.SetMediaItemInfo_Value( item, 'D_LENGTH' , len-amount )
    end
end

function TrimStart(item, amount, pos, is_pos)
    local len = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
    local start = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
    local take = reaper.GetMediaItemTake( item, 0 )
    local off = reaper.GetMediaItemTakeInfo_Value( take, 'D_STARTOFFS' )
    if is_pos == true then
        amount = pos - start
    end
    local take = reaper.GetMediaItemTake(item, 0)
    if reaper.TakeIsMIDI( take ) == true then
        reaper.MIDI_SetItemExtents( item,  reaper.TimeMap2_timeToQN( 0,start + amount ),  reaper.TimeMap2_timeToQN( 0,len + start) )
    else
        reaper.SetMediaItemInfo_Value( item, 'D_POSITION' , start + amount )
        reaper.SetMediaItemTakeInfo_Value( take, 'D_STARTOFFS', off + amount )
        reaper.SetMediaItemInfo_Value( item, 'D_LENGTH' , (len-amount) )
    end
end

function print( ...) 
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


function SaveSelectedItems()
    local list = {}
    local num = reaper.CountSelectedMediaItems(0)
    if num ~= 0 then
        for i= 0, num-1 do
            list[i+1] =  reaper.GetSelectedMediaItem( 0, i )
        end
    end
    reaper.Main_OnCommand(40289, 0)--Item: Unselect all items
    return list
end

function LoadSelectedItems(list)
    reaper.Main_OnCommand(40289, 0)--Item: Unselect all items
    if #list ~= 0 then 
        for i = 1, #list do 
            if reaper.ValidatePtr(list[i], 'MediaItem*') then
                reaper.SetMediaItemSelected( list[i], true )
            end
        end 
    end
end

function SaveSelectedTracks()
    local list = {}
    local num = reaper.CountSelectedTracks2(0, true)
    if num ~= 0 then
        for i= 0, num-1 do
            list[i+1] =  reaper.GetSelectedTrack2(0, i, true)
        end
    end
    reaper.Main_OnCommand(40297, 0)--Track: Unselect all tracks
    return list
end

function LoadSelectedTracks(list)
    reaper.Main_OnCommand(40297, 0)--Track: Unselect all tracks
    if #list ~= 0 then 
        for i = 1, #list do 
            reaper.SetTrackSelected( list[i], true )
        end 
    end
end

function SetTrackRazorEdit(track, areaStart, areaEnd, clearSelection)
    if clearSelection == nil then clearSelection = false end
    
    if clearSelection then
        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', '', false)
    
        --parse string, all this string stuff could probably be written better
        local str = {}
        for j in string.gmatch(area, "%S+") do
            table.insert(str, j)
        end
        
        --strip existing selections across the track
        local j = 1
        while j <= #str do
            local GUID = str[j+2]
            if GUID == '""' then 
                str[j] = ''
                str[j+1] = ''
                str[j+2] = ''
            end

            j = j + 3
        end

        --insert razor edit 
        local REstr = tostring(areaStart) .. ' ' .. tostring(areaEnd) .. ' ""'
        table.insert(str, REstr)

        local finalStr = ''
        for i = 1, #str do
            local space = i == 1 and '' or ' '
            finalStr = finalStr .. space .. str[i]
        end

        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', finalStr, true)
        return ret
    else         
        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', '', false)
        local str = area ~= nil and area .. ' ' or ''
        str = str .. tostring(areaStart) .. ' ' .. tostring(areaEnd) .. '  ""'
        
        local ret, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', str, true)
        return ret
    end
end

function CopyMediaItemToTrack( item, track, position ) -- Thanks Amagalma s2
    local _, chunk = reaper.GetItemStateChunk( item, "", false )
    chunk = chunk:gsub("{.-}", "") -- Reaper auto-generates all GUIDs
    local new_item = reaper.AddMediaItemToTrack( track )
    reaper.SetItemStateChunk( new_item, chunk, false )
    reaper.SetMediaItemInfo_Value( new_item, "D_POSITION" , position )
    return new_item
end



function TrimItem(pasted_item, item, idx_note, notecnt, item_take, endppqpos )
    if Settings.Is_trim_ItemEnd == true  or Settings.Is_trim_StartNextNote == true or Settings.Is_trim_EndNote == true then
        local pasted_start = reaper.GetMediaItemInfo_Value(pasted_item, "D_POSITION")
        local pasted_len = reaper.GetMediaItemInfo_Value(pasted_item, "D_LENGTH")
        local pasted_end = pasted_start + pasted_len

        local trim_values = {}
        
        if Settings.Is_trim_ItemEnd == true then 
            local midi_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local midi_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            local midi_end = midi_start + midi_len
            table.insert(trim_values, midi_end)
        end

        if Settings.Is_trim_StartNextNote == true and idx_note < notecnt-1 then -- Cant be the last note
            local _, _, _, startppqpos_next, _, _, _, _ = reaper.MIDI_GetNote( item_take, idx_note+1 )
            local quarter_next = reaper.MIDI_GetProjQNFromPPQPos( item_take, startppqpos_next )
            local time_next = reaper.TimeMap2_QNToTime( 0, quarter_next )
            table.insert(trim_values, time_next)
        end

        if Settings.Is_trim_EndNote == true then -- Cant be the last note
            local quarter_end = reaper.MIDI_GetProjQNFromPPQPos( item_take, endppqpos )
            local time_end = reaper.TimeMap2_QNToTime( 0, quarter_end )
            table.insert(trim_values, time_end)
        end

        table.sort(trim_values)
        local shortest_value = trim_values[1]

        if pasted_end > shortest_value then -- Always compare so it don't extend always reduce
            TrimEnd(pasted_item, 0, shortest_value, true)
        end

        --[[ if pasted_start < midi_start then -- Filter out note that start before the item or make this always happening
            TrimStart(pasted_item, 0, midi_start, true)
        end ]]
    end
end

function AddDBinLinear(valbefore, addval )
    local val_before_in_DB = 20 * math.log(valbefore,10) -- Linear to dB
    local dB_newval = val_before_in_DB + addval -- add to dB
    local new_linear = 10^(dB_newval/20) -- dB to Linear
    return new_linear
end

function scale(val,min1,max1,min2,max2)
    return (((max2 - min2)*(val - min1))/(max1 - min1))+min2
end

function NumberToNote(number, is_sharp, is_octave, center_c_octave) -- Number, boolean(optional), boolean(optional), number(optional)
    if center_c_octave == nil then
        center_c_octave = 4
    end
    if is_sharp == nil then
        is_sharp = true
    end
    if is_octave == nil then
        is_octave = true
    end

    local note_names_sharp = {'C','C#','D','D#','E','F','F#','G','G#','A','A#','B'}
    local note_names_flat = {'C','Db','D','Eb','E','F','Gb','G','Ab','A','Bb','B'}
    local note_names = is_sharp and note_names_sharp or note_names_flat
    local pitch_class = note_names[(number % 12)+1] 
    local octave_number = math.floor((number / 12) - (5-center_c_octave))

    return pitch_class..octave_number
end

function NoteToNumber(note,center_c_octave) -- Number, number(optional)
    if center_c_octave == nil then
        center_c_octave = 4
    end
    local note_names_sharp = {'C','C#','D','D#','E','F','F#','G','G#','A','A#','B'}
    local note_names_flat = {'C','Db','D','Eb','E','F','Gb','G','Ab','A','Bb','B'}
    
    local pitch_class_name = string.match(note, '[%a#]*')
    local octave_number = string.match(note, "[%-%d]+")
    octave_number = tonumber(octave_number) or 0
    octave_number = octave_number + (5-center_c_octave)

    local note_names
    if #pitch_class_name > 1 and string.sub(pitch_class_name, -1) == '#' then 
        note_names =  note_names_sharp
    else
        note_names =  note_names_flat
    end

    local pitch_class_number
    for k, v in pairs(note_names) do
        if v == pitch_class_name then
            pitch_class_number = k - 1 
            break 
        end
    end

    local number = pitch_class_number + (12 * octave_number)
    return number
end

function IsStringNote(string)
    local is = false
    local note_names_sharp = {'C','C#','D','D#','E','F','F#','G','G#','A','A#','B'}
    local note_names_flat = {'C','Db','D','Eb','E','F','Gb','G','Ab','A','Bb','B'}

    local pitch_class_name = string.match(string, '[%a#]*')
    for k, v in pairs(note_names_sharp) do
        if pitch_class_name == v then 
            is = true
            goto continue
        end
    end

    for k, v in pairs(note_names_flat) do
        if pitch_class_name == v then 
            is = true
            goto continue
        end
    end

    ::continue::
    return is
end

function GetProjectPath()
    return reaper.GetProjectPath(0 , '' ):gsub("(.*)\\.*$","%1")  .. "\\"
end

function GetFullProjectPath() -- with projct Name. with .rpp at the end
    return reaper.GetProjectPath(0 , '' ):gsub("(.*)\\.*$","%1")  .. reaper.GetProjectName(0)
end

function table_copy(obj, seen)
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do res[table_copy(k, s)] = table_copy(v, s) end
    return res
end

function MakeUpperCaseFirstLetter(in_string)
    local first = string.sub(in_string,1,1)
    first = first:upper()
    return first..string.sub(in_string,2)
end

  
function PostKey(hwnd, vk_code)
    reaper.JS_WindowMessage_Post(hwnd, "WM_KEYDOWN", vk_code, 0,0,0)
    reaper.JS_WindowMessage_Post(hwnd, "WM_KEYUP", vk_code, 0,0,0)
end


function CheckRequirements()
    local wind_name = ScriptName..' '..ScriptVersion
    if not reaper.APIExists('ImGui_GetVersion') then
        reaper.ShowMessageBox('Please Install ReaImGui at ReaPack', wind_name, 0)
        return false
    end    

    if not reaper.APIExists('JS_ReaScriptAPI_Version') then
        reaper.ShowMessageBox('Please Install js_ReaScriptAPI at ReaPack', wind_name, 0)
        return false
    end    

    if  not reaper.APIExists('CF_GetSWSVersion') then
        reaper.ShowMessageBox('Please Install SWS at www.sws-extension.org', wind_name, 0)
        return false
    end
    --[[  -- meh for comparing versions
    --local major, minor, patch = string.match(AppVersion, "(%d+)%.(%d+)%.(%d+)")
    local sws_version = reaper.CF_GetSWSVersion()
    local sws_min = '2.12.1'

    if not CompareVersions(sws_version,sws_min) then
        local bol = reaper.ShowMessageBox('Please Update SWS at www.sws-extension.org\nYou are running version: '..sws_version..'\nMin Version is: '..sws_min..'\nRun Anyway?', wind_name, 4)
        return bol == 6
    end

    local version =  reaper.GetAppVersion()
    print(version)
    local min = '6.50'

    if not CompareVersions(version,min) then
        local bol = reaper.ShowMessageBox('Please Update Reaper\nYou are running version: '..version..'\nMin Version is: '..min..'\nRun Anyway?', wind_name, 4)
        return bol == 6
    end ]]

    --print(reaper.ImGui_GetVersion())
    --print(reaper.JS_ReaScriptAPI_Version())
    --print(reaper.CF_GetSWSVersion())
    return true 
end
  
function GetKeycode(char)
    local char = string.upper(char)
    local Keycode = KeyCodeList()
    return Keycode[char]
end

function GetKeyName(code)
    local Keycode = KeyCodeList()
    for key, value in pairs(Keycode) do
        if code == value then return value end
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
    --Keycode['?'] =  	193 --	Windows 2000: For the US standard keyboard, the '`~' key

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


function PrintStevie()
    reaper.ClearConsole()
    local stevie =
    [[
    &&&&&&&&&%%%##((//*****,,,,,............   ...,,,,,,,,,,,,,,,,,..........     ..
    &&&&&%%%#((///****,,,,........              .....,,,,,,,,,,......    ......   ..
    &&&%##(//**,,,,,,,,,.......                  .........,,,,.......       ........
    &&%#(/*,,,,,,,,,..........                    ...................        ...,...
    &&%#/**,,,,,,,.............                        ..............         .,,,..
    &&%#/**,,,,,,,,............                           .......             .,,,,,
    &&%#(**,,,,,,,,............                                                .,,,,
    &&%#(/***,,,,,,............                                                ..,,,
    &&&%#(/**,,,,,,,........                                                   ...,,
    &&&&%(/**,,,,,,,.........                                ......,,,********,,,.,,
    @&&%#/**,,,,,,,,,,,,,,,,,,................................,,*//(#%%##(//*,,...,*
    @&%#/**,,,,**///((((///////((((((((((((//**,,,,.......,,**/(#####((/****,,.  .,*
    &&#/**,,,,**/((((((//////***////(((((##(((//**,,,...,,**//((##%%%%#/*///**,.  .,
    &%(/*,,,,***//********//((########(((///////**,,......,**//*//((((/,,...      .,
    &%(/*,,,,,**,,,,,**//((###%%%%#(***////**,,**,,,..   ..,,,,,,,,,,,,,...       .,
    %#(/*,,,,,,,,,,,,,*******,,,,,,,,,,***,,,.,,,,,,...    ..,,,....,,,,....       .
    %%(/*,,,,,,,,......,,,,,,,,,,,,,,,,,,,,...,,,,,,...      ..............         
    %%#/**,,,,,,..........,,,,,,,,,,,,..................       .......              
    (##(/**,,,,,..........................................      .........   ..      
    */((/***,,,,...................................,,.....      ..,,,..........     
    ,*////***,,,,,.............     .....,,,,,,,,,,,,....        ..,***,,,,.....    
    ,,*////**,,,,,,,,,................,,*****,,..,,,,....          .,*****,,,,...   
    ***/((/***,,,,,,,,,,,,,,,,....,,,*********,,,,,,,,,,.........,,,*****//***,,....
    **//((/****,,,,,,,,,,,,,,,,,,***///******///(((((((///***///////****///(//*,....
    ***/(#(/*****,,,,,,**********//((//***///(((##########(((((/////****//(((/*,.  .
    ***/(((//*****************//(((((////////((((((((((((/(((((//*****/////(/*,.....
    ***///((//***************//(####(((((///////////////*****//****////*///**,...*#&
    ****///(///****,,,,*****//(###((((###((/********,,,,,,......,,*//***/((*,.*#&@@@
    ***////(((//****,,,*****///(##(/****////*,,......        .,****,,,**/##((%&@@@@@
    ****////(((//*****,,**//////(##(/*,,*****/*******,,,*********,..,,**(##&&@@@@@@@
    *****////((((///***,**/((((#####(/*,,,,,*********************,,.,,*(#%&@@@@@@@@@
    ******////((##((//////(##%%%%&&&%#(/*,,,,,,**************,,,,,,,,*/(#&@@@@@@@@@@
    *******////((#%%%%%%%%%%%%%%%&&&&%%#((/***,,,******/////*********/(#%@@@@@@@@@@@
    *********////(#%%&&&&&&&%&&&&&@@@&&&%%##(/**,****/////////*****///(%&@@@@@@@@@@@
    *********/////(((#%&&&&&&&&&&&@@@@&&&&%%%#(//******************//((%&@@@@@@@@@@@
    *********///((#(//((#%&&&&&&&&&@@@&&&&&&%%#((////********//////((((%&@@@@@@@@&#%
    *********//(##/***///((#%%&&@@@@@@@@@&&&%%%####(((//(((/((((((((((#%&@@@@@@@@&(*
    ****///(##%%#/*******///((#%%&&&@@@@@&&&&&&&&%%%%##########%###(#%%#%@@@@@@@@@&(
    **/(#%&&@@@&#/,,********//(((##%%&&&&@@@@@&@@&&&&&%%%%%%%%%%%%%%%%#((%@@@@@@@@@&
    #%&&@@@@@@@&%(*,,,,,,******///(((###%&&&@@@@@@@@@&&&&&&&&&&&&&&%#/***(&&@@@@@@@@
    &@@@@@@@@@@@&%/,,,,,,,,,,,,***////((((##%%%&&&&&&&@&&&&&&&&%##(/**,,*(%&@@@@@@@@
    @@@@@@@@@@@@@&%(*,,,,,,,,,,,,******////(((###%%%%%%%%####(((//***,,,*(%&@@@@@@@@]]
    reaper.ShowConsoleMsg(stevie)
  end