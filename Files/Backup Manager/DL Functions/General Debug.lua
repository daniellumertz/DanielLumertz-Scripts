--@noindex
--version: 0.12
---------------------
----------------- Debug/Prints 
---------------------
function print(...) 
    local t = {}
    for i, v in ipairs( { ... } ) do
        t[i] = tostring( v )
    end
    reaper.ShowConsoleMsg( table.concat( t, " " ) .. "\n" )
end

---Create/append a file with some string 
---@param path string path with a file name as : "C:\\Users\\DSL\\Downloads\\test files\\hello.txt"
---@param ... any something to print, it will be converted using tostring, pass as much arguments as needs, they will be concatenated with ' '
---@diagnostic disable-next-line: lowercase-global
function filePrint(path,...)
    local t = {}
    for i, v in ipairs( { ... } ) do
        t[i] = tostring( v )
    end
    local txt =  table.concat( t, " " )

    -- Specify the file path and name
    local file_path = path

    -- Open the file for writing
    local file = io.open(file_path, "a")

    if file then
        -- Append at the file
        file:write('\n'..txt)
        
        -- Close the file
        file:close()
        --print("File created and data written successfully.")
        return true
    else
        --print("Error opening the file for writing.")
        return false
    end
end

---Print a table with indentation
---@param tbl table
---@param indent number|? 
---@diagnostic disable-next-line: lowercase-global
function tprint (tbl, indent)
    if not indent then indent = 0 end
    for k, v in pairs(tbl) do
        local formatting = string.rep("  ", indent) .. tostring(k) .. ": "
        if type(v) == "table" then
            print(formatting)
            tprint(v, indent+1)
        elseif type(v) == 'boolean' then
            print(formatting .. tostring(v))      
        else
            print(formatting .. tostring(v))
        end
    end
end

---Print the delta between start and now
---@param start number
---@diagnostic disable-next-line: lowercase-global
function print_time(start)
    print(reaper.time_precise() - start)
end