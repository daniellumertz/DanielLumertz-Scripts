local configs = {}

function configs.Save(section, key, ct)
    local s_ct = DL.serialize.tableToString(ct)
    if s_ct then
        reaper.SetExtState(section, key, s_ct, true)
    else
        return false
    end
end

function configs.Load(section, key)
    local s_ct = reaper.GetExtState(section, key)
    if s_ct then
        return DL.serialize.stringToTable(s_ct)
    end
    return false    
end

function configs.default(version)
    return {
        version = version,
        tips = true,
        gui = {
            draw = {
                active = {
                    is_draw = true,
                    color = 0x13AB00FF,
                    thick = 2,
                    is_multicolor = false
                },
                focused = {
                    is_draw = true,
                    color = 0x8DFF8AFF,
                    thick = 3,
                    is_multicolor = false
                },
                target_tracks = {
                    is_draw = true,
                    color = 0xFFBD6BFF,
                    thick = 2,
                    is_multicolor = false
                },
                sources = {
                    is_draw = true,
                    color = 0xFF8A8AFF,
                    thick = 2,
                    is_multicolor = false
                }
            }
        }
    } 
end

return configs