--@noindex
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
                    return take_table.take, take_idx-1
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
                        local region_id = tonumber(tm_name:match('%d+'))
                        local retval, isrgn, region_start, region_end ,region_name,region_user_id,color,region_id = GetMarkByID(proj,region_id,2)
                        if retval then
                            local region_table = {region_start = region_start,
                                                region_end = region_end,
                                                region_id = region_id}
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
                                pitch_q = pitch_q,

                                region = region_table
                            }
                            table.insert(loop_items_list[item].takes, t)
                        end
                    end
                end
            end
        end
    end

    if not TableHaveAnything(loop_items_list) then
        return false
    end

    -- Start applying
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2(proj)

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

    -- Create table to store information about items being pasted (save resources)
    local oi_settings = {} -- table containing all settings from original items that were cought in a region in a pasting. Structure defined at GetOptionsItemInATable 
    -- Paste:
    local safe_paste_maxvalue = 10000 -- Set a celling of how many pastes to avoid complete freeze
    if Settings.PasteAutomation or Settings.PasteItems then
        for hash_item, hash_item_table in pairs(loop_items_list) do
            if not reaper.ValidatePtr2(proj, hash_item, 'MediaItem*') then goto continue2 end -- In case the hash item were deleted in the cleaning old items area. (Can happen if user make a generated item an hash item)
            -- Paste Items and AI
            local take, take_idx
            local pasting_pos = hash_item_table.pos
            local pasting_idx = 0 -- count how many paste it had done
            while pasting_pos < hash_item_table.fim do
                -- Get take
                if pasting_idx == 0 or (hash_item_table.randomizepaste and hash_item_table.randomize) then -- Change take value for first paste or every paste
                    take, take_idx = RandomizeTake(hash_item, hash_item_table)
                    take_idx = take_idx + 1
                end
                local take_table = hash_item_table.takes[take_idx]
                local region_table = take_table.region
                -- Get hash Radomize values per paste
                local hash_random_rate = RandomNumberFloatQuantized(take_table.rate_min, take_table.rate_max, true, take_table.rate_q)
                local hash_rate = take_table.rate * hash_random_rate
                local hash_random_pitch = RandomNumberFloatQuantized(take_table.pitch_min, take_table.pitch_max, true, take_table.pitch_q)
                local hash_pitch = take_table.pitch + hash_random_pitch
                -- Calculate this pasting length
                local paste_len = (region_table.region_end - region_table.region_start) * (1/hash_rate)
                ----------------------
                if Settings.PasteItems then
                    local paste_items = GetNonHashItemsInRange(proj,region_table.region_start,region_table.region_end,false,false) -- This is getting items that start and end off the range! So remember to crop them each paste! 
                    for k, item in ipairs(paste_items) do
                        -- get information about the item
                        if not oi_settings[item] then 
                            oi_settings[item] = GetOptionsItemInATable(item)
                        end
                        -- Paste Items
                        local dif = oi_settings[item].item_pos - region_table.region_start  -- Difference between region start and original item position
                        dif = dif /hash_rate
                        if (pasting_pos + dif) >= hash_item_table.fim then -- Items out of range break this hash item loop 
                            break
                        end
                        local new_item = CopyMediaItemToTrack(item, oi_settings[item].track, pasting_pos + dif)
                        -- Crop to pasting start and pasting start + region length (don't consider the rate now, in order to crop properlly)
                        if oi_settings[item].item_pos < region_table.region_start then -- If original item started before the region
                            CropItem(new_item, pasting_pos, nil)
                        end 
                        if oi_settings[item].item_end > region_table.region_end then -- If original item passed the region end 
                            CropItem(new_item, nil, pasting_pos + region_table.region_end - region_table.region_start) -- Crop using the length of the region
                        end 
                        -- Get information about the new item
                        local new_item_pos = reaper.GetMediaItemInfo_Value(new_item, 'D_POSITION')
                        local new_item_len = reaper.GetMediaItemInfo_Value(new_item, 'D_LENGTH')
                        local new_item_end = new_item_pos + new_item_len
                        -- Apply randomizations
                        -- Position
                        local rnd_time = RandomNumberFloatQuantized(oi_settings[item].TimeRandomMin,oi_settings[item].TimeRandomMax, true, oi_settings[item].TimeQuantize)
                        local new_pos = new_item_pos + rnd_time
                        -- Delete Items placed after the end of a hash item. 
                        if new_pos >= hash_item_table.fim then
                            reaper.DeleteTrackMediaItem( oi_settings[item].track, new_item)
                            goto continue
                        end
                        reaper.SetMediaItemInfo_Value(new_item, 'D_POSITION', new_pos)

                        local new_length
                        if #oi_settings[item].takes > 0 then  -- Only items with takes (not notes items)
                            -- Take
                            local new_take, new_take_idx, _
                            if oi_settings[item].randomize then
                                _, new_take_idx = RandomizeTake(item, oi_settings[item])
                                new_take = reaper.GetTake(new_item, new_take_idx)
                                reaper.SetActiveTake(new_take)
                            end
                            new_take = new_take or reaper.GetActiveTake(new_item)
                            new_take_idx = new_take_idx or GetTakeIndex(new_item,new_take)
                            local oi_take_table = oi_settings[item].takes[new_take_idx+1]
                            -- Pitch
                            local rnd_pitch = RandomNumberFloatQuantized(oi_take_table.PitchRandomMin,oi_take_table.PitchRandomMax, true, oi_take_table.PitchQuantize)
                            local new_pitch = hash_pitch + rnd_pitch + oi_take_table.pitch -- (hash_item pitch + random hash_item_pitch) + random pitch + original pitch 
                            reaper.SetMediaItemTakeInfo_Value(new_take, 'D_PITCH', new_pitch)
                            -- Rate
                            local rnd_rate = RandomNumberFloatQuantized(oi_take_table.PlayRateRandomMin,oi_take_table.PlayRateRandomMax, true, oi_take_table.PlayRateQuantize)
                            local new_rate = hash_rate * rnd_rate * oi_take_table.rate -- (hash_item rate * random hash_item_rate) * random pitch + original pitch 
                            reaper.SetMediaItemTakeInfo_Value(new_take, 'D_PLAYRATE', new_rate)
                            -- Length
                            new_length = new_item_len / (new_rate/oi_take_table.rate)
                            reaper.SetMediaItemInfo_Value(new_item, 'D_LENGTH', new_length)
                        else -- Note items
                            -- Length
                            new_length = new_item_len / hash_rate
                            reaper.SetMediaItemInfo_Value(new_item, 'D_LENGTH', new_length)
                        end
                        -- Delete Item that end before the start the hash item
                        if new_pos + new_length <= hash_item_table.pos then
                            reaper.DeleteTrackMediaItem( oi_settings[item].track, new_item)
                            goto continue
                        end
                        -- Selected 
                        if oi_settings[item].selected == 1 then
                            reaper.SetMediaItemInfo_Value(new_item, 'B_UISEL', 0)
                        end
                        -- Apply ExtState
                        SetItemExtState(new_item,Ext_Name,LoopItemExt,'true')
                        -- Crop item to the end of the hash item
                        if (new_pos + new_length) > hash_item_table.fim then
                            CropItem(new_item, nil, hash_item_table.fim)
                        end
                        if new_pos < hash_item_table.pos then
                            CropItem(new_item, hash_item_table.pos , nil)
                        end
                        ::continue::
                    end
                end

                if Settings.PasteAutomation then
                    for track in enumTracks(proj) do
                        for env in enumTrackEnvelopes(track) do
                            local add_list = {} -- table with containing all information about the ai that needs to be added in the end
                            --add_list:
                                --i:
                                    --o_idx: n --original idx
                                    --pos:  n
                                    --len:  n
                                    --end:  n
                                    --rate: n
                                    --offset:n
                                    --pool:n
                                    --baseline:n
                                    --loop:n
                                    --amp:n
                            local ai_list = GetAutomationItemsInRange(env, region_table.region_start,region_table.region_end,false,false) -- Need to crop to region
                            for k, ai_idx in ipairs(ai_list) do
                                -- Get information from source
                                local source_info = GetOptionsAutomationItemInATable(env,ai_idx)
                                source_info.pos = reaper.GetSetAutomationItemInfo(env, ai_idx, 'D_POSITION', 0, false)
                                source_info.len = reaper.GetSetAutomationItemInfo(env, ai_idx, 'D_LENGTH', 0, false)
                                source_info.fim = source_info.pos + source_info.len
                                source_info.offset = reaper.GetSetAutomationItemInfo(env, ai_idx, 'D_STARTOFFS', 0, false)
                                source_info.rate = reaper.GetSetAutomationItemInfo(env, ai_idx, 'D_PLAYRATE', 0, false)

                                -- Define new values
                                -- Position
                                local dif = source_info.pos - region_table.region_start
                                if dif < 0 then -- if item start before the region needs to crop (add offset reduce length) and set the dif to 0 and position to region_start
                                    source_info.pos = region_table.region_start
                                    source_info.offset = source_info.offset - (dif*source_info.rate)
                                    source_info.len = source_info.len + dif
                                    dif = 0
                                end
                                dif = dif / hash_rate
                                local new_pos = pasting_pos + dif 
                                -- Length
                                if source_info.len + source_info.pos > region_table.region_end then -- if item is over the region crop it (reduce length)
                                    source_info.len = region_table.region_end - source_info.pos
                                end
                                local new_len = source_info.len
                                -- Rate
                                local new_rate = source_info.rate * hash_rate
                                new_len = new_len / (new_rate/source_info.rate)
                                -- Crop end
                                if new_pos + new_len > hash_item_table.fim then
                                    new_len = hash_item_table.fim - new_pos                           
                                end

                                add_list[k] = {
                                    pool = reaper.GetSetAutomationItemInfo(env, ai_idx, 'D_POOL_ID', 0, false),
                                    loop = reaper.GetSetAutomationItemInfo(env, ai_idx, 'D_LOOPSRC', 0, false),
                                    amp = reaper.GetSetAutomationItemInfo(env, ai_idx, 'D_AMPLITUDE', 0, false),
                                    baseline = reaper.GetSetAutomationItemInfo(env, ai_idx, 'D_BASELINE', 0, false),
                                    pos = new_pos,
                                    len = new_len,
                                    rate = new_rate,
                                    offset = source_info.offset
                                }
                            end

                            for k, ai_info in ipairs(add_list) do -- needs two loops as this will change ai_idxes
                                local idx = reaper.InsertAutomationItem(env, ai_info.pool, ai_info.pos, ai_info.len)
                                reaper.GetSetAutomationItemInfo( env, idx, 'D_STARTOFFS', ai_info.offset, true )
                                reaper.GetSetAutomationItemInfo( env, idx, 'D_PLAYRATE', ai_info.rate, true )
                                                                
                                
                                reaper.GetSetAutomationItemInfo( env, idx, 'D_LOOPSRC', ai_info.loop, true )                               
                                reaper.GetSetAutomationItemInfo( env, idx, 'D_AMPLITUDE', ai_info.amp, true )                               
                                reaper.GetSetAutomationItemInfo( env, idx, 'D_BASELINE', ai_info.baseline, true )
                            end
                        end
                    end
                end
                -- Update pasting_pos
                pasting_pos = pasting_pos + paste_len
                -- Secure While Loop Ceiling
                pasting_idx = pasting_idx + 1
                if pasting_idx >= safe_paste_maxvalue then 
                    local ret = reaper.ShowMessageBox('Its Gonna Phase have been pasting for quite some time, continue pasting?', 'Its Gonna Phase', 3)
                    if ret == 6 then -- YES
                        safe_paste_maxvalue = safe_paste_maxvalue * 2
                    else
                        break
                    end
                end
            end
            ::continue2:: 
        end 
    end
    
    reaper.UpdateArrange()
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock2(proj, 'Apply Phasing', -1)
    return true
end

-- Logic Scheme
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
                    

--[[
    loop_items_list:
        item*:
            len: n
            pos: n
            randomize: b
            randomize_paste: b
            fim: n
            region:
                region_start: n
                region_end: n
                region_id: n
            takes:
                n:
                    take: take*
                    pitch: n
                    rate: n
                    chance: n
                    rate_min: n
                    rate_max: n
                    rate_q: n
                    pitch_min: n
                    pitch_max: n
                    pitch_q: n
]]
