-- @version 1.37.2
-- @author Daniel Lumertz
-- @provides
--    [main] Clear MIDI Transfer Settings at Current Project.lua
--    [nomain] Table to string.lua
--    [nomain] Core.lua
--    [nomain] General Functions.lua
--    [nomain] GUI.lua
--    [nomain] main.lua
--    [nomain] Reaper Functions.lua
--    [nomain] map_func.lua
--    [nomain] Modules/*.lua
--    [nomain] Classes/*.lua
-- @changelog
--    + Prevent getting non midi items as source
--    + Check versions
--    + Add Clear function
--    + Enforce the Expand checkbox
--    + Enforce .font_PCM exists
--    + MIDI Track Option bugfix: Prevent copying channels if they arent in the midi file


script_version = "1.37.2"
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


package.path = package.path .. ";" .. script_path ..'\\?.lua'    -- Add current folder/socket module for looking at .so
midi = require "midi_lua"


