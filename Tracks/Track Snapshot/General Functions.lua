-- @noindex
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

function TableLen(table)
    local c = 0
    for k,v in pairs(table) do 
        c = c + 1 
    end
    return c
end

function GetProjectPath()
    return reaper.GetProjectPath(0 , '' ):gsub("(.*)\\.*$","%1")  .. "\\"
end

function GetFullProjectPath() -- with projct Name. with .rpp at the end
    return reaper.GetProjectPath(0 , '' ):gsub("(.*)\\.*$","%1")  .. reaper.GetProjectName(0)
end

function IsMasterTrack(track)
    local master = reaper.GetMasterTrack(0)
    if master == track then
        return true
    else
        return false
    end   
end

function GetProjectName()
    local proj, str=reaper.EnumProjects(-1, '')
    local name = reaper.GetProjectName( proj )
    return name:gsub("(.*).rpp$","%1")
end

function SaveSelectedTracks()
    local list = {}
    local num = reaper.CountSelectedTracks2(0, true) -- Select master?
    if num > 0 then
        for i= 0, num-1 do
            list[i+1] =  reaper.GetSelectedTrack2(0, i, true)
        end
    end
    return list
end

function LoadSelectedTracks(list)
    reaper.Main_OnCommand(40297, 0)--Track: Unselect all tracks
    if #list ~= 0 then 
        for i = 1, #list do
            if  reaper.ValidatePtr2(0, list[i], 'MediaTrack*') then
                reaper.SetTrackSelected( list[i], true )
            end
        end 
    end
end

function CheckTrackList(list)
    for key, track in pairs(list) do
        if type(track) ~= 'userdata' or reaper.ValidatePtr2(0, track, 'MediaTrack*') == false then
            return false
        end
    end
    return true
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

function table_copy_regressive(thing)
    if type(thing) == 'table' then
        local new_table = {}
        for k , v in pairs(thing) do
            local new_v = table_copy_regressive(v)
            local new_k = table_copy_regressive(k)
            new_table[new_k] = new_v
        end
        return new_table
    else 
        return thing
    end
end

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

function GetTrackByGUID(GUID) -- 
    local master = reaper.GetMasterTrack(0)
    if  GUID == reaper.GetTrackGUID( master ) then return master end
    local  track =  reaper.BR_GetMediaTrackByGUID( 0, GUID ) -- Faster than iterating all tracks but dont get master
    return track
end

function UnselectAllAutomationItemsInProject()
    local cnt_tr = reaper.CountTracks(0)
    for it = 0, cnt_tr-1 do -- Loop by track
        local track = reaper.GetTrack(0, it)
        local cnt_env = reaper.CountTrackEnvelopes( track )
        for ie = 0, cnt_env-1 do  -- Loop by envelope
            local env = reaper.GetTrackEnvelope( track, ie )
            local cnt_ai = reaper.CountAutomationItems( env )
            for iai = 0, cnt_ai-1 do  -- Loop by AI
                reaper.GetSetAutomationItemInfo( env, iai, 'D_UISEL', 0, true )
            end
        end
    end
end

function RemoveAutomationItems(track) -- Remove all Automation Items in a track and preserve points
    UnselectAllAutomationItemsInProject()
    local cnt_env = reaper.CountTrackEnvelopes( track )
    for ie = 0, cnt_env-1 do 
        local env = reaper.GetTrackEnvelope( track, ie )
        local cnt_ai = reaper.CountAutomationItems( env )
        for iai = 0, cnt_ai-1 do 
            reaper.GetSetAutomationItemInfo( env, iai, 'D_UISEL', 1, true )
        end
    end
    reaper.Main_OnCommand(42088, 0) -- Envelope: Delete automation items, preserve points
end

function CreateHiddenTrack(name)
    -- Create Track
    local idx = reaper.CountTracks( proj )
    reaper.InsertTrackAtIndex( idx, true )
    local hidden_track = reaper.GetTrack(0, idx)
    local retval, chunk = reaper.GetTrackStateChunk(hidden_track, '', false)

    --Name It
    reaper.GetSetMediaTrackInfo_String( hidden_track, 'P_NAME' , name, true )

    -- Hide it
    chunk  = ChangeChunkVal2(chunk, 'SHOWINMIX', '0 0.6667 0.5 0 0.5 -1 -1 -1') -- Default Hidden
    reaper.SetTrackStateChunk(hidden_track, chunk, false)
    return hidden_track   
end

function CreateEnvelopeInTrack(track, envname)
    local retval, chunk = reaper.GetTrackStateChunk(track, '', false)

    local new_env = '<'..envname..'\nEGUID '..reaper.genGuid(gGUID)..'\nACT 1 -1\nVIS 1 1 1\nLANEHEIGHT 0 0\nARM 1\nDEFSHAPE 0 -1 -1\nPT 0 1 0\n>' -- Envelope Chunk Section created
    chunk = AddSectionToChunk(chunk, new_env)

    reaper.SetTrackStateChunk(track, chunk, false)
end

function StoreAIinHiddenTrack(track)
    local cnt_env = reaper.CountTrackEnvelopes( track )
    for ie = 0, cnt_env-1 do  
        local env = reaper.GetTrackEnvelope( track, ie )
        local cnt_ai = reaper.CountAutomationItems( env )
        for iai = 0, cnt_ai-1 do 
            local len = reaper.GetSetAutomationItemInfo( env, iai, 'D_LENGTH', 0, false )
            local pool_id = reaper.GetSetAutomationItemInfo( env, iai, 'D_POOL_ID', 0, false )

            local hidden_envelope = reaper.GetTrackEnvelope(Configs.HiddenTrack, 0)
            reaper.InsertAutomationItem( hidden_envelope, pool_id, 0, len )
        end
    end
    
end

function BeginUndo()
    reaper.Undo_BeginBlock2(0)
    reaper.PreventUIRefresh(1)
end

function EndUndo(str)
    reaper.UpdateArrange()
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock2(0, str, -1)
end

function open_url(url)
    local OS = reaper.GetOS()
    if OS == "OSX32" or OS == "OSX64" then
      os.execute('open "" "' .. url .. '"')
    else
      os.execute('start "" "' .. url .. '"')
    end
end

function match_n(string, pattern, n)
    local i = 0
    local last_value
    for match in string.gmatch(string, pattern) do
        if i == n then return match end
        last_value = match
        i = i + 1
    end
    return last_value or false
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

function PostKey(hwnd, vk_code)
    reaper.JS_WindowMessage_Post(hwnd, "WM_KEYDOWN", vk_code, 0,0,0)
    reaper.JS_WindowMessage_Post(hwnd, "WM_KEYUP", vk_code, 0,0,0)
end

function CompareVersions(actual_version,minimum_version) -- major minor patch
    local major, minor, patch = string.match(actual_version, "(%d+)%.(%d+)%.(%d+)")
    local major_min, minor_min, patch_min = string.match(minimum_version, "(%d+)%.(%d+)%.(%d+)")

    if major_min > major then
        return false
    elseif major_min < major then
        return true
    end

    if minor_min > minor then
        return false
    elseif minor_min < minor then
        return true
    end

    if patch_min > patch then
        return false
    elseif patch_min < patch then
        return true
    end

    return true -- version is equal 
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

--- GUI

