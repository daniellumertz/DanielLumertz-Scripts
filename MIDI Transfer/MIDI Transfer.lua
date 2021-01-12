--[[
@description MIDI Transfer
@author Daniel Lumertz
@version 1.0
@about MIDI Transfer
--    [main=MIDI Transfer] .
--    [nomain] Table to string.lua
--    [nomain] Core.lua
--    [nomain] General Functions.lua
--    [nomain] GUI.lua
--    [nomain] main.lua
--    [nomain] map_func.lua
--    [nomain] Modules/*.lua
--    [nomain] Classes/*.lua
]]
script_version = "0.52"
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


