--@noindex
------ USER SETTINGS
------ Load Functions
-- Function to dofile all files in a path
local os_separator = package.config:sub(1,1)
function dofile_all(path)
    local i = 0
    while true do 
        local file = reaper.EnumerateFiles( path, i )
        i = i + 1
        if not file  then break end 
        dofile(path..os_separator..file)
    end
end

-- get script path
ScriptPath = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
-- dofile all files inside functions folder
dofile_all(ScriptPath..os_separator..'Functions')

------- Check Requirements
if not CheckReaImGUI('0.8.6.1') or not CheckJS() or not CheckSWS() or not CheckREAPERVersion('6.80') then return end -- Check Extensions


local proj = 0
reaper.Undo_BeginBlock2(proj)
reaper.PreventUIRefresh(1)
ExtStatePatterns() -- load ext state name variable 
for item in enumSelectedItems(proj) do
    RemoveItemExtState(item, Ext_Name, LoopItemExt)
end
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock2(proj, 'Remove Generative Loops Tags', -1)


