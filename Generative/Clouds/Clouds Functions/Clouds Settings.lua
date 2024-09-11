--@noindex
Clouds = Clouds or {}
Clouds.Settings = {}

function Clouds.Settings.Default()
    return {
        tooltip = true,
        theme = 'Dark',
        stop_playback = true, -- as a security measure, stop playback when generating,
        is_del_area = false, -- delete items only in the area
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