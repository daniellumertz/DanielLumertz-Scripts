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

ScriptName = 'Generative Loops Item Options'
Version = '0.0.1'

ExtStatePatterns() 
rnd_values = SetDefaults()
LoopOption = SetDefaultsLoopItem()
GuiInit(ScriptName)
main_loop()