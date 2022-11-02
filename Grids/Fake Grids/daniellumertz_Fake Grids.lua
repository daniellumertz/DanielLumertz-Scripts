-- @version 1.0.1
-- @author Daniel Lumertz
-- @provides
--    [nomain] Functions/*.lua
--    [nomain] Fonts/*.ttf
-- @changelog
--    + change from open in midi editor to selected in arrange get button behavior
--    + fix internal MIDI function
--    + add tooltips


-- get script path
ScriptPath = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
-- dofile all files inside functions folder
dofile(ScriptPath .. 'Functions/Fake Grids Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Arrange Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/MIDI Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/General Lua Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/General Music Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Loop.lua') -- Functions with the main loop for maintaining the GUI
dofile(ScriptPath .. 'Functions/Imgui Functions.lua') -- Functions with the main loop for maintaining the GUI

--dofile("C:/Users/DSL/AppData/Roaming/REAPER/Scripts/Meus/Debug VS/DL Debug.lua")
--demo = dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/ReaImGui_Demo.lua')


-- Global Variables GUI
ScriptName = 'Fake Grids'
Version = '1.0.1' -- version of the script

Settings = {Tips = true} -- GUI Settings for the script
-- Global Variables Logic
MarkersList = {}

IsSelected = false
FilterMuted = false
IsSharp = false
Sub = {
  name = 's',
  color = 0x808080,
  divisions = 4
}

Identfier = '#'
Identfier_sub = '$'


GuiInit()
loop()

