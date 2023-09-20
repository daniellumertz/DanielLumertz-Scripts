--@noindex
--dofile("C:/Users/DSL/AppData/Roaming/REAPER/Scripts/Meus/Debug VS/DL Debug.lua")
------ Load Functions

-- get script path
ScriptPath = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]

dofile(ScriptPath .. 'Functions/Arrange Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/General Lua Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/REAPER Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/UI_Automation Items.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Imgui General Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Theme.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Generative Loops Functions.lua') -- Functions for using the markov in reaper


dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8.6') -- Made with Imgui 0.8 add schims for future versions.


local proj = 0

ScriptName = 'Generative Loops Automation Items'
Version = '0.0.1'
--ExtStatePatterns() 
options = {
    randomize = false,
    playrate_min = 1,
    playrate_max = 1,
    playrate_quantize = 0,
    regions_textinput = '',
    dest_track = {},
    source_track = nil
    }

GuiInitAI(ScriptName)
main_loop_ai()