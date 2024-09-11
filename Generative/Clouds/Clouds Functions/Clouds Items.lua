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
        local found = false
        for item in DL.enum.SelectedMediaItem(proj) do
            local retval, extstate = DL.item.GetExtState(item, EXT_NAME, 'settings')
            if extstate ~= '' then
                found = true
                if CloudTable and CloudTable.cloud == item then
                    break
                end
                local ext_table = DL.serialize.stringToTable(extstate)
                -- Guids to Items/Tracks
                CloudTable = Clouds.convert.ConvertGUIDToUserDataRecursive(proj, ext_table)
                if CloudTable then -- check if cloud table havent been corrupted at some script crash
                    CloudTable.cloud = item
                    break
                end
            end
        end
        if not found then
            CloudTable = nil
        end
        CurrentProjCount = cnt
    end
end

function Clouds.Item.SaveSettings(proj, item, settings)
    --- Items/Tracks to guids
    local guided = Clouds.convert.CovertUserDataToGUIDRecursive(proj, settings)
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
    CloudTable.items = t
end

function Clouds.Item.AddItems(proj)
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
            CloudTable.items[#CloudTable.items+1] = {
                item = item,
                chance = 1
            }
        end
        ::continue::
    end
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

    -- Remove Current tracks
    for k, v in ipairs(CloudTable.tracks) do 
        CloudTable.tracks[k] = nil
    end

    -- Add Selected Tracks
    for k, v in ipairs(t) do 
        CloudTable.tracks[k] = v
    end
end

function Clouds.Item.AddTracks(proj)
    for track in DL.enum.SelectedTracks2(proj, false) do
        local t = {
            track = track,
            chance = 1
        }
        CloudTable.tracks[#CloudTable.tracks+1] = t 
    end
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
        }
    }
    return t
end

function Clouds.Item.ShowHideEnvelope(bool,envelope_n)
    if bool then
        reaper.TakeFX_GetEnvelope(reaper.GetActiveTake(CloudTable.cloud), 0, envelope_n, true)
    else
        local env = reaper.TakeFX_GetEnvelope(reaper.GetActiveTake(CloudTable.cloud), 0, envelope_n, true)
        local retval, chunk = reaper.GetEnvelopeStateChunk( env, '', false )
        chunk = chunk:gsub('\nVIS 1', '\nVIS 0')
        reaper.SetEnvelopeStateChunk( env, chunk, false )
    end
end

---Used when pasting a setting, updating all envelopes from CloudTale.cloud
function Clouds.Item.ShowHideAllEnvelopes()
    Clouds.Item.ShowHideEnvelope(CloudTable.density.density.envelope,FXENVELOPES.density)
    Clouds.Item.ShowHideEnvelope(CloudTable.density.random.envelope,FXENVELOPES.dust)
    Clouds.Item.ShowHideEnvelope(CloudTable.randomization.vol.envelope,FXENVELOPES.randomization.vol)
    Clouds.Item.ShowHideEnvelope(CloudTable.randomization.pan.envelope,FXENVELOPES.randomization.pan)
    Clouds.Item.ShowHideEnvelope(CloudTable.randomization.pitch.envelope,FXENVELOPES.randomization.pitch)
    Clouds.Item.ShowHideEnvelope(CloudTable.randomization.stretch.envelope,FXENVELOPES.randomization.stretch)
    Clouds.Item.ShowHideEnvelope(CloudTable.randomization.reverse.envelope,FXENVELOPES.randomization.reverse)
    Clouds.Item.ShowHideEnvelope(CloudTable.grains.size.envelope,FXENVELOPES.grains.size)
    Clouds.Item.ShowHideEnvelope(CloudTable.grains.randomize_size.envelope,FXENVELOPES.grains.randomize_size)
    Clouds.Item.ShowHideEnvelope(CloudTable.grains.position.envelope,FXENVELOPES.grains.position)
    Clouds.Item.ShowHideEnvelope(CloudTable.grains.randomize_position.envelope,FXENVELOPES.grains.randomize_position)
    -- chances
    Clouds.Item.ShowHideEnvelope(CloudTable.grains.randomize_position.on and CloudTable.grains.randomize_position.chance.env,FXENVELOPES.grains.c_random_position)
    Clouds.Item.ShowHideEnvelope(CloudTable.grains.randomize_size.on and CloudTable.grains.randomize_size.chance.env,FXENVELOPES.grains.c_random_size)
    Clouds.Item.ShowHideEnvelope(CloudTable.randomization.vol.on and CloudTable.randomization.vol.chance.env,FXENVELOPES.randomization.c_vol)
    Clouds.Item.ShowHideEnvelope(CloudTable.randomization.pan.on and CloudTable.randomization.pan.chance.env,FXENVELOPES.randomization.c_pan)
    Clouds.Item.ShowHideEnvelope(CloudTable.randomization.pitch.on and CloudTable.randomization.pitch.chance.env,FXENVELOPES.randomization.c_pitch)
    Clouds.Item.ShowHideEnvelope(CloudTable.randomization.stretch.on and CloudTable.randomization.stretch.chance.env,FXENVELOPES.randomization.c_stretch)
    Clouds.Item.ShowHideEnvelope(CloudTable.randomization.reverse.on and CloudTable.randomization.reverse.chance.env,FXENVELOPES.randomization.c_reverse)
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
    if CloudTable and FixedCloud then
        clouds[#clouds+1] = {item = CloudTable.cloud, guid = reaper.BR_GetMediaItemGUID(CloudTable.cloud)}
    else
        local f = is_selection and DL.enum.SelectedMediaItem or DL.enum.MediaItem
        for item in f(proj) do
            local retval, extstate = DL.item.GetExtState(item, EXT_NAME, 'settings')
            if extstate ~= '' then
                clouds[#clouds+1] = {item = item, guid = reaper.BR_GetMediaItemGUID(item)}
            end
        end
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