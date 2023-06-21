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

reaper.Undo_BeginBlock()

reaper.PreventUIRefresh(1)
local proj = 0
local env = reaper.GetSelectedEnvelope(proj)
reaper.InsertAutomationItem(env, 1, 10, 2)
--[[ for i = 0, 1000 do
    reaper.Main_OnCommand(41383, 0) -- Edit: Copy items/tracks/envelope points (depending on focus) within time selection, if any (smart copy)
    --reaper.SelectAllMediaItems( proj, false ) -- After paste only the pasted items should be selected. This makes sure of it. For some reason there is a chance that just copy and paste wont just have the copied items.
    ------ Paste
    reaper.Main_OnCommand(42398, 0) -- Item: Paste items/tracks
    if reaper.CountSelectedMediaItems(proj) == 0 then
        print('didnt paste')
        break
    end
end ]]
reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock2(proj, 'test', -1)

--[[ local track = reaper.GetTrack(proj, 0)
local env = reaper.GetTrackEnvelope(track, 0)
DeleteAutomationItem(env,1) ]]