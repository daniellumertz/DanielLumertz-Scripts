-- @noindex
function file_exists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
 end

-- Load the json functions
package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
local json = require ("./utils.json")


--Save function
function save_json(path, name,  var)
    local filepath = path .. "/" .. name .. ".json"
    local file = assert(io.open(filepath, "w+"))

    local serialized = json.encode(var)
    assert(file:write(serialized))

    file:close()
    return true
end

--Load function
function load_json(path, name)
    local filepath = path .. "/" .. name .. ".json"
    local file = assert(io.open(filepath, "rb"))

    local raw_text = file:read("*all")
    file:close()

    return json.decode(raw_text)
end

-- Load Configs
function LoadConfigs(script_path, file_name)
    local Configs
    if file_exists(script_path .. "/" ..file_name.. ".json") == false then
        Configs = {
            Max = 10,
            AutoExit = true,
            AutoUpdate = false,
            AutoPaste = true
        }
        save_json(script_path, file_name, Configs)
    else
        Configs = load_json(script_path,file_name)
    end

    return Configs
end

