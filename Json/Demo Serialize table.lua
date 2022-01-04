-- @version 1.0
-- @author Daniel Lumertz

-- Thanks to rxi for the lua and JSON functions
-- Thanks to gxray for teaching how to use it. 


----- This is a demo on how to use a script to save a variable (in this case a table) into JSON and then load it back. 
----- Useful for storing information and share data between softwares.  
-- Load json file from "./utils.json"

function print(a)
    reaper.ShowConsoleMsg("\n"..tostring(a))
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

---EXEMPLE

-- Get a Path to save json (using script path)
local info = debug.getinfo(1, 'S');
local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]];

-- A TABLE
local test_table = {
    something = "hello",
    dude = 50,
    table_in_a_table = {10,50,60,80}
}

-- SAVING A TABLE TO JSON (it don't need to be a table, can be a number, string...)
save_json(script_path, "my_preset", test_table)

-- LOADING THE TABLE 
local loaded_var = load_json(script_path, "my_preset")

print(loaded_var.table_in_a_table[1])
print(loaded_var.dude)
print(loaded_var.something)

