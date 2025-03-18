-- @version 1.39
-- @author Daniel Lumertz
-- @provides
--    [main] Clear MIDI Transfer Settings at Current Project.lua
--    [nomain] Table to string.lua
--    [nomain] Core.lua
--    [nomain] General Functions.lua
--    [nomain] GUI.lua
--    [nomain] main.lua
--    [nomain] midi_lua.lua
--    [nomain] Reaper Functions.lua
--    [nomain] map_func.lua
--    [nomain] Modules/*.lua
--    [nomain] Classes/*.lua
-- @changelog
--    + fix a bug in MIDI Track mode
--    + manage to check if user cancelled the importing
--    + add some check in case item is deleted
--local VSDEBUG = dofile("c:/Users/DSL/.vscode/extensions/antoinebalaine.reascript-docs-0.1.12/debugger/LoadDebug.lua")
script_version = "1.39"
------------------------------
info = debug.getinfo(1,'S')
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]] -- this script folder
------------------------------
dofile(script_path .. 'Reaper Functions.lua') -- Functions to check versions
if not CheckJS() or not CheckSWS() or not CheckREAPERVersion('6.71') then return end -- Check Extensions

dofile(script_path .. 'General Functions.lua') -- General Functions needed
dofile(script_path .. 'Table to string.lua') -- General Functions needed
dofile(script_path .. 'map_func.lua') --Functions to Set MAP options + Default Options for new maps 
dofile(script_path .. 'main.lua') -- Functions to updates MIDI Items
---Init configs
retval, save = reaper.GetProjExtState(0, 'MTr', 'Map')
if save ~= '' then 
    save = table.load(save)
    map = SaveMapToMap(save)
    retval, page = reaper.GetProjExtState(0, 'MTr', 'Page')
else
    map = {} -- This is the map that maps The source item to the dest tracks also saves configs.
    map[1] = CreateMap() --Creates the first source tab on the init of the GUI there will be things inserted here
end
-------
dofile(script_path .. 'Core.lua') --Lokasenna GUI s2
dofile(script_path .. 'GUI.lua') -- The GUI it self =x


package.path = package.path .. ";" .. script_path ..'/?.lua'    -- Add current folder for getting modules
midi = require "midi_lua"


