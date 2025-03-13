--@noindex
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
                    table.insert(items[cloud], {item = item, info = info, ext = ext, take = reaper.GetActiveTake(item)})
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
    ct = Clouds.convert.ConvertGUIDtoUserData_Manually(proj, ct)
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

local function corotine_check(coroutine_time, k, total)
        -- coroutine
    --coroutine_check = coroutine_check + 1
    if ((reaper.time_precise() - coroutine_time) > UPDATE_FREQ.time) then -- (coroutine_check >= UPDATE_FREQ.items) 
        reaper.PreventUIRefresh(-1)
        coroutine.yield(false, {done = k-1, total = total})

        reaper.PreventUIRefresh(1)
        coroutine_time = reaper.time_precise()
    end
    return coroutine_time
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
    elseif reroll_type.type == 'Items' then
        Clouds.ReRoll.Items(items, clouds, total, coroutine_time)
    elseif reroll_type.type == 'Volume' then
        Clouds.ReRoll.Volume(items, clouds, total, coroutine_time)
    elseif reroll_type.type == 'Pan' then
        Clouds.ReRoll.Pan(items, clouds, total, coroutine_time)
    elseif reroll_type.type == 'Pitch' then
        Clouds.ReRoll.Pitch(items, clouds, total, coroutine_time)
    elseif reroll_type.type == 'Rate' then
        Clouds.ReRoll.Rate(items, clouds, total, coroutine_time)
    elseif reroll_type.type == 'Playrate' then
        Clouds.ReRoll.Playrate(items, clouds, total, coroutine_time)
    elseif reroll_type.type == 'Reverse' then
        Clouds.ReRoll.Reverse(items, clouds, total, coroutine_time)
    elseif reroll_type.type == 'Track' then
        Clouds.ReRoll.Track(items, clouds, total, coroutine_time)
    elseif reroll_type.type == 'Grains: Position' then
        Clouds.ReRoll.Grains_Pos(items, clouds, total, coroutine_time)
    elseif reroll_type.type == 'Grains: Size' then
        Clouds.ReRoll.Grains_Size(items, clouds, total, coroutine_time)
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
        local ct = clouds[cloud]
        -- Get fixed values of freq and dust
        local freq = ct.density.density.val
        local dust = ct.density.random.val -- dust = 1 means that a position will be randomize in the range of one period. half earlier half later.
        -- Get envelopes
        local density_env = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.density, false)
        local dust_env = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.dust, false)
        for k, t in ipairs(t_items) do
            coroutine_time = corotine_check(coroutine_time, k, total)
    
            local item = t.item
            local reroll = t.info
            local o_pos = reroll.pos
    
            --Randomize (dust)

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

