-- @noindex
reaper.Main_OnCommand(40057, 0) --40057

if reaper.GetCursorContext() ~= 1 then return end
--
local version = '1.0'
local info = debug.getinfo(1, 'S');
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
configs_filename = 'configs' -- Json name


dofile(script_path .. 'Serialize Table.lua') -- Functions to generate a string from a table 
dofile(script_path .. 'Clipboard Functions.lua') -- Functions for this script
dofile(script_path .. 'General Functions.lua') -- General Functions needed
dofile(script_path .. 'preset.lua') -- preset to work with JSON

-- Copy:
-- Get current if any Table in ext state
-- Write at end of the table the current items selection
-- If table bigger than X delete first item in table and use table.remove
-- Serialize table
-- Write table

--- Loading

-- Load Clipboard table
local clipboard_table = LoadClipboardTable()

-- Save current selection at the start of the table 
local item_table = SaveSelectedItems()
if #item_table == 0 then return end
table.insert(clipboard_table, 1 ,item_table)

--- Load Configs 
Configs = LoadConfigs(script_path, configs_filename)

-- Delete last item if table is bigger than max_size (move the rest -1)
if #clipboard_table > Configs.Max then
    while #clipboard_table > Configs.Max do
        table.remove(clipboard_table,#clipboard_table)
    end
end

-- Serialize Table
SaveClipboardTable(clipboard_table)
