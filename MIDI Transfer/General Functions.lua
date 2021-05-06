-- @noindex
function Msg(val)
    reaper.ShowConsoleMsg(tostring(val).."\n")
end

function StringCommaTable(string)
    local t = {}
    for track_idx in string.gmatch(string, "[^,]+") do 
        t[#t+1] = track_idx
    end
    return t
end

function CountTable(a)
    local c = 0
    for k, v in pairs(a) do
        c = c + 1
    end
    return c
end 

function bool_to_number(value)
    return value and 1 or 0
end

function num_to_bool(value)
    if value == 1 then 
        value = true 
    elseif  value == 0 then 
        value = false 
    end
    return value
end

function numtobol()
    if a == 1 then a = true elseif a == 0 then a = false end
    return a
end

function toBits(num)
    -- returns a table of bits, least significant first.
    local t={} -- will contain the bits
    while num>0 do
        rest=math.fmod(num,2)
        t[#t+1]=math.floor(rest)
        num=(num-rest)/2
    end
    return t
end

function BitTabtoStr2(t, len) -- transform an BitTab in a String 
    local s = ""
    local i = 1;
    while i <= len do
      s = (tostring(t[i] or "0"))..s
      i = i + 1
    end
    return s
end

function TableConcat(t1,t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]  --corrected bug. if t1[#t1+i] is used, indices will be skipped
    end
    return t1
end

function GetHighKey(t)
    big = 0
    for key, val in pairs(t) do
        if type(key) == 'number' then
            big = math.max( big , key  )
        end
    end
    return big
end

function BitTabtoStr(t)
    s = tostring(t[1]) or '0'
    local big = GetHighKey(t)
    for i = 2, big do 
        if t[i] then
            s = tostring(t[i])..s
        else
            s = '0'..s
        end
    end
    return s
end

function DeleteItemsList(list)
    for k , item in pairs(list) do 
        local tr = reaper.GetMediaItem_Track( item )
        reaper.DeleteTrackMediaItem(tr, item)
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
            print(list[i])
            reaper.SetMediaItemSelected( list[i], true )
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

function TrimStartMIDI(item, amount, pos, is_pos)
    local len = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
    local start = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
    local take = reaper.GetMediaItemTake( item, 0 )
    local off = reaper.GetMediaItemTakeInfo_Value( take, 'D_STARTOFFS' )
    if is_pos == true then
        amount = pos - start
    end
    reaper.MIDI_SetItemExtents( item,  reaper.TimeMap2_timeToQN( 0,start + amount ),  reaper.TimeMap2_timeToQN( 0,len + start) )
end

function TrimStart(item, amount, pos, is_pos)
    local len = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
    local start = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
    local take = reaper.GetMediaItemTake( item, 0 )
    local off = reaper.GetMediaItemTakeInfo_Value( take, 'D_STARTOFFS' )
    if is_pos == true then
        amount = pos - start
    end
    reaper.SetMediaItemInfo_Value( item, 'D_POSITION' , start + amount )
    reaper.SetMediaItemTakeInfo_Value( take, 'D_STARTOFFS', off + amount )
    reaper.SetMediaItemInfo_Value( item, 'D_LENGTH' , (len-amount) )
end

function TrimEndMIDI(item, amount, pos, is_pos)
    local start = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
    local len = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
    if is_pos == true then
        local start = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
        amount = (len + start) - pos
    end
    reaper.MIDI_SetItemExtents( item,  reaper.TimeMap2_timeToQN( 0,start ),  reaper.TimeMap2_timeToQN( 0,start+len-amount) )
end

function TrimEnd(item, amount, pos, is_pos)
    local len = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
    if is_pos == true then
        local start = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
        amount = (len + start) - pos
    end
    reaper.SetMediaItemInfo_Value( item, 'D_LENGTH' , len-amount )
end

function bfut_ResetAllChunkGuids(item_chunk, key) -- (I changed a little but it is from here: https://github.com/bfut/ReaScripts/blob/main/Items%20Editing/bfut_Replace%20item%20under%20mouse%20cursor%20with%20selected%20item.lua
    item_chunk = item_chunk:gsub('%s('..key..')%s+.-[\r]-[%\n]', "\ntemp%1 "..reaper.genGuid("").."\n", 1)
    return item_chunk:gsub('temp'..key, key), true
end

function Match(string, pattern)
    if string.find(string,pattern..'$') then return true else return false end
end

function SubMagicChar(string)
    local string = string.gsub(string, '[%[%]%(%)%+%-%*%?%^%$%%]', '%%%1')
    return string
end

function NegativeList2(list)-- map[i] Invert ( Instead of MAP FONT CHANNEL TRACK it becomes MAP FONT TRACK CHANNEL, as map[font][track][CH])
    if not list.negative then list.negative = {} end
    for cha, v in pairs(list) do
        if type(cha) == 'number' then
            for k2, tracke in ipairs(list[cha]) do
                if not list.negative[tracke] then list.negative[tracke] = {} end
                table.insert(list.negative[tracke],cha)
            end
        end
    end
    return list.negative
end

function IsChannelOnTrack(negative_list, tr, ch) -- negative list = something like map[font].negative 
    bol = false 
    if not negative_list[tr] then return bol end
    for k,v in pairs(negative_list[tr]) do
        if v == ch then bol = true break end
    end
    return bol
end

function open_url(url)
    local OS = reaper.GetOS()
    if OS == "OSX32" or OS == "OSX64" then
      os.execute('open "" "' .. url .. '"')
    else
      os.execute('start "" "' .. url .. '"')
    end
  end