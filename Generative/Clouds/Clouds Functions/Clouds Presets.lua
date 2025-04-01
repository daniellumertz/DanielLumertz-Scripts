--@noindex
Clouds = Clouds or {}
Clouds.Presets = {}

function Clouds.Presets.LoadTable(path)
    local presets = {}
    for file_name in DL.enum.Files(path) do 
        local file = path..file_name
        if DL.files.GetExtension(file) == 'json' then
            presets[#presets+1] = {
                name = file_name:match('(.+)%.json') or 'Preset Without a Name',
                path = file
            }
        end
    end
    return presets 
end

--preset.path, ct
function Clouds.Presets.Load(path)
    local t = DL.json.load(path)
    if type(t) == 'table' then
        if #CloudsTables > 0 then
            reaper.Undo_BeginBlock2(Proj)
            reaper.PreventUIRefresh(1)
    
            for ct_idx, ct in ipairs(CloudsTables) do
                local new_ct = DL.t.DeepCopy(t)
                new_ct.items = ct.items
                new_ct.cloud = ct.cloud
                new_ct.tracks = ct.tracks
                Clouds.Item.UpdateVersion(new_ct)
                CloudsTables[ct_idx] = new_ct
                Clouds.Item.SaveSettings(Proj, ct.cloud, new_ct)
            end
            CloudTable = CloudsTables[1]
            Clouds.Item.ShowHideAllEnvelopes()
    
            reaper.UpdateArrange()
            reaper.PreventUIRefresh(-1)
            reaper.Undo_EndBlock2(Proj, 'Paste Clouds', -1) 
        end

        return true
    else
        reaper.ShowMessageBox('Failed to Load Preset!\nPlease contact me at the REAPER thread if problem persists!', "Clouds", 0)
        return false
    end    
end

function Clouds.Presets.SavePreset(path, ct)
    if not path:match('%.json$') then path = path..'.json' end
    local t = DL.t.DeepCopy(ct)
    -- Clean project related information
    t.cloud = nil
    t.items = {}
    t.tracks = {self = {chance = 1}}
    for k, v in ipairs(t) do -- will keep the t.self.chance = number
        t[k] = nil
    end
    -- Try to save
    return DL.json.save(path, t)    
end