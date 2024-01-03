--@noindex
function CleanAllItemsLoop(proj, ext_state_key, ext_pattern)
    ext_pattern = literalize(ext_pattern)
    local delete_list = {}
    for item in enumItems(proj) do
        local retval, stringNeedBig = GetItemExtState(item,ext_state_key,ext_pattern)
        --local retval, stringNeedBig = reaper.GetSetMediaItemInfo_String( item, 'P_EXT:'..ext_pattern, '', false )
        if stringNeedBig ~= '' then 
            table.insert(delete_list,item)
        end
    end
    for k, item in ipairs(delete_list) do
        reaper.DeleteTrackMediaItem( reaper.GetMediaItem_Track(item), item )
    end
    -- Automation Items Dont work it is only for pools
    --[[ for track in enumTracks(proj) do
        for env in enumTrackEnvelopes(track) do
            local delete_list = {}
            local cnt = reaper.CountAutomationItems(env)
            for i = 0, cnt - 1 do
                local retval, ext_state = reaper.GetSetAutomationItemInfo_String(env, i, 'P_POOL_EXT:'..ext_pattern, '', false)
                print(ext_state)
                if ext_state:match(ext_pattern) then 
                    delete_list[#delete_list+1] = i 
                end
            end
            DeleteAutomationItem(env,delete_list)
        end
    end ]]
end

---Remove the ext state from items
---@param sel_items table table with the items numerically
---@param ext_state_key any
---@param ext_pattern any
function RemoveItemExtState(item, ext_state_key, ext_pattern)
    local retval, stringNeedBig = GetItemExtState(item,ext_state_key,ext_pattern)
    --local retval, stringNeedBig = reaper.GetSetMediaItemInfo_String( item, 'P_EXT:'..ext_pattern, '', false )
    if stringNeedBig ~= '' then 
        SetItemExtState(item,ext_state_key,ext_pattern,'')
    end
end

--- rnd_values is a table that this function will write on. Get for items and take
function GetOptions(rnd_values, item, take)
    local rnd_values = {}
    local retval, min_time = GetItemExtState(item, Ext_Name, Ext_MinTime) -- check with just one if present then get all
    if min_time ~= '' then
        rnd_values.RandomizeTakes = (select(2, GetItemExtState(item, Ext_Name, Ext_RandomizeTake))) == 'true'
        rnd_values.TakeChance = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_TakeChance)))
        rnd_values.TimeRandomMin = tonumber(min_time)
        rnd_values.TimeRandomMax = tonumber(select(2, GetItemExtState(item, Ext_Name, Ext_MaxTime)))
        rnd_values.TimeQuantize = tonumber(select(2, GetItemExtState(item, Ext_Name, Ext_QuantizeTime)))
        rnd_values.PitchRandomMin = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_MinPitch)))
        rnd_values.PitchRandomMax = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_MaxPitch)))
        rnd_values.PitchQuantize = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_QuantizePitch)))
        rnd_values.PlayRateRandomMin = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_MinRate)))-- cannot be 0!
        rnd_values.PlayRateRandomMax = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_MaxRate))) -- cannot be 0!
        rnd_values.PlayRateQuantize = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_QuantizeRate)))
    else -- current item dont have ext states values load default
        rnd_values = SetDefaults()
    end
    return rnd_values
end

