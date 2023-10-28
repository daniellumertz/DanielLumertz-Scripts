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
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8.6') -- Made with Imgui 0.8 add schims for future versions.


local proj = 0

ScriptName = 'Generative Loops Item Options'
Version = '0.0.1'

ExtStatePatterns() 
rnd_values = SetDefaults()
LoopOption = SetDefaultsLoopItem()
GuiInit(ScriptName)
main_loop()
