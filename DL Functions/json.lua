--@noindex
--version: 0.0

DL = DL or {}
DL.json = {}

-- Load the json functions
local json = require ("rxi_json.json")

--Save function
function DL.json.save(filepath, var)
    local file = assert(io.open(filepath, "w+"))

    local serialized = json.encode(var)
    assert(file:write(serialized))

    file:close()
    return true
end

--Load function
function DL.json.load(filepath)
    local file = assert(io.open(filepath, "rb"))

    local raw_text = file:read("*all")
    file:close()

    return json.decode(raw_text)
end

return json