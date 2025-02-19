Clouds = Clouds or {}
Clouds.ReRoll ={}

local ext_reroll = 'reroll'
local function get_items_table(proj)
    local items = {}
    local no_cloud = false
    for item in DL.enum.SelectedMediaItem(proj) do
        local bol, ext = DL.item.GetExtState(item, EXT_NAME, ext_reroll)
        if ext ~= '' then
            local info = DL.serialize.stringToTable(ext)
            if info then
                local cloud = reaper.BR_GetMediaItemByGUID(proj, info.cloud)
                if reaper.ValidatePtr2(proj, cloud, 'MediaItem*') then 
                    info.cloud = cloud
                    items[cloud] = items[cloud] or {}
                    table.insert(items[cloud], {item = item, info = info})
                else
                    no_cloud = true 
                end
            end
        end
    end

    local total = 0
    for cloud, t_items in pairs(items) do
        -- Sort Items
        total = total + #t_items
        table.sort(t_items, function (a,b)
            return a.info.idx < b.info.idx
        end)
    end
    return items, no_cloud, total
end

local function check_cloud(proj, cloud)
    ---@type boolean, string|table|nil
    local _, ct = DL.item.GetExtState(cloud, EXT_NAME, 'settings')
    ct = DL.serialize.stringToTable(ct)
    -- Guids to Items/Tracks
    ct = Clouds.convert.ConvertGUIDToUserDataRecursive(proj, ct)
    -- Check if some item/track wasnt found (remove it from the table)
    for k, v in DL.t.ipairs_reverse(ct.items) do
        if not reaper.ValidatePtr2(proj, v.item, 'MediaItem*') then
            table.remove(ct.items,k)
        end
    end

    for k, v in DL.t.ipairs_reverse(ct.tracks) do -- dont need to check self
        if not reaper.ValidatePtr2(proj, v.track, 'MediaTrack*') then
            table.remove(ct.tracks,k)
        end
    end
    -- Check if it has Clouds FX
    Clouds.Item.EnsureFX(cloud)

    return ct
end

local function get_clouds(proj, items)
    local clouds = {}
    for cloud, t_items in pairs(items) do
        -- Get cloud necessary info
        --- If needed, get cloud information
        local ct = check_cloud(proj, cloud)
        if not clouds[cloud] then
            -- Info to be used in the ReRoll: 
            ct.cloud = cloud
            ct.take = reaper.GetActiveTake(cloud)
            ct.rate = reaper.GetMediaItemTakeInfo_Value(ct.take, 'D_PLAYRATE')
            ct.len = reaper.GetMediaItemInfo_Value(cloud, 'D_LENGTH')
            ct.start = reaper.GetMediaItemInfo_Value(cloud, 'D_POSITION')
            clouds[cloud] = ct
        else
            ct = clouds[cloud]
        end
    end
    return clouds
end

function Clouds.ReRoll.ReRoll(proj, seed, reroll_type)
    local items, no_cloud, total = get_items_table(proj)
    local clouds = get_clouds(proj, items)
    
    if items.total == 0 then return end
    
    ------- Apply the reroll! 
    reaper.Undo_BeginBlock2(proj)
    reaper.PreventUIRefresh(1)
    local coroutine_time = reaper.time_precise()
    -- Set general Random Seed 
    local seed = seed ~= 0 and math.randomseed(seed,0) or math.randomseed(math.random(1,100000),0)
    -- Redirect to the right Reroll
    if reroll_type.type == 'Position' then
        Clouds.ReRoll.Position(items, clouds, total, coroutine_time)
    end
    -- End it
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock2(proj, 'Clouds: ReRoll '..reroll_type.name, -1)

    if no_cloud then
        reaper.ShowMessageBox('Some items are missing their cloud parent. ', 'Clouds - Error', 0)
    end

    return true, {done = #items, total = #items, seed = seed}
end

function Clouds.ReRoll.Position(items, clouds, total, coroutine_time)
    for cloud, t_items in pairs(items) do
        for k, t in ipairs(t_items) do
            -- coroutine
            --coroutine_check = coroutine_check + 1
            if ((reaper.time_precise() - coroutine_time) > UPDATE_FREQ.time) then -- (coroutine_check >= UPDATE_FREQ.items) 
                reaper.PreventUIRefresh(-1)
                coroutine.yield(false, {done = k-1, total = total})
    
                reaper.PreventUIRefresh(1)
                coroutine_time = reaper.time_precise()
            end
    
            local item = t.item
            local reroll = t.info
            local o_pos = reroll.pos
            local ct = clouds[cloud]
    
            --Randomize (dust)
            -- Get fixed values of freq and dust
            local freq = ct.density.density.val
            local dust = ct.density.random.val -- dust = 1 means that a position will be randomize in the range of one period. half earlier half later.
            -- Get envelopes
            local density_env = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.density, false)
            local dust_env = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.dust, false)
            --- Calculate period
            local new_freq = freq
            if ct.density.density.envelope and density_env then
                -- Get env value
                local retval, env_val = reaper.Envelope_Evaluate(density_env, o_pos * ct.rate, 0, 0)
                new_freq = DL.num.MapRange(env_val * freq, 0, freq, ct.density.density.env_min, freq) 
            end
            local period = 1 / new_freq
            --- Calculate dust
            local new_dust = dust 
            if ct.density.random.envelope and dust_env then
                local retval, env_val = reaper.Envelope_Evaluate(dust_env, o_pos * ct.rate, 0, 0)
                new_dust = env_val * dust
            end
            --- Calculate new position
            local new_pos = o_pos 
            local range = period * new_dust
            local random = (math.random() * range) - (range/2)
            new_pos = new_pos + random
            -- reflect item at borders
            new_pos = new_pos % (2 * ct.len)
            if new_pos > ct.len then
                new_pos = ct.len - (new_pos - ct.len)
            end
    
            new_pos = new_pos + ct.start
    
            -- Quantize
            if ct.density.quantize then
                new_pos = reaper.BR_GetClosestGridDivision(new_pos)
            end
    
            reaper.SetMediaItemInfo_Value(item, 'D_POSITION', new_pos)
        end 
    end
end