function Clouds.ReRoll.Volume(items, clouds, total, coroutine_time)
    for cloud, t_items in pairs(items) do
        local ct = clouds[cloud]
        -- Get envelopes
        local envs = {envelopes = {}, randomization = {}}
        envs.randomization.vol = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.randomization.vol, false)
        envs.randomization.c_vol = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.randomization.c_vol, false)

        envs.envelopes.vol = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.envelopes.vol, false)
        envs.envelopes.c_vol = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.envelopes.c_vol, false)
        for k, t in ipairs(t_items) do
            coroutine_time = corotine_check(coroutine_time, k, total)
    
            local item = t.item
            local o_item_t = {vol = t.info.original_values.vol}
            local original_vol = DL.num.LinearTodB(o_item_t.vol)
            local new_values = {vol  = original_vol}
            local pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION') - ct.start

            --- Envelopes
            if ct.envelopes.vol.on and envs.envelopes.vol then
                local cur_chance = ct.envelopes.vol.chance.val 
                if ct.envelopes.vol.chance.env and envs.envelopes.c_vol then
                    local retval, env_val =  reaper.Envelope_Evaluate(envs.envelopes.c_vol, pos * ct.rate, 0, 0)
                    cur_chance = env_val * cur_chance 
                end
                local rnd = math.random(0,99)
                if rnd < cur_chance then
                    local min, max = ct.envelopes.vol.min, ct.envelopes.vol.max -- makes it always above 0, numbers between 0 and 1 are reducing the size
                    local retval, env_val = reaper.Envelope_Evaluate(envs.envelopes.vol, pos * ct.rate, 0, 0) 

                    min, max = DL.num.dBToLinear(min), DL.num.dBToLinear(max)
                    local new_vol = ((max - min) * env_val) + min 
                    new_vol = DL.num.LinearTodB(new_vol)
                    new_values.vol = (new_values.vol or 0) + new_vol
                end
            end
            --- Randomization
            if ct.randomization.vol.on then
                -- chance
                local cur_chance = ct.randomization.vol.chance.val 
                if ct.randomization.vol.chance.env and envs.randomization.c_vol then
                    local retval, env_val =  reaper.Envelope_Evaluate(envs.randomization.c_vol, pos * ct.rate, 0, 0)
                    cur_chance = env_val * cur_chance                           
                end
                local rnd = math.random(0,99)
                if rnd < cur_chance then 
                    local min, max = ct.randomization.vol.min, ct.randomization.vol.max -- makes it always above 0, numbers between 0 and 1 are reducing the size
                    if ct.randomization.vol.envelope and envs.randomization.vol then
                        local retval, env_val = reaper.Envelope_Evaluate(envs.randomization.vol, pos * ct.rate, 0, 0) 
                        min, max = min * env_val, max * env_val 
                    end  
                    min, max = min + CONSTRAINS.db_minmax, max + CONSTRAINS.db_minmax
                    local new_vol = DL.num.RandomFloatExp(min, max, 10)
                    new_vol = new_vol - CONSTRAINS.db_minmax
                    new_values.vol = (new_values.vol or 0) + new_vol
                end
                
            end
            -- Apply
            if new_values.vol then
                local result_l = DL.num.dBToLinear(new_values.vol)
                reaper.SetMediaItemInfo_Value(item, 'D_VOL', result_l)
                local ext = t.ext
                local new_ext = DL.serialize.stringToTable(ext)
                -- Set original_value related to the orignal source item
                if new_ext then
                    new_ext.parameters.vol = new_values.vol - original_vol
                    new_ext = DL.serialize.tableToString(new_ext)
                    DL.item.SetExtState(item, EXT_NAME, ext_reroll, new_ext)
                end
            end
        end 
    end
end

function Clouds.ReRoll.Pan(items, clouds, total, coroutine_time)
    for cloud, t_items in pairs(items) do
        local ct = clouds[cloud]
        -- Get envelopes
        local envs = {envelopes = {}, randomization = {}}
        envs.randomization.pan = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.randomization.pan, false)
        envs.randomization.c_pan = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.randomization.c_pan, false)

        envs.envelopes.pan = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.envelopes.pan, false)
        envs.envelopes.c_pan = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.envelopes.c_pan, false)
        for k, t in ipairs(t_items) do
            coroutine_time = corotine_check(coroutine_time, k, total)
    
            local item = t.item
            local take = t.take
            local pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION') - ct.start
            local o_item_t = {vol = t.info.original_values.pan}
            local new_values = {pan = o_item_t.pan}

            --- Envelopes
            if ct.envelopes.pan.on and envs.envelopes.pan then
                local cur_chance = ct.envelopes.pan.chance.val 
                if ct.envelopes.pan.chance.env and envs.envelopes.c_pan then
                    local retval, env_val =  reaper.Envelope_Evaluate(envs.envelopes.c_pan, pos * ct.rate, 0, 0)
                    cur_chance = env_val * cur_chance 
                end
                local rnd = math.random(0,99)
                if rnd < cur_chance then
                    local min, max = ct.envelopes.pan.min, ct.envelopes.pan.max -- makes it always above 0, numbers between 0 and 1 are reducing the size
                    local retval, env_val = reaper.Envelope_Evaluate(envs.envelopes.pan, pos * ct.rate, 0, 0) 

                    local new_pan = ((max - min) * env_val) + min 
                    new_values.pan = (new_values.pan or 0) + new_pan
                end
            end
            --- Randomization
            if ct.randomization.pan.on then
                -- chance
                local cur_chance = ct.randomization.pan.chance.val 
                if ct.randomization.pan.chance.env and envs.randomization.c_pan then
                    local retval, env_val =  reaper.Envelope_Evaluate(envs.randomization.c_pan, pos * ct.rate, 0, 0)
                    cur_chance = env_val * cur_chance                           
                end
                local rnd = math.random(0,99)
                if rnd < cur_chance then 
                    local min, max = ct.randomization.pan.min, ct.randomization.pan.max -- makes it always above 0, numbers between 0 and 1 are reducing the size
                    if ct.randomization.pan.envelope and envs.randomization.pan then
                        local retval, env_val = reaper.Envelope_Evaluate(envs.randomization.pan, pos * ct.rate, 0, 0) 
                        min, max = min * env_val, max * env_val 
                    end    
                    local new_pan = DL.num.RandomFloat(min, max, true)
                    new_values.pan = (new_values.pan or 0) + new_pan
                    new_values.pan = DL.num.Clamp(new_values.pan, -1, 1)
                end
            end
            -- Apply
            if new_values.pan then
                reaper.SetMediaItemTakeInfo_Value(take, 'D_PAN', new_values.pan)
                local ext = t.ext
                local new_ext = DL.serialize.stringToTable(ext)
                -- Set original_value related to the orignal source item
                if new_ext then
                    new_ext.parameters.pan = new_values.pan 
                    new_ext = DL.serialize.tableToString(new_ext)
                    DL.item.SetExtState(item, EXT_NAME, ext_reroll, new_ext)
                end
            end
        end 
    end