-- Alternative to GetOptions that just get from item and/or take to make it faster. I dont like this function try to remove
function GetOptionsItemTake(rnd_values, item, take)
    if item then
        local retval, min_time = GetItemExtState(item, Ext_Name, Ext_MinTime) -- check with just one if present then get all
        if min_time ~= '' then
            rnd_values.TimeRandomMin = tonumber(min_time)
            rnd_values.RandomizeTakes = (select(2, GetItemExtState(item, Ext_Name, Ext_RandomizeTake))) == 'true'
            rnd_values.TimeRandomMax = tonumber(select(2, GetItemExtState(item, Ext_Name, Ext_MaxTime)))    
            rnd_values.TimeQuantize = tonumber(select(2, GetItemExtState(item, Ext_Name, Ext_QuantizeTime)))
        else
            local defaults = SetDefaults()
            rnd_values.TimeRandomMin = defaults.TimeRandomMin
            rnd_values.RandomizeTakes = defaults.RandomizeTakes
            rnd_values.TimeRandomMax = defaults.TimeRandomMax
            rnd_values.TimeQuantize = defaults.TimeQuantize
        end
    end

    if take then
        local retval, chance = GetTakeExtState(take, Ext_Name, Ext_TakeChance)
        if chance ~= '' then
            rnd_values.TakeChance = tonumber(chance)
            rnd_values.PitchRandomMin = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_MinPitch)))
            rnd_values.PitchRandomMax = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_MaxPitch)))
            rnd_values.PitchQuantize = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_QuantizePitch)))
            rnd_values.PlayRateRandomMin = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_MinRate)))-- cannot be 0!
            rnd_values.PlayRateRandomMax = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_MaxRate))) -- cannot be 0!
            rnd_values.PlayRateQuantize = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_QuantizeRate)))
        else -- current take dont have ext states values load default

            local defaults = SetDefaults()
            rnd_values.TakeChance = defaults.TakeChance
            rnd_values.PitchRandomMin = defaults.PitchRandomMin
            rnd_values.PitchRandomMax = defaults.PitchRandomMax
            rnd_values.PitchQuantize = defaults.PitchQuantize
            rnd_values.PlayRateRandomMin = defaults.PlayRateRandomMin -- cannot be 0!
            rnd_values.PlayRateRandomMax = defaults.PlayRateRandomMax-- cannot be 0!
            rnd_values.PlayRateQuantize = defaults.PlayRateQuantize
        end
    end
end

--Yet another alternative that return a table with all values structure is
--t:
--  selected: b
--  item_pos: n
--  item_len: n
--  item_end: n
--  track: track*
--  --ext states
--  TimeRandomMin: n
--  randomize: B
--  TimeRandomMax: n
--  TimeQuantize: n
--  takes:
--      n:
--          take = take
--          chance: n
--          PitchRandomMin: n
--          PitchRandomMax: n
--          PitchQuantize: n
--          PlayRateRandomMin: n
--          PlayRateRandomMax: n
--          PlayRateQuantize: n
--          pitch: n
--          rate: n
function GetOptionsItemInATable(item)
    local t = {}
    local defaults = SetDefaults()
    local retval, min_time = GetItemExtState(item, Ext_Name, Ext_MinTime) -- check with just one if present then get all
    if min_time ~= '' then
        t.TimeRandomMin = tonumber(min_time)
        t.randomize = (select(2, GetItemExtState(item, Ext_Name, Ext_RandomizeTake))) == 'true'
        t.TimeRandomMax = tonumber(select(2, GetItemExtState(item, Ext_Name, Ext_MaxTime)))    
        t.TimeQuantize = tonumber(select(2, GetItemExtState(item, Ext_Name, Ext_QuantizeTime)))
    else
        t.TimeRandomMin = defaults.TimeRandomMin
        t.randomize = defaults.RandomizeTakes
        t.TimeRandomMax = defaults.TimeRandomMax
        t.TimeQuantize = defaults.TimeQuantize
    end
    -- normal info
    t.track = reaper.GetMediaItemTrack(item)
    t.item_pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    t.item_len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    t.item_end = (t.item_pos + t.item_len)
    t.selected = reaper.GetMediaItemInfo_Value(item, 'B_UISEL')
    
    t.takes = {}
    for take in enumTakes(item) do
        t.takes[#t.takes+1] = {take = take}
        local tk_t = t.takes[#t.takes] -- shortchut name
        local retval, chance = GetTakeExtState(take, Ext_Name, Ext_TakeChance)
        if chance ~= '' then
            tk_t.chance = tonumber(chance)
            tk_t.PitchRandomMin = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_MinPitch)))
            tk_t.PitchRandomMax = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_MaxPitch)))
            tk_t.PitchQuantize = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_QuantizePitch)))
            tk_t.PlayRateRandomMin = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_MinRate)))-- cannot be 0!
            tk_t.PlayRateRandomMax = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_MaxRate))) -- cannot be 0!
            tk_t.PlayRateQuantize = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_QuantizeRate)))
        else -- current take dont have ext states values load default
            tk_t.chance = defaults.TakeChance
            tk_t.PitchRandomMin = defaults.PitchRandomMin
            tk_t.PitchRandomMax = defaults.PitchRandomMax
            tk_t.PitchQuantize = defaults.PitchQuantize
            tk_t.PlayRateRandomMin = defaults.PlayRateRandomMin -- cannot be 0!
            tk_t.PlayRateRandomMax = defaults.PlayRateRandomMax-- cannot be 0!
            tk_t.PlayRateQuantize = defaults.PlayRateQuantize
        end
        tk_t.pitch = reaper.GetMediaItemTakeInfo_Value(take, 'D_PITCH')
        --tk_t.offset =  reaper.GetMediaItemTakeInfo_Value(take, 'D_STARTOFFS')
        tk_t.rate = reaper.GetMediaItemTakeInfo_Value(take, 'D_PLAYRATE')
    end    

    return t   
