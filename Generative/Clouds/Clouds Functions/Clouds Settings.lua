--@noindex
Clouds = Clouds or {}
Clouds.Settings = {}

function Clouds.Settings.Default()
    return {
        tooltip = true,
        theme = 'Dark'
    }
end

function Clouds.Settings.Save(path, settings)
    DL.json.save(path, settings)
end

function Clouds.Settings.Load(path)
    if not reaper.file_exists(path) then
        local default = Clouds.Settings.Default()
        Clouds.Settings.Save(path, default)
        return default
    else
        return DL.json.load(path)
    end
end