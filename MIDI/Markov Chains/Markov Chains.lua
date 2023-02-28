-- @version 1.0.6
-- @author Daniel Lumertz
-- @provides
--    [main=midi_editor] .
--    [nomain] Functions/*.lua
-- @license MIT
-- @changelog
--    + small fix at substring function


local info = debug.getinfo(1, 'S');
ScriptPath = info.source:match[[^@?(.*[\/])[^\/]-$]]

--dofile("C:/Users/DSL/AppData/Roaming/REAPER/Scripts/Meus/Debug VS/DL Debug.lua")
--demo = dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/ReaImGui_Demo.lua')

dofile(ScriptPath .. 'Functions/General Functions.lua') -- General Functions needed
dofile(ScriptPath .. 'Functions/MIDI Functions.lua') -- General MIDI Functions needed
dofile(ScriptPath .. 'Functions/MIDI Apply Functions.lua') -- General MIDI Functions needed
dofile(ScriptPath .. 'Functions/Markov Functions.lua') -- General MIDI Functions needed
dofile(ScriptPath .. 'Functions/Reaper Markov Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/GUI Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Main Loop Function.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Arrange Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Settings Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Json Main.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/GUID Convert.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Music General Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Style.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Drop Enhance Resolution Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Generate New Sequences.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/ImGUI Widgets.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/REAPER Functions.lua') -- preset to work with Tables


if not CheckSWS() or not CheckReaImGUI() or not CheckJS() then return end
-- Imgui shims to 0.7.2 (added after the news at 0.8)
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.7.2')

--- GUI
Pin = true
ScriptName = 'Markov Chains'
Version = '1.0.6'

--- Settings
SettingsFileName = "User Settings"


Settings()

-- Create a Markov Table. The indexes need to have this exact names.
AllSources = {} -- Table that haves all other markov tables inside TODO RENAME TO AllSources
SourceTable = CreateSourceTable(AllSources)
SelectedSourceTable = SourceTable

GuiInit(ScriptName)
loop()