--@noindex
------ Load Functions
-- Function to dofile all files in a path
local os_separator = package.config:sub(1,1)
function dofile_all(path)
    local i = 0
    while true do 
        local file = reaper.EnumerateFiles( path, i )
        i = i + 1
        if not file  then break end 
        dofile(path..os_separator..file)
    end
end

-- get script path
ScriptPath = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
-- dofile all files inside functions folder
dofile_all(ScriptPath..os_separator..'Functions')


local proj = 0
local item = reaper.GetSelectedMediaItem(proj, 0)
local env = reaper.GetSelectedEnvelope(proj)
CropItem(item, 22,56)
--CropAutomationItem(env, 0, 50, 60)

reaper.UpdateArrange()

