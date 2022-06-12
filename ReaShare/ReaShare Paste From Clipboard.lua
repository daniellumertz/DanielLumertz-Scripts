-- @noindex
local info = debug.getinfo(1,'S')
local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]] -- this script folder

dofile(script_path..'General Lua Functions.lua')
dofile(script_path..'Arrange Functions.lua')
dofile(script_path..'Chunk Functions.lua')
dofile(script_path..'ReaShare Functions.lua')
dofile(script_path .. 'JSON Functions.lua') 

-- Patterns
if not CheckRequirements() then return end

local pasted_chunk = reaper.CF_GetClipboard()
ReaSharePaste(pasted_chunk, script_path)
