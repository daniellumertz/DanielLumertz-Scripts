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

function IsTakeLoopItem(take)
    for retval, tm_name, color in enumTakeMarkers(take) do -- tm = take marker 
        if tm_name:match('^%s-'..LoopItemSign_literalize) then 
            local regions = {}
            local tm_name_nospace = tm_name:gsub('%s','')
            for region_string in tm_name_nospace:gmatch(LoopItemSign_literalize..'([%d%a:]+)') do
                local region_id = region_string:match('(%d+)'..LoopItemChanceSep..'?')
                local region_chance = region_string:match(LoopItemChanceSep..'(%d+)')
                regions[#regions+1] = {id = region_id, chance = region_chance}
            end

            return regions
        end
    end
    return false
end

local item = reaper.GetSelectedMediaItem(proj, 0)
local take = reaper.GetActiveTake(item)
local reg = IsTakeLoopItem(take)
if reg then
    tprint(reg)
end