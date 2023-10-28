function CreateProjectSettings()
    return {
        IsPhaseItems = true,
        IsPhaseAutomation = true,
    }
end

--- Defaults
function SetItemDefaults()
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
    t.TakeChance = 1
    t.RandomizeTakes = false
    return t    
end


---------------Items
--- Ext names
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
    Ext_Loop_MinRate = 'LoopMinRate'
    Ext_Loop_MaxRate = 'LoopMaxRate'
    Ext_Loop_QuantizeRate = 'LoopQuantizeRate' 
    --Loop items
    LoopItemSign = '##' -- Items must start with ## and be followed by the region name
    LoopItemSign_literalize = literalize(LoopItemSign)
    -- Item created by the script
    LoopItemExt = 'GenItemLoop'
end

--- Apply 
----- Loop Items
function ApplyLoopOptions()
    for selected_item in enumSelectedItems(proj) do
        local take = reaper.GetActiveTake(selected_item)
        SetItemExtState(selected_item, Ext_Name, Ext_Loop_RandomizeTake, tostring(LoopItemOptions.RandomizeTakes))
        SetTakeExtState(take, Ext_Name, Ext_Loop_TakeChance, tostring(LoopItemOptions.TakeChance))
        SetTakeExtState(take, Ext_Name, Ext_Loop_MinRate, tostring(LoopItemOptions.PlayRateRandomMin)) -- cannot be 0!
        SetTakeExtState(take, Ext_Name, Ext_Loop_MaxRate, tostring(LoopItemOptions.PlayRateRandomMax)) -- cannot be 0!
        SetTakeExtState(take, Ext_Name, Ext_Loop_QuantizeRate, tostring(LoopItemOptions.PlayRateQuantize))
    end    
end

----- Items
function ApplyOptions()
    for selected_item in enumSelectedItems(proj) do
        local take = reaper.GetActiveTake(selected_item)
        SetItemExtState(selected_item, Ext_Name, Ext_RandomizeTake, tostring(ItemsOptions.RandomizeTakes))
        SetTakeExtState(take, Ext_Name, Ext_TakeChance, tostring(ItemsOptions.TakeChance))
        SetItemExtState(selected_item, Ext_Name, Ext_MinTime, tostring(ItemsOptions.TimeRandomMin))
        SetItemExtState(selected_item, Ext_Name, Ext_MaxTime, tostring(ItemsOptions.TimeRandomMax))
        SetItemExtState(selected_item, Ext_Name, Ext_QuantizeTime, tostring(ItemsOptions.TimeQuantize))
        SetTakeExtState(take, Ext_Name, Ext_MinPitch, tostring(ItemsOptions.PitchRandomMin))
        SetTakeExtState(take, Ext_Name, Ext_MaxPitch, tostring(ItemsOptions.PitchRandomMax))
        SetTakeExtState(take, Ext_Name, Ext_QuantizePitch, tostring(ItemsOptions.PitchQuantize))
        SetTakeExtState(take, Ext_Name, Ext_MinRate, tostring(ItemsOptions.PlayRateRandomMin)) -- cannot be 0!
        SetTakeExtState(take, Ext_Name, Ext_MaxRate, tostring(ItemsOptions.PlayRateRandomMax)) -- cannot be 0!
        SetTakeExtState(take, Ext_Name, Ext_QuantizeRate, tostring(ItemsOptions.PlayRateQuantize))
    end    
end

--- Get

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

