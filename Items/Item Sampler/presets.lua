-- @noindex
-- Utils functions for presets

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

function LoadPreset(table_preset)
    local settings = {}
    for key, value in pairs(table_preset) do
        settings[key] = value
    end
    return settings
end

function LoadInitialPreset() -- Here is set the default settings
    if file_exists(script_path .. "/" .. 'user_presets' .. ".json") == false then -- If there is no json file
        UserPresets = {}
        UserPresets.Default = {
            Erase = true,
            Is_trim_ItemEnd = true,
            Is_trim_StartNextNote = true,
            Is_trim_EndNote = true,
            Tips = true,
            Velocity = false,
            Vel_OriginalVal = 64,
            Vel_Min = -6,
            Vel_Max = 6,
            Pitch = false,
            Pitch_Original = 60
        }
        save_json(script_path, 'user_presets', UserPresets)
    else
        UserPresets = load_json(script_path, 'user_presets')
    end
    if UserPresets.LS_Hide then
        Settings = LoadPreset(UserPresets.LS_Hide)
    else  
        Settings = LoadPreset(UserPresets.Default)
    end
       
end

