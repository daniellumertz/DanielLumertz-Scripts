--@noindex
function CleanAllItemsLoop(proj, ext_pattern)
    ext_pattern = literalize(ext_pattern)
    local delete_list = {}
    for item in enumItems(proj) do
        local retval, stringNeedBig = reaper.GetSetMediaItemInfo_String( item, 'P_EXT:'..ext_pattern, '', false )
        if stringNeedBig:match(ext_pattern) then 
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

--- rnd_values is a table that this function will write on. Get for items and take
function GetOptions(rnd_values, item, take)
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
end

-- Alternative to GetOptions that just get from item and/or take to make it faster
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
        local retval, chance = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_TakeChance)))
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

function ExtStatePatterns()
    Ext_Name = 'Gen_Loops'

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
end