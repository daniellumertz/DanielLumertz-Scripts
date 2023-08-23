-- @version 1.1.1
-- @author Daniel Lumertz
-- @provides
--    [main=midi_editor] .
--    [nomain] Functions/*.lua
--    [nomain] Fonts/*.ttf
-- @license MIT
-- @changelog
--    + fix dofile typo. Thanks axel_ef! 


--dofile("C:/Users/DSL/AppData/Roaming/REAPER/Scripts/Meus/Debug VS/DL Debug.lua")
--demo = dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/ReaImGui_Demo.lua')
ScriptName = 'MIDI Toolkit'
Version = '1.1.1'

--- Load functions
local info = debug.getinfo(1, 'S');
local ScriptPath = info.source:match[[^@?(.*[\/])[^\/]-$]]

dofile(ScriptPath .. 'Functions/Arrange Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Copy Paste Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/General Lua Functions.lua') -- General Functions needed
dofile(ScriptPath .. 'Functions/General Music Functions.lua') -- General Functions needed
dofile(ScriptPath .. 'Functions/GUI Functions.lua') -- General Functions needed
dofile(ScriptPath .. 'Functions/ImGUI Custom Widgets.lua') -- General Functions needed
dofile(ScriptPath .. 'Functions/Imgui Functions.lua') -- General Functions needed
dofile(ScriptPath .. 'Functions/Main Loop.lua') -- General Functions needed
dofile(ScriptPath .. 'Functions/Mapper Functions.lua') -- General Functions needed
dofile(ScriptPath .. 'Functions/MIDI Apply Functions.lua') -- General MIDI Functions needed
dofile(ScriptPath .. 'Functions/MIDI Functions.lua') -- General MIDI Functions needed
dofile(ScriptPath .. 'Functions/Param Tables Functions.lua') -- General MIDI Functions needed
dofile(ScriptPath .. 'Functions/Permutate Functions.lua') -- General MIDI Functions needed
dofile(ScriptPath .. 'Functions/Style.lua') -- General MIDI Functions needed
dofile(ScriptPath .. 'Functions/REAPER Functions.lua') -- preset to work with Tables


if not CheckSWS() or not CheckReaImGUI() or not CheckJS() then return end
-- Imgui shims to 0.7.2 (added after the news at 0.8)
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.7.2')



-- Settings
GUISettings = {tips = true, pin = true, pitch_as_numbers = true, use_sharps = true, mapper_size = 150, mapper_min = 100}

IsGap = true
Gap = 1/16
GapString = '1/16'

-- Reorder Combo Values
ComboParam = {'Pitch','Interval','Rhythm','Measure Pos','Velocity'}
SelectedParam = ComboParam[1]
ReorderTable = {}
for index, param_name in ipairs(ComboParam) do
    ReorderTable[param_name] = {}
end
-- Mapper 
MapperComboParam = {'Pitch','Interval','Rhythm','Measure Pos','Velocity'}
MapperTable = {}
for index, param_name in ipairs(MapperComboParam) do
    MapperTable[param_name] = {}
end

MapperSelectedParam = MapperComboParam[1]

MapperSettings = {is_pitch_class = true, octave_size = 12, is_quantize = true, quantize_step = 1/4, quantize_text = '1/4'}

-- Copy Paste
CopySettings = {pitch_inter = 1, interval_inter = 1, rhythm_inter = 1, measure_pos_inter = 1, groove_inter = 1, vel_inter = 1, len_inter = 1}
PitchComplete = true
InterComplete = true

-- Run Main Loop
GuiInit(ScriptName,ScriptPath)
MainLoop()