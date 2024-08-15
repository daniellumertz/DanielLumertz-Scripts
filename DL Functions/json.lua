--@noindex
--version: 0.2
-- adjust the require

DL = DL or {}
DL.json = {}

-- Load the json functions
local json = require ("DL Functions.rxi_json") -- DL Functions. should be adjusted  to whichever folder rxi_json is on

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

--Load function
function DL.json.StringToJson(raw_text)
    if type(raw_text) ~= 'string' then
        return false
    end
    return json.decode(raw_text)
end

return json