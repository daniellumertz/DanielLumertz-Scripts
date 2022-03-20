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
    print(chunk)
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

function GetKeycode(char)
    local Keycode = KeyCodeList()
    return Keycode[char]
end

function KeyCodeList()
    local Keycode = {}    
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

--- GUI

