-- @version 1.0.0
-- @author Daniel Lumertz
-- @provides
--    [nomain] Functions/*.lua
--    [nomain] Info/*.txt
-- @changelog
--    + Second Release at Reapack

-- TODO
-- Setup for reapack

-- Debugger
--dofile("C:/Users/DSL/AppData/Roaming/REAPER/Scripts/Meus/Debug VS/DL Debug.lua")
-- get script path\
ScriptPath = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
-- dofile all files inside functions folder
dofile(ScriptPath .. 'Functions/Apply Phasing.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Arrange Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/General Lua Functions.lua') -- 
dofile(ScriptPath .. 'Functions/Generative Loops Functions.lua') -- 
dofile(ScriptPath .. 'Functions/Imgui General Functions.lua') -- 
dofile(ScriptPath .. 'Functions/REAPER Functions.lua') -- 
dofile(ScriptPath .. 'Functions/Theme.lua') -- 
--dofile(ScriptPath .. 'Functions/UI_Automation Items.lua') -- 
dofile(ScriptPath .. 'Functions/UI.lua') -- 

dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8.6') -- Made with Imgui 0.8 add schims for future versions.


local proj = 0
local reaper = reaper

ScriptName = 'Its Gonna Phase'
Version = '1.0.0'

ExtStatePatterns() -- Ext state keys saved in the items
rnd_values = SetDefaults() -- Item Random settings showed at the GUI 
LoopOption = SetDefaultsLoopItem() -- ##Item Random settings showed at the GUI 
Settings = SetDefaultSettings() -- TODO save this in a json


GuiInit(ScriptName)
main_loop()
