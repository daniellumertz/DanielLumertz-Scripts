--@noindex
Clouds = Clouds or {}
Clouds.Presets = {}

function Clouds.Presets.LoadTable(path)
    local presets = {}
    for file_name in DL.enum.Files(path) do 
        local file = path..file_name
        if DL.files.GetExtension(file) == 'json' then
            presets[#presets+1] = {
                name = file_name:match('(.-)%.json'),
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
        t.items = CloudTable.items
        t.cloud = CloudTable.cloud
        t.tracks = CloudTable.tracks
        CloudTable = t
        return true
    else
        reaper.ShowMessageBox('Failed to Load Preset!\nPlease contact me at the REAPER thread if problem persists!', "Clouds", 0)
        return false
    end    
end

function Clouds.Presets.SavePreset(path, ct)
    if not path:match('$.json') then path = path..'.json' end
    local t = DL.t.DeepCopy(ct)
    -- Clean project related information
    t.cloud = nil
    t.items = {}
    for k, v in ipairs(t) do -- will keep the t.self.chance = number
        t[k] = nil
    end
    -- Try to save
    return DL.json.save(path, t)    
end