function ItsGonnaPhase(proj)
    -- Functions
    
    --- Get an hash item and its table return the active take OR a random take. Take and take index
    ---@param item any
    ---@param item_table any
    ---@return take, number
    local function RandomizeTake(item, item_table)
        if item_table.randomize then
            -- select one of the takes 
            local sum_chance = 0
            for take_idx, take_table in ipairs(item_table.takes) do
                if type(take_table) == 'table' then
                    sum_chance = sum_chance + take_table.chance
                end
            end
            local random_number = RandomNumberFloat(0,sum_chance,false)
            local addiction_weights = 0
            for take_idx, take_table in ipairs(item_table.takes) do
                addiction_weights = addiction_weights + take_table.chance
                if addiction_weights > random_number then
                    return take_table.take, take_idx
                end
            end
        else
            local take = reaper.GetActiveTake(item)
            local take_idx = GetTakeIndex(item, take)
            return take, take_idx
        end
    end

    -- Get all ## Items non muted, and their configs
    local loop_items_list = {}
    for item in enumItems(proj) do -- Delete automation items and items inside loop items range
        local item_pos, item_len, item_end, item_randomizepaste, item_randomize
        local is_mute = reaper.GetMediaItemInfo_Value(item, 'B_MUTE') == 1
        if not is_mute then
            for take in enumTakes(item) do
                for retval, tm_name, color in enumTakeMarkers(take) do 
                    if tm_name:match('^%s-'..LoopItemSign_literalize) then -- Found Take ITem
                        -- Check if it haves the settings in ext state, else create it
                        if select(2, GetTakeExtState(take, Ext_Name, Ext_Loop_TakeChance)) == '' then
                            ApplyLoopOptionsForTakeItem(take, nil, SetDefaultsLoopItem())
                        end
                        if select(2, GetItemExtState(item, Ext_Name, Ext_Loop_RandomizeTake)) == '' then
                            ApplyLoopOptionsForTakeItem(nil, item, SetDefaultsLoopItem())
                        end
                        -- Get Loop Item information
                        item_pos = item_pos or reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
                        item_len = item_len or reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
                        item_end = item_end or (item_pos + item_len)
                        -- Get Take Information
                        local rate = reaper.GetMediaItemTakeInfo_Value(take, 'D_PLAYRATE')
                        local pitch = reaper.GetMediaItemTakeInfo_Value(take, 'D_PITCH')
                        -- Get Loop Item Random Information
                        item_randomizepaste = item_randomizepaste or select(2,GetItemExtState(item, Ext_Name, Ext_Loop_RandomizeEachPaste)) == 'true'
                        item_randomize = item_randomize or select(2,GetItemExtState(item, Ext_Name, Ext_Loop_RandomizeTake)) == 'true'
                        -- Get Loop Take Random Information 
                        local chance = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_Loop_TakeChance)))
                        print(chance)


                        local rate_min = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_Loop_MinRate)))
                        local rate_max = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_Loop_MaxRate)))
                        local rate_q = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_Loop_QuantizeRate)))
            
                        local pitch_min = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_Loop_MinPitch)))
                        local pitch_max = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_Loop_MaxPitch)))
                        local pitch_q = tonumber(select(2, GetTakeExtState(take, Ext_Name, Ext_Loop_QuantiePitch)))
                        -- Put in a table
                        if not loop_items_list[item] then
                            loop_items_list[item] = {
                                pos = item_pos,
                                len = item_len,
                                fim = item_end,
                                randomize = item_randomize,
                                randomizepaste = item_randomizepaste,
                                takes = {}
                            }
                        end
                        local t = {
                            take = take,
                            pitch = pitch,
                            rate = rate,
                            chance = chance,

                            rate_min = rate_min,
                            rate_max = rate_max,
                            rate_q = rate_q,

                            pitch_min = pitch_min,
                            pitch_max = pitch_max,
                            pitch_q = pitch_q
                        }
                        table.insert(loop_items_list[item].takes, t)
                    end
                end
            end
        end
    end

    -- Cleaning old items
    if Settings.ClearArea then 
        --CleanAllItemsLoop(proj, Ext_Name, LoopItemExt)
        for item, item_table in pairs(loop_items_list) do
            -- AI
            DeleteAutomationItemsInRange(proj,item_table.pos,item_table.fim,false,false)
            -- Items
            local items_in_range = GetItemsInRange(proj,item_table.pos,item_table.fim,false,false)
            for k, item_range in ipairs(items_in_range) do
                local retval, stringNeedBig = GetItemExtState(item_range,Ext_Name,LoopItemExt)
                if stringNeedBig ~= '' then 
                    reaper.DeleteTrackMediaItem( reaper.GetMediaItem_Track(item_range), item_range )
                end
            end
        end
    end

    -- Paste:
    if Settings.PasteAutomation or Settings.PasteItems then
        for hash_item, hash_item_table in pairs(loop_items_list) do
            local take = RandomizeTake(hash_item, hash_item_table) -- Get a random take if hash_item_table.randomize or get active take
            

            
        end
    end



    -- For every non muted ## item
        -- Clean area
        -- Get take, item  Options and region 
            -- While paste start <= ## item end
                -- Get Randomize Loop values 
                    -- Pitch
                    -- Rate
                    -- Take / or active take if no randomization
                -- Determinate pasting start and end
                -- Using while loop current pasting position < length of current pasting:
                    -- Copy non ## items in the region! If paste items
                        -- apply randomizations 
                    -- copy AI!  If Paste AI
                        -- apply randomizations 
        -- Restore saved settings 
end


    -- Save Restore
    -- Undo Blocks
    -- Get all ## Items non muted
    -- For every non muted ## item
        -- Randomize Loop Takes
        -- Get take, item  Options and region 
        -- While paste start <= ## item end
            -- Get Randomize Loop values 
                -- Pitch
                -- Rate
                -- Take
            -- Determinate pasting start and end
            -- Using while loop current pasting position < length of current pasting:
                -- Copy non ## items in the region! If paste items
                    -- apply randomizations 
                -- copy AI!  If Paste AI
                    -- apply randomizations 