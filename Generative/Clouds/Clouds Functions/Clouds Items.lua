--@noindex
Clouds = Clouds or {}
Clouds.Item = {}

function Clouds.Item.Create(proj)
    reaper.Undo_BeginBlock2(proj)
    reaper.PreventUIRefresh(1)
    reaper.SelectAllMediaItems(proj, false)
    local track = reaper.GetLastTouchedTrack() or reaper.GetSelectedTrack(proj, 0) or reaper.GetTrack(proj, 0)
    if not track then
        reaper.ShowMessageBox('Please, insert some track at the project!', 'Clouds', 0)
        return false 
    end
    local start, fim = reaper.GetSet_LoopTimeRange2(proj, false, false, 0, 0, false)
    if start == fim then
        reaper.ShowMessageBox('Please, make a time selection!', 'Clouds', 0)
        return false
    end
    local item = reaper.CreateNewMIDIItemInProj(track, start, fim, false)
    reaper.SetMediaItemSelected(item, true)
    local take = reaper.GetActiveTake(item)
    local def_t = Clouds.Item.DefaultTable()
    
    -- Style 🐄
    --reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', '!Cloud Item', true)
    reaper.SetMediaItemInfo_Value(item, 'I_CUSTOMCOLOR', CloudColor)
    DL.item.SetImage(item, CloudImage, 3)

    -- fX
    reaper.TakeFX_AddByName( take, FX_NAME, -1 )

    -- Write table to item
    --local serialized_t = DL.serialize.tableToString(def_t)
    --DL.item.SetExtState(item, EXT_NAME, 'settings', serialized_t)
    Clouds.Item.SaveSettings(proj, item, def_t)

    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock2(proj, 'Create Cloud Item', -1)
    reaper.UpdateArrange()
end