end

--t:
    --pos:
    --len:
    --fim:
    --rate:
    --selected:
function GetOptionsAutomationItemInATable(env,ai_idx)
    local t = {}
    t.pos = reaper.GetSetAutomationItemInfo(env, ai_idx, 'D_POSITION', 0, false)
    t.len = reaper.GetSetAutomationItemInfo(env, ai_idx, 'D_LENGTH', 0, false)
    t.fim = t.pos + t.len
    t.selected = reaper.GetSetAutomationItemInfo(env, ai_idx, 'D_UISEL', 0, false)
    t.rate = reaper.GetSetAutomationItemInfo(env, ai_idx, 'D_PLAYRATE', 0, false)
    return t
end

function GetLoopOptions(item,take) -- Return a table with the options {RandomizeTakes = bol, TakeChance = 1, PlayRateRandomMin = 1, PlayRateRandomMax = 1, PlayRateQuantize = 0}}
    local t = {}
    local default = SetDefaultsLoopItem()
    if item then
        local retval, randomize_takes = GetItemExtState(item, Ext_Name, Ext_Loop_RandomizeTake) -- check with just one if present then get all
        if randomize_takes ~= '' then
            t.RandomizeTakes = randomize_takes == 'true'
            t.RandomizeEachPaste = select(2,GetItemExtState(item, Ext_Name, Ext_Loop_RandomizeEachPaste)) == 'true' -- check with just one if present then get all
        else
            t.RandomizeTakes = default.RandomizeTakes
            t.RandomizeEachPaste = default.RandomizeEachPaste
        end
    end

    if take then
        local retval, chance = GetTakeExtState(take, Ext_Name, Ext_Loop_TakeChance)
        if chance ~= '' then
            t.TakeChance = tonumber(chance)
            t.PlayRateRandomMin = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_Loop_MinRate)))
            t.PlayRateRandomMax = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_Loop_MaxRate)))
            t.PlayRateQuantize = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_Loop_QuantizeRate)))

            t.PitchRandomMin = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_Loop_MinPitch)))
            t.PitchRandomMax = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_Loop_MaxPitch)))
            t.PitchQuantize = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_Loop_QuantiePitch)))

        else
            t.TakeChance = default.TakeChance
            t.PlayRateRandomMin = default.PlayRateRandomMin
            t.PlayRateRandomMax = default.PlayRateRandomMax
            t.PlayRateQuantize = default.PlayRateQuantize

            t.PitchRandomMin = default.PitchRandomMin
            t.PitchRandomMax = default.PitchRandomMax
            t.PitchQuantize = default.PitchQuantize
        end
    end    
    return t    
end

--- Defaults
function SetDefaults()
    local rnd_values = {}
    rnd_values.RandomizeTakes = false
    rnd_values.TakeChance = 1
    rnd_values.TimeRandomMin = 0
    rnd_values.TimeRandomMax = 0
    rnd_values.TimeQuantize = 0
    rnd_values.PitchRandomMin = 0
    rnd_values.PitchRandomMax = 0
    rnd_values.PitchQuantize = 0
    rnd_values.PlayRateRandomMin = 1 -- cannot be 0!
    rnd_values.PlayRateRandomMax = 1 -- cannot be 0!
    rnd_values.PlayRateQuantize = 0
    return rnd_values
end

function SetDefaultsLoopItem()
    local t = {}
    t.PlayRateRandomMin = 1
    t.PlayRateRandomMax = 1
    t.PlayRateQuantize = 0
    t.PitchRandomMin = 0
    t.PitchRandomMax = 0
    t.PitchQuantize = 0
    t.TakeChance = 1
    t.RandomizeTakes = false
    t.RandomizeEachPaste = true
    return t    
end

function SetDefaultSettings()
    local t = {}
    t.PasteItems = true -- Paste Items
    t.PasteAutomation = true -- Paste AI
    t.ClearArea = true -- Clear Previousm made items before pasting new ones
    return t
