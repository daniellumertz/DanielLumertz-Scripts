LoopItemSign = '##' -- Items must start with ## and be followed by the region name
LoopItemSign_literalize = literalize(LoopItemSign)
LoopItemChanceSep = ':'

--- Return true if at least one item take is an ## item
function IsLoopItemSelected()
    for item in enumSelectedItems(proj) do
        for take in enumTakes(item) do
            local regions_table = IsTakeLoopItem(take)
            if regions_table then
                return take, regions_table -- Or should I return a table with all takes?
            end
        end
    end
    return false
end

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

-- Return a table[item] = {{id = region_id, chance = region_chance},{etc}}
function GetLoopItemsInProject(proj)
    local loop_items = {}
    for item in enumItems(proj) do
        for take in enumTakes(item) do
            local regions_table = IsTakeLoopItem(take)
            loop_items[item] = regions_table
        end
    end
    return loop_items
end