end

function Clouds.ReRoll.Reverse(items, clouds, total, coroutine_time)
    local reverserd_items = {}
    for cloud, t_items in pairs(items) do
        local ct = clouds[cloud]
        -- Get envelopes
        local envs = {envelopes = {}, randomization = {}}
        envs.randomization.reverse = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.randomization.reverse, false)

        for k, t in ipairs(t_items) do
            coroutine_time = corotine_check(coroutine_time, k, total)
    
            local item = t.item
            local take = t.take
            local pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION') - ct.start
            local o_item_t = {vol = t.info.original_values.pan}
            local new_values = {pan = o_item_t.pan}

            --- Randomization
            if ct.randomization.reverse.on then
                local pcm = reaper.GetMediaItemTake_Source(take )
                local retval, offs, len, is_rev = reaper.PCM_Source_GetSectionInfo( pcm ) -- current item source is reversed?
                local is_src_rev = t.info.original_values.reverse
                
                local random = DL.num.RandomFloat(0, 100, true)
                local chance = ct.randomization.reverse.val
                if ct.randomization.reverse.envelope and envs.randomization.reverse then
                    local retval, env_val = reaper.Envelope_Evaluate(envs.randomization.reverse, pos * cloud.rate, 0, 0)
                    chance = chance * env_val
                end
                if (random < chance and is_rev == is_src_rev) or (random >= chance and is_rev ~= is_src_rev) then -- oposite than source
                    reverserd_items[#reverserd_items+1] = item

                    local ext = t.ext
                    local new_ext = DL.serialize.stringToTable(ext)
                    -- Set original_value related to the orignal source item
                    if new_ext then
                        new_ext.parameters.reverse = not new_ext.parameters.reverse 
                        new_ext = DL.serialize.tableToString(new_ext)
                        DL.item.SetExtState(item, EXT_NAME, ext_reroll, new_ext)
                    end
                end
            end
        end 
    end
    -- Reverse Items: 
    if #reverserd_items > 0 then
        -- Save selection
        local sel_items = DL.item.CreateSelectedItemsTable(Proj)

        -- Reverse
        reaper.SelectAllMediaItems(Proj, false)
        for index, item in ipairs(reverserd_items) do
            reaper.SetMediaItemSelected(item, true)
        end
        reaper.Main_OnCommand(41051, 0) -- Item properties: Toggle take reverse

        -- Selects back
        reaper.SelectAllMediaItems(Proj, false)
        for i, item in ipairs(sel_items) do
            if reaper.ValidatePtr2(Proj, item, 'MediaItem*') then
                reaper.SetMediaItemSelected(item, true)
            end
        end
    end
end

function Clouds.ReRoll.Playrate(items, clouds, total, coroutine_time)
    for cloud, t_items in pairs(items) do
        local ct = clouds[cloud]
        -- Get envelopes
        local envs = {envelopes = {}, randomization = {}}
        envs.randomization.stretch = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.randomization.stretch, false)
        envs.randomization.c_stretch = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.randomization.c_stretch, false)

        envs.envelopes.stretch = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.envelopes.stretch, false)
        envs.envelopes.c_stretch = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.envelopes.c_stretch, false)
        for k, t in ipairs(t_items) do
            coroutine_time = corotine_check(coroutine_time, k, total)
    
            local item = t.item
            local take = t.take
            local pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION') - ct.start
            local o_item_t = {rate = t.info.original_values.rate}
            local new_values = {rate  = o_item_t.rate}
            
            --- Envelopes
            if ct.envelopes.stretch.on and envs.envelopes.stretch then
                local cur_chance = ct.envelopes.stretch.chance.val 
                if ct.envelopes.stretch.chance.env and envs.envelopes.c_stretch then
                    local retval, env_val =  reaper.Envelope_Evaluate(envs.envelopes.c_stretch , pos * ct.rate, 0, 0)
                    cur_chance = env_val * cur_chance 
                end
                local rnd = math.random(0,99)
                if rnd < cur_chance then
                    local min, max = ct.envelopes.stretch.min, ct.envelopes.stretch.max -- makes it always above 0, numbers between 0 and 1 are reducing the size
                    local retval, env_val = reaper.Envelope_Evaluate(envs.envelopes.stretch, pos * ct.rate, 0, 0) 
                    local new_val = min * ((max / min) ^ env_val) 
                    new_values.rate = (new_values.rate or 1) * new_val
                    --new_values.rate = (new_values.rate or o_item_t.rate) * new_val
                    --new_values.length = (new_values.length or o_item_t.length) / new_val
                end
            end
            -- Random
            if ct.randomization.stretch.on then
                -- chance
                local cur_chance = ct.randomization.stretch.chance.val 
                if ct.randomization.stretch.chance.env and envs.randomization.c_stretch then
                    local retval, env_val =  reaper.Envelope_Evaluate(envs.randomization.c_stretch, pos * ct.rate, 0, 0)
                    cur_chance = env_val * cur_chance                           
                end
                local rnd = math.random(0,99)
                if rnd < cur_chance then 
                    local min, max = ct.randomization.stretch.min, ct.randomization.stretch.max -- makes it always above 0, numbers between 0 and 1 are reducing the size
                    if ct.randomization.stretch.envelope and envs.randomization.stretch then
                        local retval, env_val = reaper.Envelope_Evaluate(envs.randomization.stretch, pos * ct.rate, 0, 0) 
                        min, max = min ^ env_val, max ^ env_val 
                    end    
                    local new_val = DL.num.RandomFloatExp(min, max, 2)
                    new_values.rate = (new_values.rate or 1) * new_val
                    --new_values.rate = (new_values.rate or o_item_t.rate) * new_val
                    --new_values.length = (new_values.length or o_item_t.length) / new_val
                end
            end
            -- Apply
            if new_values.rate then
                local ratio = (new_values.rate / reaper.GetMediaItemTakeInfo_Value(take, 'D_PLAYRATE'))
                new_values.length = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH') / ratio
                reaper.SetMediaItemTakeInfo_Value(take, 'D_PLAYRATE', new_values.rate)
                reaper.SetMediaItemInfo_Value(item, 'D_LENGTH', new_values.length)
                -- Adjust fades
                local fade_in = reaper.GetMediaItemInfo_Value(item, 'D_FADEINLEN')
                reaper.SetMediaItemInfo_Value(item, 'D_FADEINLEN', fade_in / ratio )
                local fade_out = reaper.GetMediaItemInfo_Value(item, 'D_FADEOUTLEN')
                reaper.SetMediaItemInfo_Value(item, 'D_FADEOUTLEN', fade_out / ratio )

                local ext = t.ext
                local new_ext = DL.serialize.stringToTable(ext)
                -- Set original_value related to the orignal source item
                if new_ext then
                    new_ext.parameters.rate = new_values.rate / o_item_t.rate
                    new_ext = DL.serialize.tableToString(new_ext)
                    DL.item.SetExtState(item, EXT_NAME, ext_reroll, new_ext)
                end
            end
        end 
    end
