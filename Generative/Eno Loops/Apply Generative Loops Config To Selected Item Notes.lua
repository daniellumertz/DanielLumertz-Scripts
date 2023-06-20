--@noindex
------ Load Functions
-- Function to dofile all files in a path
function dofile_all(path)
    local i = 0
    while true do 
        local file = reaper.EnumerateFiles( path, i )
        i = i + 1
        if not file  then break end 
        dofile(path..'/'..file)
    end
end

-- get script path
ScriptPath = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
-- dofile all files inside functions folder
dofile_all(ScriptPath..'/'..'Functions')




local proj = 0
local items_pattern = '$$$LOOP_CONFIG$$$'
local base_setting = [[
    $Time Randomize: 0 - 0
    $Time Random Quantize: 0
    $Pitch Randomize: 0 - 0
    $Pitch Random Quantize: 0
    $Playrate Randomize: 0
    $Playrate Random Quantize: 0
    $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$]]

reaper.Undo_BeginBlock2(proj)

for selected_item in enumSelectedItems(proj) do
    local retval, stringNeedBig = reaper.GetSetMediaItemInfo_String( selected_item, 'P_NOTES', '', false )
    local literal = literalize(items_pattern)
    print(stringNeedBig:match(literal) )
    if not stringNeedBig:match(literal) then
        stringNeedBig = items_pattern..'\n'..base_setting..'\n'..stringNeedBig
        local retval, _ = reaper.GetSetMediaItemInfo_String( selected_item, 'P_NOTES', stringNeedBig, true )
    end
end


reaper.Undo_EndBlock2(proj, 'Apply Eno Loop Config To Selected Item Notes', -1)