--@noindex
--dofile("C:/Users/DSL/AppData/Roaming/REAPER/Scripts/Meus/Debug VS/DL Debug.lua")
------ Load Functions

-- get script path
ScriptPath = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]

dofile(ScriptPath .. 'Functions/Arrange Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/General Lua Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/REAPER Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Imgui General Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Theme.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/GUI.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Phasing Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Settings.lua') -- Functions for using the markov in reaper


dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8.6') -- Made with Imgui 0.8 add schims for future versions.

local proj = select(1, reaper.EnumProjects( -1 ))

ScriptName = 'Its Gonna Phase'
Version = '0.0.1'

PhasingOptions = {} -- Its Gonna phase Options
ExtStatePatterns() -- Ext State Names
LoopItemOptions = SetDefaultsLoopItem() -- Loop Items settings
ItemsOptions = SetItemDefaults() -- Items Settings


GuiInitAI(ScriptName)
reaper.defer(main_loop_ai)