end

function Clouds.ReRoll.Pitch(items, clouds, total, coroutine_time)
    for cloud, t_items in pairs(items) do
        local ct = clouds[cloud]
        -- Get MIDI Notes
        local notes = {}
        local retval, notes_cnt = reaper.MIDI_CountEvts(ct.take) 
        if notes_cnt > 0 then
            for selected, muted, startppqpos, endppqpos, chan, pitch, vel, noteidx in DL.enum.MIDINotes(ct.take) do
                if not muted then
                    notes[#notes+1] = {
                        start = (reaper.MIDI_GetProjTimeFromPPQPos(ct.take, startppqpos) - ct.start), 
                        fim = (reaper.MIDI_GetProjTimeFromPPQPos(ct.take, endppqpos) - ct.start), 
                        pitch = pitch,
                        vel = vel
                    }
                end
                -- body
            end
        end
        -- Get envelopes
        local envs = {envelopes = {}, randomization = {}}
        envs.randomization.pitch = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.randomization.pitch, false)
        envs.randomization.c_pitch = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.randomization.c_pitch, false)

        envs.envelopes.pitch = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.envelopes.pitch, false)
        envs.envelopes.c_pitch = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.envelopes.c_pitch, false)
        for k, t in ipairs(t_items) do
            coroutine_time = corotine_check(coroutine_time, k, total)
    
            local item = t.item
            local take = t.take
            local o_item_t = {pitch = t.info.original_values.pitch}
            local new_values = {pitch = o_item_t.pitch}
            local pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION') - ct.start

            --- Envelopes
            if ct.envelopes.pitch.on and envs.envelopes.pitch then
                local cur_chance = ct.envelopes.pitch.chance.val 
                if ct.envelopes.pitch.chance.env and envs.envelopes.c_pitch then
                    local retval, env_val =  reaper.Envelope_Evaluate(envs.envelopes.c_pitch , pos * ct.rate, 0, 0)
                    cur_chance = env_val * cur_chance 
                end
                local rnd = math.random(0,99)
                if rnd < cur_chance then
                    local min, max = ct.envelopes.pitch.min, ct.envelopes.pitch.max -- makes it always above 0, numbers between 0 and 1 are reducing the size
                    local retval, env_val = reaper.Envelope_Evaluate(envs.envelopes.pitch, pos * ct.rate, 0, 0) 
                    local new_pitch = ((max - min) * env_val) + min 
                    new_pitch = ct.envelopes.pitch.quantize and DL.num.Quantize(new_pitch, ct.envelopes.pitch.quantize/100) or new_pitch
                    new_values.pitch = (new_values.pitch or 0) + new_pitch
                end
            end
            -- Randomization
            if ct.randomization.pitch.on then
                -- chance
                local cur_chance = ct.randomization.pitch.chance.val 
                if ct.randomization.pitch.chance.env and envs.randomization.c_pitch then
                    local retval, env_val =  reaper.Envelope_Evaluate(envs.randomization.c_pitch, pos * ct.rate, 0, 0)
                    cur_chance = env_val * cur_chance                           
                end
                local rnd = math.random(0,99)
                if rnd < cur_chance then 
                    local min, max = ct.randomization.pitch.min, ct.randomization.pitch.max -- makes it always above 0, numbers between 0 and 1 are reducing the size
                    if ct.randomization.pitch.envelope and envs.randomization.pitch then
                        local retval, env_val = reaper.Envelope_Evaluate(envs.randomization.pitch, pos * ct.rate, 0, 0) 
                        min, max = min * env_val, max * env_val 
                    end    
                    local new_pitch = ct.randomization.pitch.quantize == 0 and DL.num.RandomFloat(min, max, true) or DL.num.RandomFloatQuantized(min, max, true, ct.randomization.pitch.quantize/100)
                    new_values.pitch = (new_values.pitch or 0) + new_pitch
                    --new_pitch = new_pitch + reaper.GetMediaItemTakeInfo_Value(new_item.take, 'D_PITCH')
                    --reaper.SetMediaItemTakeInfo_Value(new_item.take, 'D_PITCH', new_pitch)
                end
            end
            -- MIDI Notes
            if (not ct.midi_notes.is_synth) and #notes > 0 then
                local held = {}
                local idx = 1
                for i = 1, #notes do
                    local note = notes[idx]
                    if note.start > pos then --no more notes in this position
                        break
                    elseif note.fim < pos then -- this note will never be reached again, delete it
                        table.remove(notes, idx)
                    else 
                        held[#held+1] = note
                        idx = idx + 1
                    end                        
                end
                
                if #held > 0 then
                    local idx, sel_note = DL.t.RandomValueWithWeight(held, 'vel')
                    local new_pitch = (sel_note.pitch - ct.midi_notes.center) * (12/ct.midi_notes.EDO)  -- Alterar aqui para ter edo
                    new_values.pitch = (new_values.pitch or 0) + new_pitch
                end
            end
            -- Apply
            if new_values.pitch then
                reaper.SetMediaItemTakeInfo_Value(take, 'D_PITCH', new_values.pitch)
                local ext = t.ext
                local new_ext = DL.serialize.stringToTable(ext)
                -- Set original_value related to the orignal source item
                if new_ext then
                    new_ext.parameters.pitch = new_values.pitch - o_item_t.pitch
                    new_ext = DL.serialize.tableToString(new_ext)
                    DL.item.SetExtState(item, EXT_NAME, ext_reroll, new_ext)
                end
            end
        end 
    end
end

function Clouds.ReRoll.Items(items, clouds, total, coroutine_time)
    local reverse_items = {}
    local source_items_info = {}
    local no_items = false
    local is_proj_mix = reaper.SNM_GetIntConfigVar('itemmixflag',100) == 1 --mix behavior 
    for cloud, t_items in pairs(items) do
        local ct = clouds[cloud]
        clouds[cloud].guid = reaper.BR_GetMediaItemGUID(cloud)
        for k, t in ipairs(t_items) do
            coroutine_time = corotine_check(coroutine_time, k, total)
    
            local item = t.item
            local track = reaper.GetMediaItem_Track(t.item)
            local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local reroll = t.info
            local ext = t.ext

            -- Copy the new item
            local item_k, new_item_t = DL.t.RandomValueWithWeight(ct.items, 'chance') -- test if this work if I delete all items before rerolling
            if new_item_t then
                local source = new_item_t.item
                if not source_items_info[source] then
                    source_items_info[source] = {}
                    source_items_info[source].take = reaper.GetActiveTake(source)
                    source_items_info[source].vol = reaper.GetMediaItemInfo_Value(source, 'D_VOL')
                    source_items_info[source].length = reaper.GetMediaItemInfo_Value(source, 'D_LENGTH')
                    source_items_info[source].pitch = reaper.GetMediaItemTakeInfo_Value(source_items_info[source].take, 'D_PITCH')
                    source_items_info[source].offset = reaper.GetMediaItemTakeInfo_Value(source_items_info[source].take, 'D_STARTOFFS')
                    source_items_info[source].rate = reaper.GetMediaItemTakeInfo_Value(source_items_info[source].take, 'D_PLAYRATE')  -- Need for: grains
                    local pcm = reaper.GetMediaItemTake_Source( source_items_info[source].take)
                    local retval, offs, len, rev = reaper.PCM_Source_GetSectionInfo( pcm )
                    source_items_info[source].reverse = rev  -- Need for: grains
                    source_items_info[source].mix = DL.item.GetMixBehavior(source)
                end
                local new_item, new_take
                new_item = new_item_t.item
                new_item = DL.item.CopyToTrack(new_item, track, pos, true, false)
                new_take = reaper.GetActiveTake(new_item)
                
                -- Volume
                if reroll.parameters.vol then
                    source_items_info[source].vol = source_items_info[source].vol or reaper.GetMediaItemInfo_Value(source, 'D_VOL')
                    local cur = DL.num.LinearTodB(source_items_info[source].vol) --TODO CHANGE TO GET ONLY ONCE
                    local result_l = DL.num.dBToLinear(reroll.parameters.vol + cur)
                    reaper.SetMediaItemInfo_Value(new_item, 'D_VOL', result_l)
                end
                -- Pan
                if reroll.parameters.pan then
                    reaper.SetMediaItemTakeInfo_Value(new_take, 'D_PAN', reroll.parameters.pan)
                end
                -- Pitch
                if reroll.parameters.pitch then
                    source_items_info[source].pitch = source_items_info[source].pitch or reaper.GetMediaItemTakeInfo_Value(source_items_info[source].take, 'D_PITCH')
                    local new_pitch = source_items_info[source].pitch + reroll.parameters.pitch
                    reaper.SetMediaItemTakeInfo_Value(new_take, 'D_PITCH', new_pitch)
                end
                -- Rate
                if reroll.parameters.rate then
                    source_items_info[source].rate = source_items_info[source].rate or reaper.GetMediaItemTakeInfo_Value(source_items_info[source].take, 'D_PLAYRATE')
                    local new_rate = source_items_info[source].rate * reroll.parameters.rate
                    reaper.SetMediaItemTakeInfo_Value(new_take, 'D_PLAYRATE', new_rate)
                end
                -- Length
                local new_length 
                if reroll.grains.size or reroll.parameters.rate then -- Set by : Grains, Playrate
                    source_items_info[source].length = source_items_info[source].length or reaper.GetMediaItemInfo_Value(source, 'D_LENGTH')
                    new_length = (reroll.grains.size or source_items_info[source].length) / (reroll.parameters.rate or 1)
                    reaper.SetMediaItemInfo_Value(new_item, 'D_LENGTH', new_length)                
                end
                -- Offset
                if reroll.grains.offset then -- Set by : Grains
                    -- reroll.grains.offset is in %
                    source_items_info[source].rate = source_items_info[source].rate or reaper.GetMediaItemTakeInfo_Value(source_items_info[source].take, 'D_PLAYRATE')
                    source_items_info[source].length = source_items_info[source].length or reaper.GetMediaItemInfo_Value(source, 'D_LENGTH')
                    source_items_info[source].offset = source_items_info[source].offset or reaper.GetMediaItemTakeInfo_Value( source_items_info[source].take, 'D_STARTOFFS')
                    local new_offset = source_items_info[source].offset + ((source_items_info[source].length * source_items_info[source].rate ) * reroll.grains.offset)
                    reaper.SetMediaItemTakeInfo_Value(new_take, 'D_STARTOFFS', new_offset)
                end
                -- Grain Fade
                if reroll.grains.fade then
                    source_items_info[source].length = source_items_info[source].length or reaper.GetMediaItemInfo_Value(source, 'D_LENGTH')
                    local item_len = new_length or source_items_info[source].length
                    local fade_len = item_len * (ct.grains.fade.val/200)
                    reaper.SetMediaItemInfo_Value(new_item, 'D_FADEINLEN', fade_len)
                    reaper.SetMediaItemInfo_Value(new_item, 'D_FADEOUTLEN', fade_len)
                end
                -- Reverse
                if reroll.parameters.reverse then
                    reverse_items[#reverse_items+1] = new_item
                end
                -- Mix
                if source_items_info[source].mix ~= 1 and not (is_proj_mix and source_items_info[source].mix == -1) then
                    DL.item.SetMixBehavior(new_item, 1)
                end
                -- Copy Paste Ext State
                local new_ext = DL.serialize.stringToTable(ext)
                -- Set original_value related to the orignal source item
                if new_ext then
                    new_ext.original_values = source_items_info[source]
                    new_ext = DL.serialize.tableToString(new_ext)
                    DL.item.SetExtState(new_item, EXT_NAME, ext_reroll, new_ext)
                end
                DL.item.SetExtState(new_item, EXT_NAME, 'is_item', clouds[cloud].guid)
                -- Delete the older item
                reaper.DeleteTrackMediaItem(track, item)
            else 
                no_items = true
            end
        end 
    end

    -- Reverse Items: 
    if #reverse_items > 0 then
        -- Save selection
        local sel_items = DL.item.CreateSelectedItemsTable(Proj)

        -- Reverse
        reaper.SelectAllMediaItems(Proj, false)
        for index, item in ipairs(reverse_items) do
            reaper.SetMediaItemSelected(item, true)
        end
        reaper.Main_OnCommand(41051, 0) -- Item properties: Toggle take reverse

        -- Selects back
        reaper.SelectAllMediaItems(Proj, false)
        for i, item in ipairs(sel_items) do
            if reaper.ValidatePtr2(Proj, item, 'MediaItem*') then
                reaper.SetMediaItemSelected(item, true)
            end
        end
    end 

    if no_items then
        reaper.ShowMessageBox('Some Cloud Items are Missing all their source items!', 'Reaper Clouds ReRoll', 0)
    end
end


function Clouds.ReRoll.Track(items, clouds, total, coroutine_time)
    for cloud, t_items in pairs(items) do
        local ct = clouds[cloud]
        for k, t in ipairs(t_items) do
            coroutine_time = corotine_check(coroutine_time, k, total)
    
            local item = t.item
            local track = reaper.GetMediaItem_Track(item)

            -- Need to pass .self to .1 for using Random with Weight
            table.insert(ct.tracks,1,ct.tracks.self) 
            local track_k, track_t = DL.t.RandomValueWithWeight(ct.tracks, 'chance')
            local new_track = DL.t.Check(track_t,'track') or track -- specific track or self. 
            if new_track ~= track then
                reaper.MoveMediaItemToTrack( item, new_track )
            end
        end 
    end
end

function Clouds.ReRoll.Grains_Pos(items, clouds, total, coroutine_time)
    for cloud, t_items in pairs(items) do
        local ct = clouds[cloud]
        -- Get envelopes
        local envs = {envelopes = {}, randomization = {}, grains = {}}
        envs.grains.position = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.grains.position, false)

        envs.grains.randomize_position = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.grains.randomize_position, false)
        envs.grains.c_randomize_position = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.grains.c_random_position, false)

        for k, t in ipairs(t_items) do
            coroutine_time = corotine_check(coroutine_time, k, total)
    
            local item = t.item
            local take = t.take
            local pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION') - ct.start
            local o_item_t = {rate = t.info.original_values.rate, length = t.info.original_values.length, offset = t.info.original_values.offset}
            local new_values = {}

            if ct.grains.on then
                -- Position/Offset (only inside the original are)
                local grain_offset
                if not ct.grains.position.on then -- random using items area 
                    local take_end = o_item_t.offset + (o_item_t.length * o_item_t.rate) -- need to consider the rate 
                    grain_offset = DL.num.RandomFloat(o_item_t.offset, take_end, true)
                else -- user determinated
                    local percent = ct.grains.position.val/100
                    if ct.grains.position.envelope and envs.grains.position then
                        local _
                        _, percent = reaper.Envelope_Evaluate(envs.grains.position, pos * ct.rate, 0, 0) 
                    end
                    grain_offset = o_item_t.offset + ((o_item_t.length * o_item_t.rate) * percent)
                    -- Apply position drift
                    if ct.grains.randomize_position.on then
                        -- chance
                        local cur_chance = ct.grains.randomize_position.chance.val 
                        if ct.grains.randomize_position.chance.env and envs.grains.c_randomize_position then
                            local retval, env_val =  reaper.Envelope_Evaluate(envs.grains.c_randomize_position, pos * ct.rate, 0, 0)
                            cur_chance = env_val * cur_chance                           
                        end
                        local rnd = math.random(0,99)
                        if rnd < cur_chance then
                            local min, max = ct.grains.randomize_position.min, ct.grains.randomize_position.max
                            if ct.grains.randomize_position.envelope and envs.grains.randomize_position then
                                local retval, env_val = reaper.Envelope_Evaluate(envs.grains.randomize_position, pos * ct.rate, 0, 0) 
                                min, max = min * env_val, max * env_val   
                            end
                            local drift =  DL.num.RandomFloat(min, max, true)
                            drift = drift / 1000 -- ms to sec
                            grain_offset = grain_offset + drift
                        end
                    end
                end
                new_values.offset = grain_offset 

                -- Offset
                if new_values.offset then -- Set by : Grains,
                    reaper.SetMediaItemTakeInfo_Value(take, 'D_STARTOFFS', new_values.offset)
                end
            end

        end 
    end
