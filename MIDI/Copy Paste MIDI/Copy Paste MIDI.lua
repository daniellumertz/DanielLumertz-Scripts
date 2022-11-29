-- @version 0.4.4
-- @author Daniel Lumertz
-- @provides
--    [main=midi_editor] .
--    [nomain] Functions/*.lua
-- @changelog
--    + Update Checkers

--dofile("C:/Users/DSL/AppData/Roaming/REAPER/Scripts/Meus/Debug VS/DL Debug.lua")
demo = dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/ReaImGui_Demo.lua')

local info = debug.getinfo(1,'S')
local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]] -- this script folder

--- Global
ScriptName = 'Copy Paste MIDI'
Version = '0.4.4'
CopyList = {}

--- Settings Change in the UI after 
Gap = 60 -- 64th note How much time in ppq to consider events one thing. Not cumulative
IsGap = true

-- Interpolation between 0 - 1 
RhythmInter = 1
LenghtInter = 1
VelocityInter = 1 
PitchInter = 1 
IntervalInter = 1 
GrooveInter = 1 

IsAutoPaste = false --Auto Paste when changing Inter value 
-- When pasting Pitch and intervals create notes that were not in chord? 
PitchFill = true
InterFill = true

RhythmMeasurePos = false
--- UI
Pin = true
-- Meme
StevieTable = {}

----
dofile(script_path..'Functions/General Lua Functions.lua')
dofile(script_path..'Functions/MIDI Functions.lua')
dofile(script_path..'Functions/Arrange Functions.lua')
dofile(script_path..'Functions/Copy Paste Functions.lua')
dofile(script_path..'Functions/GUI Functions.lua')
dofile(script_path ..'Functions/REAPER Functions.lua') -- preset to work with Tables


if not CheckSWS() or not CheckReaImGUI() or not CheckJS() then return end
-- Imgui shims to 0.7.2 (added after the news at 0.8)
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.7.2')

GuiInit()
loop()

--

--[[ local midi_editor = reaper.MIDIEditor_GetActive()
local start = reaper.time_precise()

for take in enumMIDITakes(midi_editor, true) do
    local list = Copy(take)
end

print(reaper.time_precise() - start) ]]