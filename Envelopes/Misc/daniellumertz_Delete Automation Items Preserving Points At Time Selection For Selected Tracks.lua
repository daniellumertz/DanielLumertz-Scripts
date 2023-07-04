-- @version 1.0
-- @author Daniel Lumertz
-- @changelog
--    + Initial Release

------ USER SETTINGS
local clean_before_apply = true -- clean all items previously created and then paste new ones
------ Load Functions
-- Function to dofile all files in a path
function dofile_all(path)
    local i = 0
    while true do 
        local file = reaper.EnumerateFiles( path, i )
        i = i + 1
        if not file  then break end 
        dofile(path..'/'..file)
    end
end

-- get script path
ScriptPath = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
-- dofile all files inside functions folder
dofile_all(ScriptPath..'/'..'Functions')

local proj = 0

reaper.Undo_BeginBlock2(proj)
reaper.PreventUIRefresh(1)
local start, fim = reaper.GetSet_LoopTimeRange2(proj, false, true, 0, 0, false)
UnselectAllAutomationItems()
for track in enumSelectedTracks2(proj,true) do
    for env in enumTrackEnvelopes(track) do
        SelectAutomationItemsInRange(proj,start,fim,false,false, true, env)
        reaper.Main_OnCommand(42088, 0) --Envelope: Delete automation items, preserve points
    end
end
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock2(proj, 'Delete Automation Items Preserving Points At Time Selection For Selected Tracks', -1)