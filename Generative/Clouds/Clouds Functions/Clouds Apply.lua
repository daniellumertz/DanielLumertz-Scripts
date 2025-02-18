--@noindex
Clouds = Clouds or {}
Clouds.apply = {}

function Clouds.apply.GenerateClouds(proj, is_selection, is_delete)
    --local debug_time = reaper.time_precise()
    -- Get the Clouds it will generate
    local clouds = {}

    if CloudTable and FixedCloud then
        clouds[#clouds+1] = DL.t.DeepCopy(CloudTable)
    else
        local f = is_selection and DL.enum.SelectedMediaItem or DL.enum.MediaItem
        for item in f(proj) do
            local retval, extstate = DL.item.GetExtState(item, EXT_NAME, 'settings')
            if extstate ~= '' then
                local ext_table = DL.serialize.stringToTable(extstate)
                -- Guids to Items/Tracks
                local t = Clouds.convert.ConvertGUIDToUserDataRecursive(proj, ext_table)
                -- Check if some item/track wasnt found (remove it from the table)
                for k, v in DL.t.ipairs_reverse(t.items) do
                    if not reaper.ValidatePtr2(proj, v.item, 'MediaItem*') then
                        table.remove(t.items,k)
                    end
                end
        
                for k, v in DL.t.ipairs_reverse(t.tracks) do -- dont need to check self
                    if not reaper.ValidatePtr2(proj, v.track, 'MediaTrack*') then
                        table.remove(t.tracks,k)
                    end
                end
                -- Check if it has Clouds FX
                Clouds.Item.EnsureFX(item)
    
                t.cloud = item

                Clouds.Item.UpdateVersion(t)

                clouds[#clouds+1] = t
            end
        end
    end


    if #clouds == 0 then return true end
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    if Settings.stop_playback and reaper.GetPlayState() ~= 0 then
        reaper.Main_OnCommand(40044, 0) -- Transport: Play/stop
    end
    
    local coroutine_time = reaper.time_precise()
    local reverserd_items = {}
    local is_proj_mix = reaper.SNM_GetIntConfigVar('itemmixflag',100) == 1 --mix behavior 
    for c_idx, ct in ipairs(clouds) do -- ct = cloud table
        -- Save information about items and check if they exist
        local chance_sum = 0
        for k, v in DL.t.ipairs_reverse(ct.items) do
            local bol = reaper.ValidatePtr2(proj, v.item, 'MediaItem*')
            if bol then
                chance_sum = chance_sum + v.chance
                v.track = reaper.GetMediaItem_Track(v.item)
                v.take = reaper.GetActiveTake(v.item)
                v.offset = reaper.GetMediaItemTakeInfo_Value(v.take, 'D_STARTOFFS')  -- Need for: grains
                v.length = reaper.GetMediaItemInfo_Value(v.item, 'D_LENGTH')  -- Need for: grains
                v.rate = reaper.GetMediaItemTakeInfo_Value(v.take, 'D_PLAYRATE')  -- Need for: grains
                v.mix = DL.item.GetMixBehavior(v.item) 
            else
                table.remove(ct.items,k)
            end
        end
        if #ct.items == 0 then 
            reaper.ShowMessageBox('Please, add some Items at the Items tab!', 'Cloud Warning', 0)
            goto continue 
        end
        if chance_sum == 0 then 
            reaper.ShowMessageBox('All Item Weights are equal to zero!\nNo Item will be pasted!', 'Cloud Warning', 0)
            goto continue 
        end

        -- get cloud positions
        local cloud = {}
        cloud.item = ct.cloud
        cloud.take = reaper.GetActiveTake(cloud.item)
        cloud.start = reaper.GetMediaItemInfo_Value(ct.cloud, 'D_POSITION')
        cloud.len = reaper.GetMediaItemInfo_Value(ct.cloud, 'D_LENGTH')
        cloud.fim = cloud.start + cloud.len
        cloud.guid = reaper.BR_GetMediaItemGUID(cloud.item)
        cloud.rate = reaper.GetMediaItemTakeInfo_Value(cloud.take, 'D_PLAYRATE')

        -- Get MIDI Notes
        local notes = {}
        local retval, notes_cnt = reaper.MIDI_CountEvts(cloud.take) 
        if notes_cnt > 0 then
            for selected, muted, startppqpos, endppqpos, chan, pitch, vel, noteidx in DL.enum.MIDINotes(cloud.take) do
                if not muted then
                    notes[#notes+1] = {
                        start = (reaper.MIDI_GetProjTimeFromPPQPos(cloud.take, startppqpos) - cloud.start), 
                        fim = (reaper.MIDI_GetProjTimeFromPPQPos(cloud.take, endppqpos) - cloud.start), 
                        pitch = pitch,
                        vel = vel
                    }
                end
                -- body
            end
        end

        -- if delete then check items at cloud items positions and delete
        if is_delete then
            local dt = {}
            if Settings.is_del_area then
                dt = DL.item.GetItemsInRange(proj, cloud.start, cloud.fim, false, false, true) 
            else
                for item in DL.enum.MediaItem(proj) do
                    dt[#dt+1] = item
                end
            end
            for index, d_item in ipairs(dt) do
                local retval, extstate = DL.item.GetExtState(d_item, EXT_NAME, 'is_item')
                if extstate == cloud.guid then
                    reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(d_item), d_item)
                end
            end
        end

        -- Set general Random Seed 
        local seed = ct.seed.seed ~= 0 and math.randomseed(ct.seed.seed,0) or math.randomseed(math.random(1,100000),0)
        table.insert(ct.seed.history, seed)
        if #ct.seed.history == SEEDLIMIT then
            table.remove(ct.seed.history, 1)
        end
        Clouds.Item.SaveSettings(proj, ct.cloud, ct)
        if ct.cloud == CloudTable.cloud then -- Update GUI Cloud Table
            CloudTable.seed = ct.seed
        end

        -- Creates the reroll table to store information about the randomness.
        local reroll = {}

        -- calculate the position of each item using density values. output a table with the position for each new item t = {i = position}
        local positions = {} -- [1] = 0
        local synth_freqs = {}
        do
            local freq = ct.density.density.val
            local dust = ct.density.random.val -- dust = 1 means that a position will be randomize in the range of one period. half earlier half later.
            local density_env = reaper.TakeFX_GetEnvelope(cloud.take, 0, FXENVELOPES.density, false)
            local dust_env = reaper.TakeFX_GetEnvelope(cloud.take, 0, FXENVELOPES.dust, false)
            local chunk_size, desire = 1/(2*freq), 0
            if not ct.midi_notes.is_synth then -- Not Synth
                for pos = 0, cloud.len, chunk_size do
                    local new_freq = freq
                    if ct.density.density.envelope and density_env then
                        -- Get env value
                        local retval, env_val = reaper.Envelope_Evaluate(density_env, pos * cloud.rate, 0, 0)
                        new_freq = DL.num.MapRange(env_val * freq, 0, freq, ct.density.density.env_min, freq) 
                    end
                    local period = 1 / new_freq
    
                    if desire >= period then
                        local new_pos = pos
                        --Randomize (dust)
                        if dust > 0 then
                            local new_dust = dust 
                            if ct.density.random.envelope and dust_env then
                                local retval, env_val = reaper.Envelope_Evaluate(dust_env, pos * cloud.rate, 0, 0)
                                new_dust = env_val * dust
                            end
                            local range = period * new_dust
                            local random = (math.random() * range) - (range/2)
                            new_pos = new_pos + random
                            -- reflect item at borders
                            if new_pos > cloud.len then
                                new_pos = new_pos - (2 * (new_pos - cloud.len))
                            elseif new_pos < 0 then
                                new_pos = new_pos * -1 
                            end
                        end
                        -- Quantize
                        if ct.density.quantize then
                            local grid = reaper.BR_GetClosestGridDivision(new_pos + cloud.start)
                            new_pos = grid - cloud.start
                        end
                        -- Add to table
                        if not ct.midi_notes.solo_notes then
                            positions[#positions + 1] = new_pos
                        else
                            for index, note in ipairs(notes) do
                                if note.start <= new_pos and note.fim >= new_pos then
                                    positions[#positions + 1] = new_pos
                                    break
                                end 
                            end
                        end
                        desire = desire % period
                    end
                    -- add for next loop 
                    desire = desire + chunk_size
                end
                table.sort(positions)

            elseif #notes > 0 then -- Synth
                for index, note in ipairs(notes) do
                    if cloud.start + note.start >= cloud.fim then
                        break
                    end
                    local freq = ct.midi_notes.A4 * (2 ^ ((note.pitch - 69)/ct.midi_notes.EDO))
                    for i = 1, freq * (note.fim - note.start) do
                        local pos = note.start + (1/freq * i)
                        if cloud.start + pos >= cloud.fim then -- if pass the item
                            break
                        elseif pos >= 0 then
                            positions[#positions+1] = pos
                            synth_freqs[#synth_freqs+1] = {freq = freq, vel = note.vel, note_id = index}   
                        end
                    end
                end
                -- DONT SORT (need to match synth_freq. I didnt want to put both at the same table because this way is faster in the generate loop)
            end
        end

        -- Need to pass .self to .1 for using Random with Weight
        table.insert(ct.tracks,1,ct.tracks.self) 
        -- Check envelopes
        local envs = {
            grains = {
                size = reaper.TakeFX_GetEnvelope(cloud.take, 0, FXENVELOPES.grains.size, false),
                randomize_size = reaper.TakeFX_GetEnvelope(cloud.take, 0, FXENVELOPES.grains.randomize_size, false),
                position = reaper.TakeFX_GetEnvelope(cloud.take, 0, FXENVELOPES.grains.position, false),
                randomize_position = reaper.TakeFX_GetEnvelope(cloud.take, 0, FXENVELOPES.grains.randomize_position, false),

                c_randomize_size = reaper.TakeFX_GetEnvelope(cloud.take, 0, FXENVELOPES.grains.c_random_size, false),
                c_randomize_position = reaper.TakeFX_GetEnvelope(cloud.take, 0, FXENVELOPES.grains.c_random_position, false),
            },
            randomization = {
                vol = reaper.TakeFX_GetEnvelope(cloud.take, 0, FXENVELOPES.randomization.vol, false),
                pan = reaper.TakeFX_GetEnvelope(cloud.take, 0, FXENVELOPES.randomization.pan, false),
                pitch = reaper.TakeFX_GetEnvelope(cloud.take, 0, FXENVELOPES.randomization.pitch, false),
                stretch = reaper.TakeFX_GetEnvelope(cloud.take, 0, FXENVELOPES.randomization.stretch, false),
                reverse = reaper.TakeFX_GetEnvelope(cloud.take, 0, FXENVELOPES.randomization.reverse, false),

            
                c_vol = reaper.TakeFX_GetEnvelope(cloud.take, 0, FXENVELOPES.randomization.c_vol, false),
                c_pan = reaper.TakeFX_GetEnvelope(cloud.take, 0, FXENVELOPES.randomization.c_pan, false),
                c_pitch = reaper.TakeFX_GetEnvelope(cloud.take, 0, FXENVELOPES.randomization.c_pitch, false),
                c_stretch = reaper.TakeFX_GetEnvelope(cloud.take, 0, FXENVELOPES.randomization.c_stretch, false),
            }
        }

        --local coroutine_check = 0
        local held_items = {} -- for limiting the max n of overlapped items
        local notes_positions = {} -- for synth hold_position
        for k, pos in ipairs(positions) do
            -- coroutine
            --coroutine_check = coroutine_check + 1
            if ((reaper.time_precise() - coroutine_time) > UPDATE_FREQ.time) then -- (coroutine_check >= UPDATE_FREQ.items) 
                reaper.PreventUIRefresh(-1)
                coroutine.yield(false, {done = c_idx-1, total = #clouds}, {done = k, total = #positions})
                if CancelCreatingClouds then -- Cancel pasting
                    reaper.Undo_EndBlock2(proj, 'Generate Clouds', -1)
                    return true
                end
                --coroutine_check = 0
                reaper.PreventUIRefresh(1)
                coroutine_time = reaper.time_precise()
            end
            -- Check if it is caping
            if ct.density.cap > 0 then
                local idx = 1
                for i = 1, #held_items do
                    local held = held_items[idx]
                    if held.fim < pos then
                        table.remove(held_items, idx)
                    else
                        idx = idx + 1
                    end
                end

                -- randomize which item will be pasted
                if #held_items >= ct.density.cap then
                    goto continue_item 
                end
            end
            local item_k, o_item_t = DL.t.RandomValueWithWeight(ct.items, 'chance')
            -- decide which track to apply
            local track_k, track_t = DL.t.RandomValueWithWeight(ct.tracks, 'chance')
            local track = DL.t.Check(track_t,'track') or o_item_t.track -- specific track or self. 
            -- copy the item 
            local new_item = {}
            new_item.item = DL.item.CopyToTrack(o_item_t.item, track, pos + cloud.start, false, false)
            new_item.take = reaper.GetActiveTake(new_item.item)
            -- make a table of randomizations
            local new_values = {}


            -- if grains then get a length, offset and fade
            if ct.grains.on then
                -- Volume (synth)
                if ct.midi_notes.is_synth then
                    -- map midi to dB
                    local db = DL.num.MapRange(synth_freqs[k].vel, 1, 127, ct.midi_notes.synth.min_vol, 0)
                    new_values.vol = db
                end
                -- Size/Length
                local grain_size = ((not ct.midi_notes.is_synth) and ct.grains.size.val) or (2 * 1000/synth_freqs[k].freq)
                if ct.grains.size.envelope and envs.grains.size then
                    local retval, env_val = reaper.Envelope_Evaluate(envs.grains.size, pos * cloud.rate, 0, 0)
                    grain_size = DL.num.MapRange(grain_size * env_val, 0, grain_size, ct.grains.size.env_min, grain_size)  
                end    
                
                -- Size Drift
                if ct.grains.randomize_size.on then
                    -- chance
                    local cur_chance = ct.grains.randomize_size.chance.val 
                    if ct.grains.randomize_size.chance.env and envs.grains.c_randomize_size then
                        local retval, env_val = reaper.Envelope_Evaluate(envs.grains.c_randomize_size, pos * cloud.rate, 0, 0)
                        cur_chance = env_val * cur_chance
                    end
                    local rnd = math.random(0,99)
                    if rnd < cur_chance then
                        local min, max = ct.grains.randomize_size.min, ct.grains.randomize_size.max -- makes it always above 0, numbers between 0 and 1 are reducing the size
                        if ct.grains.randomize_size.envelope and envs.grains.randomize_size then
                            local retval, env_val = reaper.Envelope_Evaluate(envs.grains.randomize_size, pos * cloud.rate, 0, 0) 
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

                -- Position/Offset (only inside the original are)
                local grain_offset
                if (not ct.midi_notes.is_synth) or (not ct.midi_notes.synth.hold_pos) or (not notes_positions[synth_freqs[k].note_id]) then -- get a new position value
                    if not ct.grains.position.on then -- random using items area 
                        local take_end = o_item_t.offset + (o_item_t.length * o_item_t.rate) -- need to consider the rate 
                        grain_offset = DL.num.RandomFloat(o_item_t.offset, take_end, true)
                    else -- user determinated
                        local percent = ct.grains.position.val/100
                        if ct.grains.position.envelope and envs.grains.position then
                            local _
                            _, percent = reaper.Envelope_Evaluate(envs.grains.position, pos * cloud.rate, 0, 0) 
                        end
                        grain_offset = o_item_t.offset + ((o_item_t.length * o_item_t.rate) * percent)
                        -- Apply position drift
                        if ct.grains.randomize_position.on then
                            -- chance
                            local cur_chance = ct.grains.randomize_position.chance.val 
                            if ct.grains.randomize_position.chance.env and envs.grains.c_randomize_position then
                                local retval, env_val =  reaper.Envelope_Evaluate(envs.grains.c_randomize_position, pos * cloud.rate, 0, 0)
                                cur_chance = env_val * cur_chance                           
                            end
                            local rnd = math.random(0,99)
                            if rnd < cur_chance then
                                local min, max = ct.grains.randomize_position.min, ct.grains.randomize_position.max
                                if ct.grains.randomize_position.envelope and envs.grains.randomize_position then
                                    local retval, env_val = reaper.Envelope_Evaluate(envs.grains.randomize_position, pos * cloud.rate, 0, 0) 
                                    min, max = min * env_val, max * env_val   
                                end
                                local drift =  DL.num.RandomFloat(min, max, true)
                                drift = drift / 1000 -- ms to sec
                                grain_offset = grain_offset + drift
                            end
                        end
                    end
                    if ct.midi_notes.synth.hold_pos then
                        notes_positions[synth_freqs[k].note_id] = grain_offset
                    end
                else -- Get the held value
                    grain_offset = notes_positions[synth_freqs[k].note_id]
                end
                new_values.offset = grain_offset
            end
            
            -- if randomization get volume, pan, pitch, playrate, length, is_reverse
            do
                -- Volume
                if ct.randomization.vol.on then
                    -- chance
                    local cur_chance = ct.randomization.vol.chance.val 
                    if ct.randomization.vol.chance.env and envs.randomization.c_vol then
                        local retval, env_val =  reaper.Envelope_Evaluate(envs.randomization.c_vol, pos * cloud.rate, 0, 0)
                        cur_chance = env_val * cur_chance                           
                    end
                    local rnd = math.random(0,99)
                    if rnd < cur_chance then 
                        local min, max = ct.randomization.vol.min, ct.randomization.vol.max -- makes it always above 0, numbers between 0 and 1 are reducing the size
                        if ct.randomization.vol.envelope and envs.randomization.vol then
                            local retval, env_val = reaper.Envelope_Evaluate(envs.randomization.vol, pos * cloud.rate, 0, 0) 
                            min, max = min * env_val, max * env_val 
                        end  
                        min, max = min + CONSTRAINS.db_minmax, max + CONSTRAINS.db_minmax
                        local new_vol = DL.num.RandomFloatExp(min, max, 10)
                        new_vol = new_vol - CONSTRAINS.db_minmax
                        new_values.vol = (new_values.vol or 0) + new_vol
                    end
                end

                -- Pan
                if ct.randomization.pan.on then
                    -- chance
                    local cur_chance = ct.randomization.pan.chance.val 
                    if ct.randomization.pan.chance.env and envs.randomization.c_pan then
                        local retval, env_val =  reaper.Envelope_Evaluate(envs.randomization.c_pan, pos * cloud.rate, 0, 0)
                        cur_chance = env_val * cur_chance                           
                    end
                    local rnd = math.random(0,99)
                    if rnd < cur_chance then 
                        local min, max = ct.randomization.pan.min, ct.randomization.pan.max -- makes it always above 0, numbers between 0 and 1 are reducing the size
                        if ct.randomization.pan.envelope and envs.randomization.pan then
                            local retval, env_val = reaper.Envelope_Evaluate(envs.randomization.pan, pos * cloud.rate, 0, 0) 
                            min, max = min * env_val, max * env_val 
                        end    
                        local new_pan = DL.num.RandomFloat(min, max, true)
                        reaper.SetMediaItemTakeInfo_Value(new_item.take, 'D_PAN', new_pan)
                    end
                end

                -- Pitch
                if ct.randomization.pitch.on then
                    -- chance
                    local cur_chance = ct.randomization.pitch.chance.val 
                    if ct.randomization.pitch.chance.env and envs.randomization.c_pitch then
                        local retval, env_val =  reaper.Envelope_Evaluate(envs.randomization.c_pitch, pos * cloud.rate, 0, 0)
                        cur_chance = env_val * cur_chance                           
                    end
                    local rnd = math.random(0,99)
                    if rnd < cur_chance then 
                        local min, max = ct.randomization.pitch.min, ct.randomization.pitch.max -- makes it always above 0, numbers between 0 and 1 are reducing the size
                        if ct.randomization.pitch.envelope and envs.randomization.pitch then
                            local retval, env_val = reaper.Envelope_Evaluate(envs.randomization.pitch, pos * cloud.rate, 0, 0) 
                            min, max = min * env_val, max * env_val 
                        end    
                        local new_pitch = ct.randomization.pitch.quantize == 0 and DL.num.RandomFloat(min, max, true) or DL.num.RandomFloatQuantized(min, max, true, ct.randomization.pitch.quantize/100)
                        new_values.pitch = new_pitch
                        --new_pitch = new_pitch + reaper.GetMediaItemTakeInfo_Value(new_item.take, 'D_PITCH')
                        --reaper.SetMediaItemTakeInfo_Value(new_item.take, 'D_PITCH', new_pitch)
                    end
                end

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
 
                -- Stretch
                if ct.randomization.stretch.on then
                    -- chance
                    local cur_chance = ct.randomization.stretch.chance.val 
                    if ct.randomization.stretch.chance.env and envs.randomization.c_stretch then
                        local retval, env_val =  reaper.Envelope_Evaluate(envs.randomization.c_stretch, pos * cloud.rate, 0, 0)
                        cur_chance = env_val * cur_chance                           
                    end
                    local rnd = math.random(0,99)
                    if rnd < cur_chance then 
                        local min, max = ct.randomization.stretch.min, ct.randomization.stretch.max -- makes it always above 0, numbers between 0 and 1 are reducing the size
                        if ct.randomization.stretch.envelope and envs.randomization.stretch then
                            local retval, env_val = reaper.Envelope_Evaluate(envs.randomization.stretch, pos * cloud.rate, 0, 0) 
                            min, max = min ^ env_val, max ^ env_val 
                        end    
                        local new_rate = DL.num.RandomFloatExp(min, max, 2)
                        new_rate = new_rate * o_item_t.rate
                        new_values.length = (new_values.length or o_item_t.length) * (o_item_t.rate/new_rate)
                        reaper.SetMediaItemTakeInfo_Value(new_item.take, 'D_PLAYRATE', new_rate)
                    end
                end

                -- Reverse
                if ct.randomization.reverse.on then
                    local random = DL.num.RandomFloat(0, 100, true)
                    local chance = ct.randomization.reverse.val
                    if ct.randomization.reverse.envelope and envs.randomization.reverse then
                        local retval, env_val = reaper.Envelope_Evaluate(envs.randomization.reverse, pos * cloud.rate, 0, 0)
                        chance = chance * env_val
                    end
                    if random < chance then
                        reverserd_items[#reverserd_items+1] = new_item.item
                    end
                end
            end
            -- apply the new_values
            do
                -- Volume
                if new_values.vol then
                    local cur = DL.num.LinearTodB(reaper.GetMediaItemInfo_Value(new_item.item, 'D_VOL')) --TODO CHANGE TO GET ONLY ONCE
                    local result_l = DL.num.dBToLinear(new_values.vol + cur)
                    reaper.SetMediaItemInfo_Value(new_item.item, 'D_VOL', result_l)
                end
                -- Pitch
                if new_values.pitch then
                    new_values.pitch = new_values.pitch + reaper.GetMediaItemTakeInfo_Value(new_item.take, 'D_PITCH')
                    reaper.SetMediaItemTakeInfo_Value(new_item.take, 'D_PITCH', new_values.pitch)
                end
                -- Length
                if new_values.length then -- Set by : Grains, Playrate
                    reaper.SetMediaItemInfo_Value(new_item.item, 'D_LENGTH', new_values.length)
                end

                -- Offset
                if new_values.offset then -- Set by : Grains,
                    reaper.SetMediaItemTakeInfo_Value(new_item.take, 'D_STARTOFFS', new_values.offset)
                end
                -- Grain Fade
                if ct.grains.on and ct.grains.fade.on then
                    local len  = new_values.length * (ct.grains.fade.val/200)
                    reaper.SetMediaItemInfo_Value(new_item.item, 'D_FADEINLEN', len)
                    reaper.SetMediaItemInfo_Value(new_item.item, 'D_FADEOUTLEN', len)
                end

                if o_item_t.mix ~= 1 and not (is_proj_mix and o_item_t.mix == -1) then
                    DL.item.SetMixBehavior(new_item.item, 1)
                end

                -- Ext State
                DL.item.SetExtState(new_item.item, EXT_NAME, 'is_item', cloud.guid)
            end

            if ct.density.cap > 0 then
                held_items[#held_items+1] = {
                    start = pos,
                    fim = pos + (new_values.length or o_item_t.length)
                }
            end

            ::continue_item::
        end
        ::continue::
    end

    -- Reverse Items: 
    if #reverserd_items > 0 then
        -- Save selection
        local sel_items = DL.item.CreateSelectedItemsTable(proj)

        -- Reverse
        reaper.SelectAllMediaItems(proj, false)
        for index, item in ipairs(reverserd_items) do
            reaper.SetMediaItemSelected(item, true)
        end
        reaper.Main_OnCommand(41051, 0) -- Item properties: Toggle take reverse

        -- Selects back
        reaper.SelectAllMediaItems(proj, false)
        for i, item in ipairs(sel_items) do
            if reaper.ValidatePtr2(proj, item, 'MediaItem*') then
                reaper.SetMediaItemSelected(item, true)
            end
        end
    end

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock2(proj, 'Generate Clouds', -1)
    --print('Time: ', reaper.time_precise() - debug_time)
    return true, {done = #clouds, total = #clouds}, {done = 1, total = 1}
end