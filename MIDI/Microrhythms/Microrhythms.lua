-- @version 0.1.7
-- @author Daniel Lumertz
-- @provides
--    [main=midi_editor] .
--    [nomain] Functions/*.lua
-- @changelog
--    + Correct Checkers

--dofile("C:/Users/DSL/AppData/Roaming/REAPER/Scripts/Meus/Debug VS/DL Debug.lua")
--demo = dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/ReaImGui_Demo.lua')

local info = debug.getinfo(1,'S')
local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]] -- this script folder

dofile(script_path..'Functions/General Lua Functions.lua')
dofile(script_path..'Functions/MIDI Functions.lua')
dofile(script_path..'Functions/Arrange Functions.lua')
dofile(script_path..'Functions/Microrhythms Functions.lua')
dofile(script_path..'Functions/GUI Functions.lua')
dofile(script_path .. 'Functions/REAPER Functions.lua') -- preset to work with Tables


if not CheckSWS() or not CheckReaImGUI() or not CheckJS() then return end
-- Imgui shims to 0.7.2 (added after the news at 0.8)
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.7.2')


------- Global

-- ID
ScriptName = 'Microrhythms'
Version = '0.1.7'

-- UI
Pin = true
PreventPassKeys = {}

--- Settings
Gap = 60 -- 64th note How much time in ppq to consider events one thing. Not cumulative
IsGap = true

local UserInputRatio, UserInputLength
SliderInter = 1
RhythmTable = {}
local SteadyValue

GuiInit()
loop()