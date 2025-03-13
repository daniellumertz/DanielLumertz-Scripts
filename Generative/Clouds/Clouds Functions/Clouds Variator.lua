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
        keep_shape = false, -- keep envelope shape
        is_all = false,  -- apply to all active cloud
        range = {
            vertical = 10,
            horizontal = 10
        },

        gen = {
            n_points = 10,
            randomize = {
                range = {
                    vertical = 10,
                    horizontal = 10
                },
            }
        }
    },
    GUI = {
        on = false,
        btn_w = 250,
    },
}

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

--- Each Variator
function Clouds.Variator.Hub(ctx, w, vtype)
    if Clouds.Variator.t.GUI.on then 
        Clouds.Variator.Draw(ctx, w)
        -- Check if key is pressed
        if ImGui.IsItemHovered(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_V) then
            for kct, ct in ipairs(CloudsTables) do
                if vtype == 'density' then
                    Clouds.Variator.Density(ct)
                elseif vtype == 'dust' then
                    Clouds.Variator.Dust(ct)
                end
            end
        end
    end
end

function Clouds.Variator.Density(ct)
    local change = false
    change, ct.density.density.val = Clouds.Variator.VariateValueInRange(ct.density.density.val, ct.density.density.val, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, 0)
    if change then
        ct.density.density.env_min =  DL.num.Clamp(ct.density.density.env_min, 0, ct.density.density.val)
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
end

function Clouds.Variator.Dust(ct)
    local change = false
    change, ct.density.dust.val = Clouds.Variator.VariateValueInRange(ct.density.dust.val, ct.density.dust.val, Clouds.Variator.t.parameters.percent, Clouds.Variator.t.parameters.chance, 0)
    if change then
        Clouds.Item.SaveSettings(Proj, ct.cloud, ct)
    end
end

