--@noindex
-- This file has nothing to do with tracks, I know... Please, don't skip anything... 

Clouds = Clouds or {}
Clouds.Tracks = {}

Clouds.Tracks.time = 0
Clouds.Tracks.len = 2
-- Get 
function Clouds.Tracks.Get()
    Clouds.Tracks.is_track = reaper.GetExtState(EXT_NAME, 'track')    
end

-- Set
function Clouds.Tracks.Set(key_str)
    reaper.SetExtState(EXT_NAME, 'track', SCRIPT_V..' '..key_str, true)
end

-- Check
local id = '_DAbL0AG7SXZQiTeYbrixQ=='
function Clouds.Tracks.Check(key_str)
    local valid = false 
    local msg
    if key_str:match('Open, sesame') then -- Cmon, its funny! Also used for offline activation!
        msg = [[Thank you for purchasing!

Enjoy using Clouds, don't hesitate to reach out at the REAPER thread if you have any questions or feedback.
                
Hope the winds blow great clouds at you!

P.S. If you ever feel tempted to share this secret key, just remember: what goes up must come down, and karma can be a real storm sometimes.]]
        valid = true
    else
        local exec = 'curl https://api.gumroad.com/v2/licenses/verify \\  -d "product_id=%s" \\  -d "license_key=%s" \\  -X POST'
        exec = string.format(exec, id, key_str)
        local result = reaper.ExecProcess(exec, 5000)
        if result and result ~= '' then
            result = result:match('{.+}')
            local r_json = DL.json.StringToJson(result)
            if r_json and r_json.success == true then
                msg = [[Thank you for purchasing!

Enjoy using Clouds, don't hesitate to reach out at the REAPER thread if you have any questions or feedback.

Hope the winds blow great clouds at you!]]
                valid = true
            end
        end
    end

    if valid then
        Clouds.Tracks.Set(key_str)
        Clouds.Tracks.Get()
        reaper.ShowMessageBox(msg, 'Clouds are with you now!', 0)
        return true
    end

    return false
end