function Clouds.Item.CheckSelection(proj)
    local cnt = reaper.GetProjectStateChangeCount(proj)
    if cnt ~= CurrentProjCount then
        local something_changed = false
        if not CreatingClouds then -- Update selected cloud to GUI. If fixed cloud or it is generating, prevent it.
            local found = false
            for item in DL.enum.SelectedMediaItem(proj) do
                local retval, extstate = DL.item.GetExtState(item, EXT_NAME, 'settings')
                if extstate ~= '' then
                    --[[ if CloudTable and CloudTable.cloud == item then
                        break
                    end ]]
                    local ext_table = DL.serialize.stringToTable(extstate)
                    -- Guids to Items/Tracks
                    local t = Clouds.convert.ConvertGUIDtoUserData_Manually(proj, ext_table)
                    -- Set Primary CloudTable
                    if t then -- check if cloud table havent been corrupted at some script crash
                        t.cloud = item
                        if not found then
                            found = true
                            -- reset previous CloudsTables
                            Clouds.Item.ResetColors()
                            CloudsTables = {}
                            -- Set GUI Cloud Table
                            CloudTable = t
                        end

                        something_changed = Clouds.Item.UpdateVersion(t)
                        CloudsTables[#CloudsTables+1] = t
                    end
                end
            end
        end

        --Checks
        if CloudsTables then
            for ctidx, ct in DL.t.ipairs_reverse(CloudsTables) do
                if not reaper.ValidatePtr2(Proj, ct.cloud, 'MediaItem*') then
                    table.remove(CloudsTables, ctidx)
                    if #CloudsTables == 0 then
                        CloudsTables = nil
                        CloudTable = nil
                    end
                    goto continue
                end 

                for k, v in DL.t.ipairs_reverse(CloudTable.items) do
                    if not reaper.ValidatePtr2(Proj, v.item, 'MediaItem*') then
                        table.remove(CloudTable.items,k)
                        something_changed = true
                    end
                end
    
                for k, v in DL.t.ipairs_reverse(CloudTable.tracks) do -- dont need to check self
                    if not reaper.ValidatePtr2(Proj, v.track, 'MediaTrack*') then
                        table.remove(CloudTable.tracks,k)
                        something_changed = true
                    end
                end

                -- Check if cloud item has FX
                Clouds.Item.EnsureFX(CloudTable.cloud)   
                
                if something_changed then
                    Clouds.Item.SaveSettings(proj, CloudTable.cloud, CloudTable)
    
                    if CreatingClouds then -- Something got deleted while it was generating
                        CreatingClouds = nil
                        -- TODO give a warning message. 
                    end
                end
                ::continue::
            end
        end

        CurrentProjCount = cnt
    end
end

local time = 0
function Clouds.Item.DrawSelected(proj)
    if CloudsTables then
        time = time + 0.045
        local wave = (math.sin(time)) / 8 
        for index, ct in ipairs(CloudsTables) do

            
            local r = math.max(0, math.min(255, 7 + (wave * 255)))//1
            local g = math.max(0, math.min(255, 136 + (wave * 255)))//1
            local b = math.max(0, math.min(255, 140 + (wave * 255)))//1
            local native = reaper.ColorToNative(r,g,b) | 0x1000000
            reaper.SetMediaItemInfo_Value(ct.cloud, 'I_CUSTOMCOLOR', native)
        end 
        reaper.UpdateArrange()
    end
end

function Clouds.Item.ResetColor(cloud_item)
    if  reaper.ValidatePtr2(Proj, cloud_item, 'MediaItem*') then
        reaper.SetMediaItemInfo_Value(cloud_item, 'I_CUSTOMCOLOR', CloudColor)
    end 
end

function Clouds.Item.ResetColors()
    if CloudsTables then
        for index, ct in ipairs(CloudsTables) do
            Clouds.Item.ResetColor(ct.cloud)
        end
    end
end

function Clouds.Item.atexit()
    Clouds.Item.ResetColors()    
end

---Applies a parameter to all other clouds
---@param value any The new value to be set for the property.
---@param ... any An array of keys that represent the path to the property to be updated.
function Clouds.Item.ApplyParameter(value, ...)
    local address = {...}
    for index, ct in ipairs(CloudsTables) do
        if ct ~= CloudTable.cloud then
            local current = ct
            -- Navigate through the address path
            for i = 1, #address-1 do
                current = current[address[i]]
            end
            -- Set the final value
            current[address[#address]] = value
            -- Save the updated settings
            Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
        end
    end
    reaper.UpdateArrange()
    reaper.Undo_OnStateChange_Item(Proj, 'Cloud: Change Setting', CloudTable.cloud)
end

function Clouds.Item.SaveSettings(proj, item, settings)
    --- Items/Tracks to guids
    settings.cloud = item -- Covers the case of the cloud item being copied
    local guided = Clouds.convert.ConvertUserDataToGUID_Manually(proj, settings)
    local serialized_t = DL.serialize.tableToString(guided)
    DL.item.SetExtState(item, EXT_NAME, 'settings', serialized_t)
end

---------- Items to be copied: 
local msg_add_tags_items = 'Some of the items you are tring to add were generated using Clouds.\nTo add them back to Clouds you need to untag them.\nUntagging an item will make it a normal items, which wont be deleted by new generations.\nDo you want to untag these items?' 
function Clouds.Item.SetItems(proj)
    local t = {}
    local result
    for item in DL.enum.SelectedMediaItem(proj) do
        local is_tag = DL.item.GetExtState(item, EXT_NAME, 'is_item')
        if (not result) and is_tag then
            result = reaper.ShowMessageBox( msg_add_tags_items, 'Clouds', 4 )
        end

        if is_tag and result == 7 then -- skip 
            goto continue
        elseif is_tag and result == 6 then -- untag
            DL.item.SetExtState(item, EXT_NAME, 'is_item', '')
        end

        if not DL.item.GetExtState(item, EXT_NAME, 'settings') then -- prevent adding cloud items to selections
            t[#t+1] = {
                item = item,
                chance = 1
            }
        end 
        ::continue::
    end

    for ct_idx, ct in ipairs(CloudsTables) do
        ct.items = t
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    reaper.Undo_OnStateChange_Item(Proj, 'Cloud: Change Setting', CloudTable.cloud)
end

function Clouds.Item.AddItems(proj)
    local result
    local items = {}
    for item in DL.enum.SelectedMediaItem(proj) do
        local is_tag = DL.item.GetExtState(item, EXT_NAME, 'is_item')
        if (not result) and is_tag then
            result = reaper.ShowMessageBox( msg_add_tags_items, 'Clouds', 4 )
        end

        if is_tag and result == 7 then -- skip 
            goto continue
        elseif is_tag and result == 6 then -- untag
            DL.item.SetExtState(item, EXT_NAME, 'is_item', '')
        end

        if not DL.item.GetExtState(item, EXT_NAME, 'settings') then -- prevent adding cloud items to selections
            items[#items+1] = {
                item = item,
                chance = 1
            }
        end
        ::continue::
    end

    for ct_idx, ct in ipairs(CloudsTables) do
        for k, item in ipairs(items) do
            ct.items[#ct.items+1] = item
        end
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    reaper.Undo_OnStateChange_Item(Proj, 'Cloud: Change Setting', CloudTable.cloud)
end

function Clouds.Item.SelectItems(proj)
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2(proj)
    reaper.SelectAllMediaItems(proj, false)
    for k, t in ipairs(CloudTable.items) do
        local item = t.item
        reaper.SetMediaItemSelected(item, true)
    end
    reaper.SetMediaItemSelected(CloudTable.cloud, true)
    reaper.UpdateArrange()
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock2(proj, 'Select Rain Items for Cloud', -1)
end

------------ Tracks to be copied

function Clouds.Item.SetTracks(proj) --Set
    local t = {}
    for track in DL.enum.SelectedTracks2(proj, false) do
        t[#t+1] = {
            track = track,
            chance = 1
        }
    end

    -- Remove Current tracks (I am removing all tracks but the self track)
    for ct_idx, ct in ipairs(CloudsTables) do
        for k, v in DL.t.ipairs_reverse(ct.tracks) do 
            ct.tracks[k] = nil
        end
        
        -- Add Selected Tracks
        for k, v in ipairs(t) do 
            ct.tracks[k] = v
        end
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    reaper.Undo_OnStateChange_Item(Proj, 'Cloud: Change Setting', CloudTable.cloud)
end

function Clouds.Item.AddTracks(proj)
    local tracks = {}
    for track in DL.enum.SelectedTracks2(proj, false) do
        tracks[#tracks+1] = {
            track = track,
            chance = 1
        }
    end

    for ct_idx, ct in ipairs(CloudsTables) do
        -- Create a table with all tracks already added for this ct
        local already = {}
        for k2, trackT in ipairs(ct.tracks) do
            already[trackT.track] = true             
        end
        -- Add non duplicated tracks
        for k, v in ipairs(tracks) do
            if not already[v.track] then
                ct.tracks[#ct.tracks+1] = v
            end
        end
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    reaper.Undo_OnStateChange_Item(Proj, 'Cloud: Change Setting', CloudTable.cloud)
end

function Clouds.Item.SelectTracks(proj)
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2(proj)
    -- Unselect all
    for track in DL.enum.Tracks(proj) do
        reaper.SetTrackSelected(track, false)
    end
    -- Select addressed at the cloud
    for k, t in ipairs(CloudTable.tracks) do
        local track = t.track
        reaper.SetTrackSelected(track, true)
    end
    -- Select at cloud
    local cloud_track = reaper.GetMediaItem_Track(CloudTable.cloud)
    reaper.SetTrackSelected(cloud_track, true)

    reaper.UpdateArrange()
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock2(proj, 'Select Rain Items for Cloud', -1)
end

-------------- Default table

function Clouds.Item.DefaultTable()
    local t = {
        version = SCRIPT_V,
        items = {},
        density = {
            random = {
                val = 5,
                envelope = false
            },

            density = {
                val = 10,
                envelope = false,
                env_min = 0
            },

            cap = 0,
            quantize = false,
            n_gen = 1 -- 1.2.0
        },
        tracks = {
            self = {
                chance = 1
            },
        },
        randomization = {
            vol = {
                on = false,
                min = 0,
                max = 0,
                envelope = false,
                chance = {
                    val = 100,
                    env = false,
                },
            },

            pan = {
                on = false,
                min = 0,
                max = 0,
                envelope = false,
                chance = {
                    val = 100,
                    env = false,
                },
            },

            pitch = {
                on = false,
                min = 0,
                max = 0,
                envelope = false,
                quantize = 0,
                chance = {
                    val = 100,
                    env = false,
                },
            },

            stretch = {
                on = false,
                min = 1, -- should never be 0
                max = 1, -- should never be 0
                envelope = false,
                chance = {
                    val = 100,
                    env = false,
                },
            },

            reverse = {
                on = false,
                val = 0,
                envelope = false,
                chance = {
                    val = 100,
                    env = false,
                },
            },
        },

        envelopes = {
            vol = {
                on = false,
                min = 0,
                max = 0,
                chance = {
                    val = 100,
                    env = false,
                },
            },

            pan = {
                on = false,
                min = 0,
                max = 0,
                chance = {
                    val = 100,
                    env = false,
                },
            },

            pitch = {
                on = false,
                min = 0,
                max = 0,
                quantize = 0,
                chance = {
                    val = 100,
                    env = false,
                },
            },

            stretch = {
                on = false,
                min = 1, -- should never be 0
                max = 1, -- should never be 0
                chance = {
                    val = 100,
                    env = false,
                },
            },
        },

        midi_notes = {
            EDO = 12,
            center = 60,
            is_synth = false,
            synth = {
                min_vol = -36,
                hold_pos = false
            },
            A4 = 440,
            solo_notes = false
        },

        grains = {
            on = false,
            size = {
                val = 100,
                envelope = false,
                env_min = 0,
            },
            randomize_size = {
                on = false,
                min = -25, -- in %
                max = 25,
                envelope = false,
                chance = {
                    val = 100,
                    env = false,
                },
            },
            position = {
                on = false,
                val = 0, -- in %
                envelope = false,
            },
            randomize_position = {
                on = false,
                min = -25,
                max = 25,
                envelope = false,
                chance = {
                    val = 100,
                    env = false,
                },
            },
            fade = {
                on = true,
                val = 20 -- in %. 100% = fadein + fadeout = item_length 
            }
        },
        seed = {
            seed = 0,
            history = {}
        }
    }
    return t
end

function Clouds.Item.UpdateVersion(cloud)
    local was_updated = false
    if not cloud.version or not DL.num.CompareVersion(cloud.version, '1.1.0') then -- V 1.1
        cloud.version = '1.1.0'
        cloud.seed = {
            seed = 0,
            history = {}
        }

        was_updated = true
    end

    if not DL.num.CompareVersion(cloud.version, '1.2.0') then
        cloud.envelopes = {
            vol = {
                on = false,
                min = 0,
                max = 0,
                chance = {
                    val = 100,
                    env = false,
                },
            },

            pan = {
                on = false,
                min = 0,
                max = 0,
                chance = {
                    val = 100,
                    env = false,
                },
            },

            pitch = {
                on = false,
                min = 0,
                max = 0,
                quantize = 0,
                chance = {
                    val = 100,
                    env = false,
                },
            },

            stretch = {
                on = false,
                min = 1, -- should never be 0
                max = 1, -- should never be 0
                chance = {
                    val = 100,
                    env = false,
                },
            },
        }

        cloud.density.n_gen = 1

        cloud.version = '1.2.0'
        was_updated = true
    end
    
    return was_updated
end

function Clouds.Item.ShowHideEnvelope(bool,envelope_n,t)
    t = t or CloudsTables
    for k, ct in ipairs(t) do
        if bool then
            reaper.TakeFX_GetEnvelope(reaper.GetActiveTake(ct.cloud), 0, envelope_n, true)
        else
            local env = reaper.TakeFX_GetEnvelope(reaper.GetActiveTake(ct.cloud), 0, envelope_n, true)
            local retval, chunk = reaper.GetEnvelopeStateChunk( env, '', false )
            chunk = chunk:gsub('\nVIS 1', '\nVIS 0')
            reaper.SetEnvelopeStateChunk( env, chunk, false )
        end
    end
end

---Used when pasting a setting, updating all envelopes from CloudTale.cloud
function Clouds.Item.ShowHideAllEnvelopes(t)
    t = t or CloudsTables
    for k, ct in ipairs(t) do
        Clouds.Item.ShowHideEnvelope(ct.density.density.envelope,FXENVELOPES.density)
        Clouds.Item.ShowHideEnvelope(ct.density.random.envelope,FXENVELOPES.dust)
        Clouds.Item.ShowHideEnvelope(ct.randomization.vol.envelope,FXENVELOPES.randomization.vol)
        Clouds.Item.ShowHideEnvelope(ct.randomization.pan.envelope,FXENVELOPES.randomization.pan)
        Clouds.Item.ShowHideEnvelope(ct.randomization.pitch.envelope,FXENVELOPES.randomization.pitch)
        Clouds.Item.ShowHideEnvelope(ct.randomization.stretch.envelope,FXENVELOPES.randomization.stretch)
        Clouds.Item.ShowHideEnvelope(ct.randomization.reverse.envelope,FXENVELOPES.randomization.reverse)
        Clouds.Item.ShowHideEnvelope(ct.grains.size.envelope,FXENVELOPES.grains.size)
        Clouds.Item.ShowHideEnvelope(ct.grains.randomize_size.envelope,FXENVELOPES.grains.randomize_size)
        Clouds.Item.ShowHideEnvelope(ct.grains.position.envelope,FXENVELOPES.grains.position)
        Clouds.Item.ShowHideEnvelope(ct.grains.randomize_position.envelope,FXENVELOPES.grains.randomize_position)
        -- chances
        Clouds.Item.ShowHideEnvelope(ct.grains.randomize_position.on and ct.grains.randomize_position.chance.env,FXENVELOPES.grains.c_random_position)
        Clouds.Item.ShowHideEnvelope(ct.grains.randomize_size.on and ct.grains.randomize_size.chance.env,FXENVELOPES.grains.c_random_size)
        Clouds.Item.ShowHideEnvelope(ct.randomization.vol.on and ct.randomization.vol.chance.env,FXENVELOPES.randomization.c_vol)
        Clouds.Item.ShowHideEnvelope(ct.randomization.pan.on and ct.randomization.pan.chance.env,FXENVELOPES.randomization.c_pan)
        Clouds.Item.ShowHideEnvelope(ct.randomization.pitch.on and ct.randomization.pitch.chance.env,FXENVELOPES.randomization.c_pitch)
        Clouds.Item.ShowHideEnvelope(ct.randomization.stretch.on and ct.randomization.stretch.chance.env,FXENVELOPES.randomization.c_stretch)
        Clouds.Item.ShowHideEnvelope(ct.randomization.reverse.on and ct.randomization.reverse.chance.env,FXENVELOPES.randomization.c_reverse)
        -- envelopes
        Clouds.Item.ShowHideEnvelope(ct.envelopes.vol.on,FXENVELOPES.envelopes.vol)
        Clouds.Item.ShowHideEnvelope(ct.envelopes.vol.on and ct.envelopes.vol.chance.env, FXENVELOPES.envelopes.c_vol)
        Clouds.Item.ShowHideEnvelope(ct.envelopes.pan.on,FXENVELOPES.envelopes.pan)
        Clouds.Item.ShowHideEnvelope(ct.envelopes.pan.on and ct.envelopes.pan.chance.env, FXENVELOPES.envelopes.c_pan)
        Clouds.Item.ShowHideEnvelope(ct.envelopes.pitch.on,FXENVELOPES.envelopes.pitch)
        Clouds.Item.ShowHideEnvelope(ct.envelopes.pitch.on and ct.envelopes.pitch.chance.env, FXENVELOPES.envelopes.c_pitch)
        Clouds.Item.ShowHideEnvelope(ct.envelopes.stretch.on,FXENVELOPES.envelopes.stretch)
        Clouds.Item.ShowHideEnvelope(ct.envelopes.stretch.on and ct.envelopes.stretch.chance.env, FXENVELOPES.envelopes.c_stretch)
    end
end

function Clouds.Item.EnsureFX(cloud)
    local retval, buf = reaper.TakeFX_GetFXName( reaper.GetActiveTake(cloud), 0 )
    if not buf:match(FX_NAME) then
        reaper.TakeFX_AddByName( reaper.GetActiveTake(cloud), FX_NAME, -1 )
        Clouds.Item.ShowHideAllEnvelopes()
    end
end

function Clouds.Item.Paste(is_selected)
    if #CloudsTables > 0 then
        reaper.Undo_BeginBlock2(Proj)
        reaper.PreventUIRefresh(1)

        for ct_idx, ct in ipairs(CloudsTables) do
            local cloud = ct.cloud
            ct = DL.t.DeepCopy(CopySettings)
            CloudsTables[ct_idx] = ct
            ct.cloud = cloud
            Clouds.Item.UpdateVersion(ct)
            Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
        end
        CloudTable = CloudsTables[1]
        Clouds.Item.ShowHideAllEnvelopes()

        reaper.UpdateArrange()
        reaper.PreventUIRefresh(-1)
        reaper.Undo_EndBlock2(Proj, 'Paste Clouds', -1) 
    end
end

------ Generated Items:
function Clouds.Item.UntagSelected(proj)
    for item in DL.enum.SelectedMediaItem(proj) do
        local retval, extstate = DL.item.GetExtState(item, EXT_NAME, 'is_item')
        if extstate ~= '' then
            DL.item.SetExtState(item, EXT_NAME, 'is_item', '')
        end 
        -- body
    end
end

-- Delete

function Clouds.Item.DeleteGenerations(proj, is_selection, is_area)
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2(proj)
    -- Which clouds apply
    local clouds = {}
    for k, ct in ipairs(CloudsTables) do
        clouds[#clouds+1] = {item = ct.cloud, guid = reaper.BR_GetMediaItemGUID(ct.cloud)}
    end      

    -- Which scope to delete
    local del_items = {}
    for k, v in ipairs(clouds) do
        local cloud_item = v.item
        local cloud_guid = v.guid
        if is_area then
            local start = reaper.GetMediaItemInfo_Value(cloud_item, 'D_POSITION')
            local len = reaper.GetMediaItemInfo_Value(cloud_item, 'D_LENGTH')
            local fim = start + len
            local dt = DL.item.GetItemsInRange(proj, start, fim, false, false) 
            for index, d_item in ipairs(dt) do
                local retval, extstate = DL.item.GetExtState(d_item, EXT_NAME, 'is_item')
                if extstate == cloud_guid then
                    del_items[d_item] = true
                end
            end
        else
            for loop_item in DL.enum.MediaItem(proj) do
                local retval, extstate = DL.item.GetExtState(loop_item, EXT_NAME, 'is_item')
                if extstate == cloud_guid then
                    del_items[loop_item] = true
                end
            end
        end        
    end
    -- delete
    for item, value in pairs(del_items) do        
        reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(item), item)
    end


    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock2(proj, 'Clouds: Delete Generated Items', -1)
    reaper.UpdateArrange()
end

function Clouds.Item.DeleteAnyGeneration(proj)
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2(proj)

    local del_items = {}
    for loop_item in DL.enum.MediaItem(proj) do
        local retval, extstate = DL.item.GetExtState(loop_item, EXT_NAME, 'is_item')
        if extstate ~= '' then
            del_items[loop_item] = true
        end
    end

    for item, value in pairs(del_items) do        
        reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(item), item)
    end

    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock2(proj, 'Clouds: Delete All Generated Items', -1)
    reaper.UpdateArrange()
end

--- Misc Actions
function Clouds.Item.PrintSeedHistory(cloud)
    reaper.ClearConsole()
    local len = #cloud.seed.history
    local start = len - (Settings.seed_print-1) > 0 and len - (Settings.seed_print-1) or 1
    for i = start, len do 
        if cloud.seed.history[i] then
            print('Seed ' .. tostring(len - i + 1).. ' : '..cloud.seed.history[i])
        else 
            break
        end
    end
end