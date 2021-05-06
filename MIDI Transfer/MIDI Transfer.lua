-- @version 1.3
-- @author Daniel Lumertz
-- @provides
--    [nomain] Table to string.lua
--    [nomain] Core.lua
--    [nomain] General Functions.lua
--    [nomain] GUI.lua
--    [nomain] main.lua
--    [nomain] map_func.lua
--    [nomain] Modules/*.lua
--    [nomain] Classes/*.lua
-- @changelog
--    + Faster handling of MIDI notes.
--    + Corrected Bug concerning huge MIDI files: MIDI Transfer was trying to open it before it was done.
--    + Presets Menu Removed 
--    + ADD forum and Donate button
--    + Support to Import Time Signature in MIDI Track MODE


script_version = "1.1"
------------------------------
info = debug.getinfo(1,'S')
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]] -- this script folder
------------------------------

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


