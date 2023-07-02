-- @version 0.1
-- @author Daniel Lumertz
-- @provides
--    [nomain] Functions/*.lua
-- @changelog
--    + release
--dofile("C:/Users/DSL/AppData/Roaming/REAPER/Scripts/Meus/Debug VS/DL Debug.lua")

function dofile_all(path)
    local i = 0
    while true do 
        local file = reaper.EnumerateFiles( path, i )
        i = i + 1
        if not file  then break end 
        dofile(path..'/'..file)
    end
end

local info = debug.getinfo(1,'S')
local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]] -- this script folder

local folder_name = 'Functions'

dofile_all(script_path..'/'..folder_name)

-------------------------------
-------   SCRIPT     ----------
-------------------------------
if reaper.CountSelectedMediaItems(proj) == 0 then return end

local proj = 0

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

--dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")
local render = reaper.NamedCommandLookup( '_SWS_AWRENDERSTEREOSMART' )
local sel_items = CreateSelectedItemsTable(proj)
for k, item in ipairs(sel_items) do
    local track = reaper.GetMediaItem_Track(item)
    reaper.SetOnlyTrackSelected(track)
    -- mute other items in this track
    local item_table_mute = {}
    for item_track in enumTrackItems(track) do
        local mute = reaper.GetMediaItemInfo_Value(item_track, 'B_MUTE')
        item_table_mute[item_track] = mute
        if item_track ~= item then
            reaper.SetMediaItemInfo_Value(item_track, 'B_MUTE', 1)
        end
    end
    -- get info time
    local pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    local len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    local fim = pos + len
    local mute = reaper.GetMediaTrackInfo_Value(track, 'B_MUTE')
    -- record
    reaper.GetSet_LoopTimeRange2(proj, true, true, pos, fim, false)
    reaper.Main_OnCommand(render, 0) --_SWS_AWRENDERSTEREOSMART SWS/AW: Render tracks to stereo stem tracks, obeying time selection
    reaper.SetMediaTrackInfo_Value(track, 'B_MUTE', mute)
    reaper.ShowConsoleMsg('halo')

    for restore_item, mute_val in pairs(item_table_mute) do
        reaper.SetMediaItemInfo_Value(restore_item, 'B_MUTE', mute_val)
    end
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.UpdateTimeline()
reaper.Undo_EndBlock2(proj, 'Render Selected Items in New Tracks', -1)