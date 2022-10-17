--@noindex

function Settings()
    local retval_load = false
    if reaper.file_exists( ScriptPath..SettingsFileName..'.json' ) then
        retval_load = LoadSettings(ScriptPath,SettingsFileName) -- it return retval based if the version of settings is the same as the current, if false then recreate with default settings
    end -- Create the settings file and load default
    if not retval_load then
        DefaultSettings()
        SaveSettings(ScriptPath,SettingsFileName)
    end
end

function DefaultSettings()
    -------------Get Setings
    IsGap = true
    Gap = 1/16 -- gap in QN
    GapString = '1/16'

    CombineTakes = true

    -------------Learn/Apply Setings
    PitchSettings = {
        mode =  1, -- 0 is off, 1 is pitch, 2 is intervals
        order = 1, --markov order to be used
        keep_start = true, -- maintain the order N notes when applying the markov
        use_muted = 0, -- 2 or 0 if generate a muted note will apply it. Add user setting to go between the three --- Ignore Mute = 0 (remove the mute symbol)--- Mute Type = 1 (dont change nothing) --- One Mute = 2 (parameters marked with mute will be only a muted symbol and wont differentiate between they. Exemple : Muted C and Muted D will become just Muted symbol) 
        drop = false -- if true the resolution will drop to the drop value. if 12 its the classical pitch classes 
    }

    RhythmSettings = {
        mode =  1, -- 0 is off, 1 is rhythm, 2 is measure pos
        order = 1, --markov order to be used
        keep_start = true, -- maintain the order N notes when applying the markov
        use_muted = 0, --1 or 0 if generate a muted note will apply it. For rhythms it only makes sense to be 0 or 1 mode
        drop = false, --if true the resolution will drop quantizing to the nearst value using the drop value.
        drop_quantize_text = '1/8'
    }

    VelSettings = {
        mode =  1, -- 0 is off, 1 is vel
        order = 1, --markov order to be used
        keep_start = true, -- maintain the order N notes when applying the markov
        use_muted = 0, --2 or 0 if generate a muted note will apply it. For vel it only makes sense to be 0 or 2 mode.
        drop = false --if true the resolution will drop to the nearst group the value fit in. Exemple: if the value is 50 and the drop is {{low = 1, high = 40},{low = 41, high = 100},{low = 101, high = 127}} then the value will be 2, referecing to the group 2. When enchanced it will choose randomly a value inside the group
    }

    LinkSettings = {
        pitch = false,
        vel = false,
        rhythm = false,
        separator = '\1',
        pitch_start = 'p', -- to form parameters like 'p60'..separator..'r1/4'..separator..'v100'
        rhythm_start = 'r',
        vel_start = 'v',
        keep_start = true
    }

    ---- Legato
    Legato = 'take'

    --- learn
    IgnoreMuted = false -- if true, will ignore muted notes ???

    --- UI Settings
    GUISettings = {
        tips = false
    }

    -- Weight are per section so dont need to declare as they all start with nil. PosQNWeight (for rhythm and measure pos), PCWeight(for pitch classes), PitchWeight(for pitch) , VelWeight(for velocity)
end

function SaveSettings(path,name)
    local settings = {
        IsGap = IsGap,
        Gap = Gap,
        GapString = GapString,
        CombineTakes = CombineTakes,
        PitchSettings = PitchSettings,
        RhythmSettings = RhythmSettings,
        VelSettings = VelSettings,
        LinkSettings = LinkSettings,
        Legato = Legato,
        IgnoreMuted = IgnoreMuted,
        Version = Version,
        GUISettings = GUISettings
    }
    save_json(path , name, settings)
end

function LoadSettings(path,name)
    local settings = load_json(path , name)
    local load_version = settings.Version
    if load_version ~= Version then return false end
    IsGap = settings.IsGap
    Gap = settings.Gap
    GapString = settings.GapString
    CombineTakes = settings.CombineTakes
    PitchSettings = settings.PitchSettings
    RhythmSettings = settings.RhythmSettings
    VelSettings = settings.VelSettings
    LinkSettings = settings.LinkSettings
    Legato = settings.Legato
    IgnoreMuted = settings.IgnoreMuted
    GUISettings = settings.GUISettings
    return true
end

function SaveSourceTable(source_table)
    local initial_folder = ScriptPath..'Sources'
    local retval, fileName = reaper.JS_Dialog_BrowseForSaveFile('Save Source Table', initial_folder, source_table.name, 'Markov Source Files\0*.json')
    if retval == 1 then
        local path = fileName:match('(.*)[\\/].-$')
        local name = fileName:match('.*[/\\](.-)$')
        local temp_source = TableConvertAllKeysToString(source_table)
        temp_source = CovertUserDataToGUIDRecursive(temp_source) 
        save_json(path , name, temp_source)
    end
end

function LoadSource(AllSources)
    local initial_folder = ScriptPath..'Sources'
    local retval, fileName = reaper.JS_Dialog_BrowseForOpenFiles('Load Source Table', initial_folder, '', 'Markov Source Files\0*.json',false) 
    if retval == 1 then
        local path = fileName:match('(.*)[\\/].-$')
        local name = fileName:match('.*[/\\](.-)%..-$') -- filter out the extension
        local temp_source = load_json(path , name)
        temp_source = TableConvertKeyToNumbers(temp_source)
        temp_source = ConvertGUIDToUserDataRecursive(temp_source)
        
        AllSources[#AllSources+1] = temp_source
        return temp_source
    else
        return false
    end
end

--------------- Json functions
--Save function
function save_json(path, name,  var)
    local filepath = path .. "/" .. name .. ".json"
    local file = assert(io.open(filepath, "w+"))

    local serialized = json.encode(var)
    assert(file:write(serialized))

    file:close()
    return true
end

--Load function
function load_json(path, name)
    local filepath = path .. "/" .. name .. ".json"
    local file = assert(io.open(filepath, "rb"))

    local raw_text = file:read("*all")
    file:close()

    return json.decode(raw_text)
end