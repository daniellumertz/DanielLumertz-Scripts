--@noindex
Clouds = Clouds or {}
Clouds.Settings = {}

function Clouds.Settings.Default()
    return {
        tooltip = true,
        theme = 'Dark',
        stop_playback = true, -- as a security measure, stop playback when generating,
        is_del_area = false, -- delete items only in the area
        reroll = { -- not used for now. during generations, store the range of randomness for rerolling aftwards
            on = true,
        },
        version = SCRIPT_V,
        seed_print = 10, -- number of seeds to print.
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
        local t = DL.json.load(path)

        -- Update older versions.
        if Clouds.Settings.UpdateCheck(t) then
            Clouds.Settings.Save(path, t)
        end

        return t
    end
end

function Clouds.Settings.UpdateCheck(settings)
    local was_updated
    if not settings.version or not DL.num.CompareVersion(settings.version, '1.1.0') then
        settings.reroll = { -- during generations, store the range of randomness for rerolling aftwards
            on = false,
        }
        settings.version = '1.1.0'

        was_updated = true
    end

    if not DL.num.CompareVersion(settings.version, '1.1.1') then
        settings.seed_print = 10
        settings.version = '1.1.1'

        was_updated = true
    end

    if not DL.num.CompareVersion(settings.version, '1.2.0') then
        settings.version = '1.2.0'
        settings.reroll = { -- depreciated. during generations, store the range of randomness for rerolling aftwards
            on = true,
        }

        was_updated = true
    end

    return was_updated
end