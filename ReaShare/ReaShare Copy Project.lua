-- @noindex
local info = debug.getinfo(1,'S')
local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]] -- this script folder

dofile(script_path..'General Lua Functions.lua')
dofile(script_path..'Arrange Functions.lua')
dofile(script_path..'Chunk Functions.lua')
dofile(script_path..'ReaShare Functions.lua')

if not CheckRequirements() then return end

local chunk = GetProjectChunk(0,script_path..'temp file get project chunk.txt')
reaper.CF_SetClipboard(chunk)
reaper.defer(function() end)
