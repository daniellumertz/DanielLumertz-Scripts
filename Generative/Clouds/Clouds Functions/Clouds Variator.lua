--@noindex
Clouds = Clouds or {}
Clouds.Variator = {}

-- Table
Clouds.Variator.t = {
    version = SCRIPT_V,
    parameters = {
        chance = 100,
        percent = 10
    },
    envelopes = {

        is_edit = true,

        edit = {
            position = 10,
            value = 10,
            keep_shape = false -- keep envelope shape
        },

        gen = {
            n_points = {
                min = 10,
                max = 10
            },
            dust = 5,
            v_range = {
                min = 0,
                max = 1
            }
        }
    },
    GUI = {
        on = false,
        btn_w = 250,
    },
}

------ Each Variator
function Clouds.Variator.Hub(ctx, w, vtype, env_idx)
    if Clouds.Variator.t.GUI.on then 
        Clouds.Variator.Draw(ctx, w)
        -- Check if key is pressed
        if ImGui.IsItemHovered(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Mod_Ctrl, false) then
            for kct, ct in ipairs(CloudsTables) do
                if not env_idx then
                    Clouds.Variator[vtype](ct)
                else
                    Clouds.Variator.Envelope(ct, env_idx)
                end
            end
            reaper.UpdateArrange()
            reaper.Undo_OnStateChange_Item(Proj, 'Cloud: Variate '..(vtype or 'Envelopes'), CloudTable.cloud)
        end
    end
end

------- Envelopes
local function centered_range(min, max, center, percentage)
    local range = (max - min) * percentage
    -- Centralize range
    local range_start = math.max(min, center - (range/2)) 
    range_start = math.min(max - range, range_start)
    -- body
    return range_start, range_start + range
end

--- Get a target number and a series of numbers. Return a table with the closest values. close_values.closest, close_values.above, close_values.below
local function closest_number(target,...)
    local close_values = {}
    local dif_t = {}
    local numbers = {...}
    for k, v in pairs(numbers) do
        if type(v) ~= 'number' then goto continue end
        local dif = math.abs(v - target)

        if (dif < (dif_t.closest or math.huge)) then
            dif_t.closest = dif
            close_values.closest = v
        end

        local direction = v > target and 'above' or 'below'

        if dif < (dif_t[direction] or math.huge) then
            dif_t[direction] = dif
            close_values[direction] = v
        end
        ::continue::
    end
    return close_values
end

