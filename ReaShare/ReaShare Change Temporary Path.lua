-- @noindex
local info = debug.getinfo(1,'S')
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]] -- this script folder

dofile(script_path..'General Lua Functions.lua')
dofile(script_path..'Arrange Functions.lua')
dofile(script_path..'Chunk Functions.lua')
dofile(script_path..'ReaShare Functions.lua')
dofile(script_path .. 'Core.lua') --Lokasenna GUI s2
dofile(script_path .. 'JSON Functions.lua') 

local retval, save_path = reaper.GetUserInputs('ReaShare', 1, 'Path to save temp File', '')
if not retval then return end -- User pressed cancel.
save_path = save_path..'/' -- need to end with this
save_json(script_path,'settings',{save_path = save_path})