end

function Clouds.ReRoll.Grains_Size(items, clouds, total, coroutine_time)
    for cloud, t_items in pairs(items) do
        local ct = clouds[cloud]
        -- Get envelopes
        local envs = {envelopes = {}, randomization = {}, grains = {}}
        envs.grains.size = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.grains.size, false)

        envs.grains.randomize_size = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.grains.randomize_size, false)
        envs.grains.c_randomize_size = reaper.TakeFX_GetEnvelope(ct.take, 0, FXENVELOPES.grains.c_random_size, false)

        for k, t in ipairs(t_items) do
            coroutine_time = corotine_check(coroutine_time, k, total)
    
            local item = t.item
            local take = t.take
            local pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION') - ct.start
            local new_values = {}

            if ct.grains.on then
                -- Size/Length
                local grain_size = ct.grains.size.val
                if ct.grains.size.envelope and envs.grains.size then
                    local retval, env_val = reaper.Envelope_Evaluate(envs.grains.size, pos * ct.rate, 0, 0)
                    grain_size = DL.num.MapRange(grain_size * env_val, 0, grain_size, ct.grains.size.env_min, grain_size)  
                end    
                
                -- Size Drift
                if ct.grains.randomize_size.on then
                    -- chance
                    local cur_chance = ct.grains.randomize_size.chance.val 
                    if ct.grains.randomize_size.chance.env and envs.grains.c_randomize_size then
                        local retval, env_val = reaper.Envelope_Evaluate(envs.grains.c_randomize_size, pos * ct.rate, 0, 0)
                        cur_chance = env_val * cur_chance
                    end
                    local rnd = math.random(0,99)
                    if rnd < cur_chance then
                        local min, max = ct.grains.randomize_size.min, ct.grains.randomize_size.max -- makes it always above 0, numbers between 0 and 1 are reducing the size
                        if ct.grains.randomize_size.envelope and envs.grains.randomize_size then
                            local retval, env_val = reaper.Envelope_Evaluate(envs.grains.randomize_size, pos * ct.rate, 0, 0) 
                            min, max = min * env_val, max * env_val 
                        end    
                        min, max = min + 100, max + 100
                        local drift = DL.num.RandomFloatExp(min, max) -- between almost 0 and inf
                        drift = drift - 100
                        local drift_ms = grain_size * (drift/100)
                        grain_size = grain_size + drift_ms
                    end
                end
                grain_size = DL.num.Clamp(grain_size, CONSTRAINS.grain_low)                
                grain_size = grain_size / 1000 -- ms to sec
                new_values.length = grain_size

                -- Size
                if new_values.length then -- Set by : Grains, Playrate
                    reaper.SetMediaItemInfo_Value(item, 'D_LENGTH', new_values.length /( t.info.parameters.rate or 1) )
                end
            end

        end 
    end
end

