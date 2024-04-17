-- @noindex
local info = debug.getinfo(1,'S')
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]] -- this script folder

dofile(script_path..'General Lua Functions.lua')
dofile(script_path..'Arrange Functions.lua')
dofile(script_path..'Chunk Functions.lua')
dofile(script_path..'ReaShare Functions.lua')
dofile(script_path .. 'Core.lua') --Lokasenna GUI s2
dofile(script_path .. 'JSON Functions.lua') 

local retval, save_path
local try = true
while try do
    retval, save_path = reaper.GetUserInputs('ReaShare', 1, 'Path to save temp File', '')
    if not retval then return end -- User pressed cancel.
    save_path = save_path..'/' -- need to end with this

    -- check if valid path
    local test_file = save_path..'ReaShare_TestPath.txt'
    local f = io.open(test_file, "w")
    if f then
        try = false
        f:close()
        os.remove(test_file)
    else 
        print('Invalid Path!')
        print('Try Again')
    end
end
save_path = save_path..'/' -- need to end with this
save_json(script_path,'settings',{save_path = save_path})