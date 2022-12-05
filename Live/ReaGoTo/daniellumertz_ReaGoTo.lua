-- @version 0.0.1b
-- @author Daniel Lumertz
-- @provides
--    [nomain] Functions/*.lua
-- @changelog
--    + Release
-- @license MIT
print('hello world')


-----TODO:
-- 0) Fake data to test Project structure and user setting
-- 1) make the main loop to check
-- 2) Gui and hook parameters up
-- 4) Save settings
-- 5) MIDI Trigger
-- 6) Goto Overide markers


--dofile("C:/Users/DSL/AppData/Roaming/REAPER/Scripts/Meus/Debug VS/DL Debug.lua")
--demo = dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/ReaImGui_Demo.lua')

-- get script path
ScriptPath = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
-- dofile all files inside functions folder
dofile(ScriptPath .. 'Functions/Arrange Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/General Lua Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/REAPER Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Randomizer Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/GUI Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Imgui General Functions.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Main Loop.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Theme.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Json Main.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Settings.lua') -- Functions for using the markov in reaper
dofile(ScriptPath .. 'Functions/Serialize Functions.lua') -- Functions for using the markov in reaper

if not CheckReaImGUI('0.8') or not CheckJS() or not CheckSWS() or not CheckREAPERVersion('6.0') then return end -- Check Extensions
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8') -- Made with Imgui 0.8 add schims for future versions.


----- Script Names
ScriptName = 'ReaGoTo'
Version = '0.0.1'

--[[ -- Load Settings
SettingsFileName = 'ReaGoTo Settings'

-- Project configs (Loaded in the main loop at CheckProjects()) Need to start with an blank table
ProjConfigs = {}
ExtKey = 'project_config' -- ext state key
ProjPaths = {} -- Table with the paths for each project tab. ProjPaths[proj] = path
 ]]

-- Test Configs making script
FocusedProj = reaper.EnumProjects(-1)
ProjConfigs = {
    [FocusedProj] = {
        playlists = {
            [1] = {
                [1] = {
                    guid = '{28680144-38F8-4365-995D-6585F5D4AF2F}',
                    loop = true,
                    type = 'region' -- need?
                },

                [2] = {
                    guid = '{C4230ED0-80D3-4FD8-8F44-B88ACC20D5F1}',
                    loop = true,
                    type = 'region' -- need?
                }
            }
        },
        identifier = '#goto',
        oldtime = reaper.time_precise(),
        is_play = reaper.GetPlayStateEx(FocusedProj)&1 == 1,
        oldpos = (reaper.GetPlayStateEx(FocusedProj)&1 == 1 and reaper.GetPlayPositionEx( FocusedProj )) or reaper.GetCursorPositionEx(FocusedProj), -- switch for is_play
        is_triggered = false,
        stop_trigger = true, -- if pause or stop it will cancel triggers
        is_region_end_trigger = false,
        moveview = false
    } 
}
UserConfigs = {
    only_focus_project = false,
    compensate = 2,
    add_markers = true
}

-- Gui Style
Gui_W_init = 275 -- Init 
Gui_H_init = 450 -- Init 
FLTMIN, FLTMAX = reaper.ImGui_NumericLimits_Float() --set the padding to the right side


-- Start


