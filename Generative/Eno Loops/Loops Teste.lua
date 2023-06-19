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

local proj = 0

local item = reaper.GetSelectedMediaItem(proj, 0)
reaper.GetSetMediaItemInfo_String( item, 'P_EXT:HIe', 'aweee:', true )
--[[ local track = reaper.GetTrack(proj, 0)
local env = reaper.GetTrackEnvelope(track, 0)
DeleteAutomationItem(env,1) ]]