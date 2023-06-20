--@noindex
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


reaper.PreventUIRefresh(1)
local proj = 0
for i = 0, 1000 do
    reaper.Main_OnCommand(41383, 0) -- Edit: Copy items/tracks/envelope points (depending on focus) within time selection, if any (smart copy)
    reaper.Main_OnCommand(42398, 0) -- Item: Paste items/tracks
    if reaper.CountSelectedMediaItems(proj) > 1 then 
        print('Didnt unselect before pasting')
        reaper.PreventUIRefresh(-1)
        reaper.UpdateArrange()
        return 
    end
end
reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)

--[[ local track = reaper.GetTrack(proj, 0)
local env = reaper.GetTrackEnvelope(track, 0)
DeleteAutomationItem(env,1) ]]