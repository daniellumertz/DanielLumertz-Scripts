-- @noindex
function print( ...) 
    local t = {}
    for i, v in ipairs( { ... } ) do
      t[i] = tostring( v )
    end
    reaper.ShowConsoleMsg( table.concat( t, "\n" ) .. "\n" )
end

function printtable(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
end

function GetProjectPath()
    return reaper.GetProjectPath(0 , '' ):gsub("(.*)\\.*$","%1")  .. "\\"
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

function BeginUndo()
    reaper.Undo_BeginBlock2(0)
    reaper.PreventUIRefresh(1)
end

function EndUndo(str)
    reaper.UpdateArrange()
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock2(0, str, -1)
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

--- GUI

