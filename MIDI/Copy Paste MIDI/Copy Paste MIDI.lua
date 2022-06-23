-- @version 0.2.1
-- @author Daniel Lumertz
-- @provides
--    [nomain] Functions/*.lua
-- @changelog
--    + First Release

--dofile("C:/Users/DSL/AppData/Roaming/REAPER/Scripts/Meus/Debug VS/DL Debug.lua")
demo = dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/ReaImGui_Demo.lua')

local info = debug.getinfo(1,'S')
local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]] -- this script folder

--- Global
ScriptName = 'Copy Paste MIDI'
Version = '0.2.1'
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
MeasureInter = 1 
-- When pasting Pitch and intervals create notes that were not in chord? 
PitchFill = true
InterFill = true
-- Meme
StevieTable = {}

----
dofile(script_path..'Functions/General Lua Functions.lua')
dofile(script_path..'Functions/MIDI Functions.lua')
dofile(script_path..'Functions/Arrange Functions.lua')
dofile(script_path..'Functions/Copy Paste Functions.lua')
dofile(script_path..'Functions/GUI Functions.lua')






GuiInit()
loop()

--

--[[ local midi_editor = reaper.MIDIEditor_GetActive()
local start = reaper.time_precise()

for take in enumMIDITakes(midi_editor, true) do
    local list = Copy(take)
end

print(reaper.time_precise() - start) ]]