end

----- Loop Items

-- Apply to all selected items and takes (for UI)
function ApplyLoopOptions()
    for selected_item in enumSelectedItems(proj) do
        local take = reaper.GetActiveTake(selected_item)
        SetItemExtState(selected_item, Ext_Name, Ext_Loop_RandomizeTake, tostring(LoopOption.RandomizeTakes))
        SetTakeExtState(take, Ext_Name, Ext_Loop_TakeChance, tostring(LoopOption.TakeChance))
        SetItemExtState(selected_item, Ext_Name, Ext_Loop_RandomizeEachPaste, tostring(LoopOption.RandomizeEachPaste))

        SetTakeExtState(take, Ext_Name, Ext_Loop_MinRate, tostring(LoopOption.PlayRateRandomMin)) -- cannot be <=0!
        SetTakeExtState(take, Ext_Name, Ext_Loop_MaxRate, tostring(LoopOption.PlayRateRandomMax)) -- cannot be <=0!
        SetTakeExtState(take, Ext_Name, Ext_Loop_QuantizeRate, tostring(LoopOption.PlayRateQuantize))

        SetTakeExtState(take, Ext_Name, Ext_Loop_MinPitch, tostring(LoopOption.PitchRandomMin)) 
        SetTakeExtState(take, Ext_Name, Ext_Loop_MaxPitch, tostring(LoopOption.PitchRandomMax)) 
        SetTakeExtState(take, Ext_Name, Ext_Loop_QuantiePitch, tostring(LoopOption.PitchQuantize))

    end    
end

-- Apply to specific items and takes (for setting defaults)
function ApplyLoopOptionsForTakeItem(take, item, table_settings)
    if item then
        SetItemExtState(item, Ext_Name, Ext_Loop_RandomizeTake, tostring(table_settings.RandomizeTakes))
        SetItemExtState(item, Ext_Name, Ext_Loop_RandomizeEachPaste, tostring(table_settings.RandomizeEachPaste))
    end
    
    if take then
        SetTakeExtState(take, Ext_Name, Ext_Loop_TakeChance, tostring(table_settings.TakeChance))

        SetTakeExtState(take, Ext_Name, Ext_Loop_MinRate, tostring(table_settings.PlayRateRandomMin)) -- cannot be <=0!
        SetTakeExtState(take, Ext_Name, Ext_Loop_MaxRate, tostring(table_settings.PlayRateRandomMax)) -- cannot be <=0!
        SetTakeExtState(take, Ext_Name, Ext_Loop_QuantizeRate, tostring(table_settings.PlayRateQuantize))

        SetTakeExtState(take, Ext_Name, Ext_Loop_MinPitch, tostring(table_settings.PitchRandomMin)) 
        SetTakeExtState(take, Ext_Name, Ext_Loop_MaxPitch, tostring(table_settings.PitchRandomMax)) 
        SetTakeExtState(take, Ext_Name, Ext_Loop_QuantiePitch, tostring(table_settings.PitchQuantize))
    end
end


----- Items
function ApplyOptions()
    for selected_item in enumSelectedItems(proj) do
        local take = reaper.GetActiveTake(selected_item)
        if take then
            SetItemExtState(selected_item, Ext_Name, Ext_RandomizeTake, tostring(rnd_values.RandomizeTakes))
            SetTakeExtState(take, Ext_Name, Ext_TakeChance, tostring(rnd_values.TakeChance))
            SetItemExtState(selected_item, Ext_Name, Ext_MinTime, tostring(rnd_values.TimeRandomMin))
            SetItemExtState(selected_item, Ext_Name, Ext_MaxTime, tostring(rnd_values.TimeRandomMax))
            SetItemExtState(selected_item, Ext_Name, Ext_QuantizeTime, tostring(rnd_values.TimeQuantize))
            SetTakeExtState(take, Ext_Name, Ext_MinPitch, tostring(rnd_values.PitchRandomMin))
            SetTakeExtState(take, Ext_Name, Ext_MaxPitch, tostring(rnd_values.PitchRandomMax))
            SetTakeExtState(take, Ext_Name, Ext_QuantizePitch, tostring(rnd_values.PitchQuantize))
            SetTakeExtState(take, Ext_Name, Ext_MinRate, tostring(rnd_values.PlayRateRandomMin)) -- cannot be <=0!
            SetTakeExtState(take, Ext_Name, Ext_MaxRate, tostring(rnd_values.PlayRateRandomMax)) -- cannot be <=0!
            SetTakeExtState(take, Ext_Name, Ext_QuantizeRate, tostring(rnd_values.PlayRateQuantize))
        end
    end    