function Clouds.Variator.Envelope(ct, env_idx)
    local item = ct.cloud
    local take = reaper.GetActiveTake(item)
    Clouds.Item.EnsureFX(item)
    local env = reaper.TakeFX_GetEnvelope(take, 0, env_idx, false)
    if not env then return false end

    local ct_info = {
        length = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH'), 
        rate = reaper.GetMediaItemTakeInfo_Value(take, 'D_PLAYRATE'), 
        offset = reaper.GetMediaItemTakeInfo_Value(take, 'D_STARTOFFS') 
    }
    ct_info.content_length  = (ct_info.length * ct_info.rate)
    ct_info.content_end = ct_info.content_length + ct_info.offset
    if Clouds.Variator.t.envelopes.is_edit then -- Edit Points
        -- Make a table with all points values and position
        local points = {}
        for retval, time, value, shape, tension, selected, i in DL.enum.EnvelopePointEx(env, -1) do
            points[#points+1] = {pos = time, value = value} --  retval = retval, shape = shape, tension = tension, selected = selected
        end

        for k, point in ipairs(points) do
            -- Randomize Value (if keep shape, look the adjacent points)
            do
                local min, max = 0, 1
                if Clouds.Variator.t.envelopes.edit.keep_shape then
                    local prev = k > 1 and points[k-1].value
                    local next = k < #points and points[k+1].value

                    local values = closest_number(point.value, prev, next, min, max)
                    min = values.below or min
                    max = values.above or max
                end
                --randomize a new value
                local r_min, r_max = centered_range(min, max, point.value, Clouds.Variator.t.envelopes.edit.value/100) -- r = random
                local new_val = DL.num.RandomFloat(r_min, r_max, true)
                point.value = new_val
            end

            -- Randomize position
            do
                -- if the last point is after the end of the cloud item, skip it
                if  k == #points and ct_info.content_end < point.pos then
                    goto continue
                end

                local min, max
                min = k > 1 and points[k-1].pos or 0
                max = k < #points and points[k+1].pos or ct_info.content_end 

                local r_min, r_max = centered_range(min, max, point.pos, Clouds.Variator.t.envelopes.edit.position/100) -- r = random
                local new_pos = DL.num.RandomFloat(r_min, r_max, true)
                point.pos = new_pos
                ::continue::
            end
            -- Set point
            reaper.SetEnvelopePointEx(env, -1, k-1, point.pos, point.value, nil, nil, nil, true)
        end
    else -- Delete and Create new Points
        -- Delete
        local cnt = reaper.CountEnvelopePoints(env)
        for i = cnt -1, 0, -1 do
            reaper.DeleteEnvelopePointEx(env, -1, i)
        end 
        -- Create
        local dust = Clouds.Variator.t.envelopes.gen.dust
        local n_points = math.random(Clouds.Variator.t.envelopes.gen.n_points.min, Clouds.Variator.t.envelopes.gen.n_points.max) 
        local period = ct_info.content_length / n_points
        for i = 0, n_points-1 do
            -- Positionvv
            local pos = period * i
            if dust > 0 then
                local min, max = pos - (period*dust), pos + (period*dust)
                min, max = DL.num.Clamp(min, 0, ct_info.content_end), DL.num.Clamp(max, 0, ct_info.content_end)
                pos = DL.num.RandomFloat(min, max, true)
            end
            -- Value
            local val = DL.num.RandomFloat(Clouds.Variator.t.envelopes.gen.v_range.min, Clouds.Variator.t.envelopes.gen.v_range.max, true)
            reaper.InsertEnvelopePointEx(env, -1, pos, val, 0, 0, false, true) -- 0, 0 are shape and tension
        end
    end
    reaper.Envelope_SortPointsEx(env, -1)

    ::continue::
end




------- Parameters
---Variate a value between (value - (range * percent / 2), value + (range * percent / 2))
---@param value number value to change
---@param range number range it can change. It will be divided by 2. Half for going down, half for going up.
---@param percent number percent of the range it can change.
---@param chance number chance to change the value
---@param min number? min value
---@param max number? max value
---@return boolean --true if value was changed, false if not
---@return number --new value
function Clouds.Variator.VariateValueInRange(value, range, percent, chance, min, max)
    local percent = percent / 100
    if math.random(1, 100) <= chance then
        local min_rnd = value - (range * percent / 2)
        local max_rnd = value + (range * percent / 2)
        min_rnd = DL.num.Clamp(min_rnd, min, max)
        max_rnd = DL.num.Clamp(max_rnd, min, max)
        return true, DL.num.RandomFloat(min_rnd, max_rnd, true)
    end
    return false, value
end

function Clouds.Variator.density(ct)
    local change = false
    change, ct.density.density.val = Clouds.Variator.VariateValueInRange(ct.density.density.val, ct.density.density.val, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, 0)
    if change then
        ct.density.density.env_min =  DL.num.Clamp(ct.density.density.env_min, 0, ct.density.density.val)
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    return change
end

function Clouds.Variator.dust(ct)
    local change = false
    change, ct.density.random.val = Clouds.Variator.VariateValueInRange(ct.density.random.val, ct.density.random.val, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, 0)
    if change then
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    return change
end

function Clouds.Variator.cap(ct)
    local change = false
    change, ct.density.cap = Clouds.Variator.VariateValueInRange(ct.density.cap, ct.density.cap, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, 0)
    if change then
        ct.density.cap = DL.num.Clamp(ct.density.cap, 0) // 1
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    return change
end

function Clouds.Variator.n_gen(ct)
    local change = false
    change, ct.density.n_gen = Clouds.Variator.VariateValueInRange(ct.density.n_gen, ct.density.n_gen, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, 0)
    if change then
        ct.density.n_gen = DL.num.Clamp(ct.density.n_gen, 1) // 1
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    return change
end

function Clouds.Variator.grain_size(ct)
    local change = false
    change, ct.grains.size.val = Clouds.Variator.VariateValueInRange(ct.grains.size.val, ct.grains.size.val, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, 0)
    if change then
        ct.grains.size.val = DL.num.Clamp(ct.grains.size.val, CONSTRAINS.grain_low) // 1
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    return change
end

function Clouds.Variator.grain_drift_size(ct)
    local low = ct.grains.randomize_size.min
    local high = ct.grains.randomize_size.max
    local range = math.abs((high - low)) / 2
    local change1, min = Clouds.Variator.VariateValueInRange(low, range, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, CONSTRAINS.grain_rand_low)
    local change2, max = Clouds.Variator.VariateValueInRange(high, range, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, min)
    if change1 or change2 then
        if min > max then 
            min = max
        end
        ct.grains.randomize_size.min = min
        ct.grains.randomize_size.max = max
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    return change1, change2 
end

function Clouds.Variator.grain_position(ct)
    local change = false
    change, ct.grains.position.val = Clouds.Variator.VariateValueInRange(ct.grains.position.val, 100, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, 0, 100)
    if change then
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    return change
end

function Clouds.Variator.grain_position_drift(ct)
    local low = ct.grains.randomize_position.min
    local high = ct.grains.randomize_position.max
    local range = math.abs((high - low)) / 2
    local change1, min = Clouds.Variator.VariateValueInRange(low, range, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance)
    local change2, max = Clouds.Variator.VariateValueInRange(high, range, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, min)
    if change1 or change2 then
        if min > max then 
            min = max
        end
        ct.grains.randomize_position.min = min
        ct.grains.randomize_position.max = max
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    return change1, change2 
end

function Clouds.Variator.grain_fade(ct)
    local change = false
    change, ct.grains.fade.val = Clouds.Variator.VariateValueInRange(ct.grains.fade.val, 100, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, 0, 100)
    if change then
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    return change
end

function Clouds.Variator.envelope_volume(ct)
    local low = ct.envelopes.vol.min
    local high = ct.envelopes.vol.max
    local range = math.abs((high - low)) / 2
    local change1, min = Clouds.Variator.VariateValueInRange(low, range, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance)
    local change2, max = Clouds.Variator.VariateValueInRange(high, range, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, min)
    if change1 or change2 then
        if min > max then 
            min = max
        end
        ct.envelopes.vol.min = min
        ct.envelopes.vol.max = max
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    return change1, change2 
end

function Clouds.Variator.envelope_pan(ct)
    local low = ct.envelopes.pan.min
    local high = ct.envelopes.pan.max
    local range = math.abs((high - low)) / 2
    local change1, min = Clouds.Variator.VariateValueInRange(low, range, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, -1, 1)
    local change2, max = Clouds.Variator.VariateValueInRange(high, range, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, min, 1)
    if change1 or change2 then
        if min > max then 
            min = max
        end
        ct.envelopes.pan.min = min
        ct.envelopes.pan.max = max
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    return change1, change2 
end

function Clouds.Variator.envelope_pitch(ct)
    local low = ct.envelopes.pitch.min
    local high = ct.envelopes.pitch.max
    local range = math.abs((high - low)) / 2
    local change1, min = Clouds.Variator.VariateValueInRange(low, range, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance)
    local change2, max = Clouds.Variator.VariateValueInRange(high, range, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, min)
    if change1 or change2 then
        if min > max then 
            min = max
        end
        ct.envelopes.pitch.min = min
        ct.envelopes.pitch.max = max
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    return change1, change2 
end

function Clouds.Variator.envelope_stretch(ct)
    local low = ct.envelopes.stretch.min
    local high = ct.envelopes.stretch.max
    local range = math.abs((high - low)) / 2
    local change1, min = Clouds.Variator.VariateValueInRange(low, range, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, CONSTRAINS.stretch_low)
    local change2, max = Clouds.Variator.VariateValueInRange(high, range, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, min)
    if change1 or change2 then
        if min > max then 
            min = max
        end
        ct.envelopes.stretch.min = min
        ct.envelopes.stretch.max = max
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    return change1, change2 
end

function Clouds.Variator.random_volume(ct)
    local low = ct.randomization.vol.min
    local high = ct.randomization.vol.max
    local range = math.abs((high - low)) / 2
    local change1, min = Clouds.Variator.VariateValueInRange(low, range, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance)
    local change2, max = Clouds.Variator.VariateValueInRange(high, range, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, min)
    if change1 or change2 then
        if min > max then 
            min = max
        end
        ct.randomization.vol.min = min
        ct.randomization.vol.max = max
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    return change1, change2 
end

function Clouds.Variator.random_pan(ct)
    local low = ct.randomization.pan.min
    local high = ct.randomization.pan.max
    local range = math.abs((high - low)) / 2
    local change1, min = Clouds.Variator.VariateValueInRange(low, range, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, -1, 1)
    local change2, max = Clouds.Variator.VariateValueInRange(high, range, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, min, 1)
    if change1 or change2 then
        if min > max then 
            min = max
        end
        ct.randomization.pan.min = min
        ct.randomization.pan.max = max
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    return change1, change2 
end

function Clouds.Variator.random_pitch(ct)
    local low = ct.randomization.pitch.min
    local high = ct.randomization.pitch.max
    local range = math.abs((high - low)) / 2
    local change1, min = Clouds.Variator.VariateValueInRange(low, range, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance)
    local change2, max = Clouds.Variator.VariateValueInRange(high, range, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, min)
    if change1 or change2 then
        if min > max then 
            min = max
        end
        ct.randomization.pitch.min = min
        ct.randomization.pitch.max = max
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    return change1, change2 
end

function Clouds.Variator.random_stretch(ct)
    local low = ct.randomization.stretch.min
    local high = ct.randomization.stretch.max
    local range = math.abs((high - low)) / 2
    local change1, min = Clouds.Variator.VariateValueInRange(low, range, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, CONSTRAINS.stretch_low)
    local change2, max = Clouds.Variator.VariateValueInRange(high, range, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, min)
    if change1 or change2 then
        if min > max then 
            min = max
        end
        ct.randomization.stretch.min = min
        ct.randomization.stretch.max = max
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    return change1, change2 
end

function Clouds.Variator.random_reverse(ct)
    local change = false
    change, ct.randomization.reverse.val = Clouds.Variator.VariateValueInRange(ct.randomization.reverse.val, 100, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, 0, 100)
    if change then
        ct.randomization.reverse.val  = ct.randomization.reverse.val  // 1 
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
    return change
end

------- GUI
--- Draw functions
function Clouds.Variator.DrawRGBBlack(ctx, x, y, w, h, stroke, velocity)
    local stroke = stroke or 1
    local velocity = velocity or 1
    if Clouds.Variator.t.GUI.on then
        local dl = ImGui.GetWindowDrawList(ctx)                
        -- Create animated colors using HSV
        local time = (reaper.time_precise() % velocity) / velocity
        local hue = {0,.1}
        local col = {}
        for k, h in ipairs(hue) do
            h = (time + h) % 1.0
            local r,g,b = ImGui.ColorConvertHSVtoRGB(h, 0.75, 1.0)
            col[#col+1] = ImGui.ColorConvertDouble4ToU32(r, g, b, 1)
        end
        
        -- Draw the rectangle with animated colors
        DL.imgui.DrawList_AddRectMultiColor(dl, x, y, x+w, y+h, stroke, col[1], col[2], col[2], col[1])
    end    
end

local wt_hues = {0.7,0.88} -- white theme hues
function Clouds.Variator.DrawWhiteRGB(ctx, x, y, w, h, stroke, velocity)
    local stroke = stroke or 1
    local velocity = velocity or 1
    if Clouds.Variator.t.GUI.on then
        local dl = ImGui.GetWindowDrawList(ctx)                
        -- Create animated colors using HSV

        local col = {}
        for k, h in ipairs(wt_hues) do
            local raw_time = (reaper.time_precise() % velocity) / velocity
            if k == 2 then raw_time = (raw_time + 0.5) % 1 end
            local time = 1 - math.abs(2 * raw_time - 1)  -- Triangle wave function
            local c1 = DL.num.MapRange(time, 0, 1, wt_hues[1], wt_hues[2])
            local r, g, b = ImGui.ColorConvertHSVtoRGB(c1, 0.4, 1.0)
            col[#col+1] = ImGui.ColorConvertDouble4ToU32(r, g, b, 1)
        end
        
        -- Draw the rectangle with animated colors
        DL.imgui.DrawList_AddRectMultiColor(dl, x, y, x+w, y+h, stroke, col[1], col[2], col[2], col[1])
    end    
end

local gui = {}
function Clouds.Variator.Draw(ctx, w)
    -- Initialize
    if not gui.h then gui.h = ImGui.GetFrameHeight(ctx) end
    -- Draw stroke
    local x, y = ImGui.GetItemRectMin(ctx)
    if Settings.theme == 'Dark' then
        Clouds.Variator.DrawRGBBlack(ctx, x, y, w, gui.h, 1, 3.5)
    else
        Clouds.Variator.DrawWhiteRGB(ctx, x, y, w, gui.h, 2, 3.5)
    end 
end