end

function ExtStatePatterns()
    Ext_Name = 'daniellumertz_ItsGonnaPhase'

    Ext_RandomizeTake = 'RandTakes'    
    Ext_TakeChance = 'TakeChance'    
    Ext_MinTime = 'MinTime'    
    Ext_MaxTime = 'MaxTime'    
    Ext_QuantizeTime = 'QuantizeTime'    
    Ext_MinPitch = 'MinPitch'    
    Ext_MaxPitch = 'MaxPitch'
    Ext_QuantizePitch = 'QuantizePitch'    
    Ext_MinRate = 'MinRate'    
    Ext_MaxRate = 'MaxRate'    
    Ext_QuantizeRate = 'QuantizeRate'    
    --for ## items
    Ext_Loop_RandomizeTake = 'LoopRandTakes'
    Ext_Loop_TakeChance = 'LoopTakeChance'
    Ext_Loop_RandomizeEachPaste = 'LoopRandomizeEachPaste'
    Ext_Loop_MinRate = 'LoopMinRate'
    Ext_Loop_MaxRate = 'LoopMaxRate'
    Ext_Loop_QuantizeRate = 'LoopQuantizeRate'
    Ext_Loop_MinPitch = 'LoopMinPitch'
    Ext_Loop_MaxPitch = 'LoopMaxPitch'
    Ext_Loop_QuantiePitch = 'LoopQuantizePitch'
    --Loop items
    LoopItemSign = '##' -- Items must start with ## and be followed by the region name
    LoopItemSign_literalize = literalize(LoopItemSign)
    -- Item created by the script
    LoopItemExt = 'daniellumertz_PhaseItem'
end

-- remove the Generated item ext state for all selected items
function RemoveGenExtState()
    for item in enumItems(proj) do
        SetItemExtState(item, Ext_Name, LoopItemExt, '' )
    end
end

--- Return true if at least one item take is an ## item, also return if an item generated with this script is selected
function IsLoopItemSelected()
    local is_loop_item, is_gen_item
    for item in enumSelectedItems(proj) do
        for take in enumTakes(item) do
            for retval, tm_name, color in enumTakeMarkers(take) do -- tm = take marker 
                if tm_name:match('^%s-'..LoopItemSign_literalize) then 
                    local user_region_id = tonumber(tm_name:match('^%s-'..LoopItemSign_literalize..'%s-(%d+)')) -- to check if the id is right and not misspelled
                    if user_region_id then --  ## MARKER! found in a take
                        is_loop_item = true
                    end
                end
            end
        end

        is_gen_item = is_gen_item or GetItemExtState(item,Ext_Name,LoopItemExt)

        if is_loop_item == true and is_gen_item == true then -- Dont need to check for more if both are true
            break
        end
    end
    return is_loop_item, is_gen_item
end


---Return a list with all items in a time range, excluding hash items
---@param proj project
---@param start_range number beginning of the range (start point are includded in the range)
---@param fim_range number end of the range (end points are not includded in the range)
---@param only_start_in_range boolean only get items that start inside the range (if start at start_range it is includded)
---@param only_end_in_range boolean only get items that end inside the range (if end at the fim_range it is includded)
function GetNonHashItemsInRange(proj,start_range,fim_range,only_start_in_range,only_end_in_range)
    local item_list = {}
    for track in enumTracks(proj) do
        for item in enumTrackItems(track) do 
            for take in enumTakes(item) do -- Dont copy hash items!
                for retval, tm_name, color in enumTakeMarkers(take) do -- tm = take marker 
                    if tm_name:match('^%s-'..LoopItemSign_literalize) then 
                        goto continue
                    end
                end
            end

            local pos = reaper.GetMediaItemInfo_Value( item, 'D_POSITION')

            if only_start_in_range and pos < start_range then goto continue end -- filter if only_start_in_range 
            if pos >= fim_range then break end -- start after range. break

            local len = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH')
            local final_pos = len + pos
            if only_end_in_range and final_pos > fim_range then goto continue end -- filter if only_end_in_range

            if final_pos > start_range then
                item_list[#item_list+1] = item
            end

            ::continue::
        end
    end
    return item_list
end
