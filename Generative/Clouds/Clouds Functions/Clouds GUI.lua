--@noindex
Clouds = Clouds or {}
Clouds.GUI = {}

-- Define GUI start variables
local ctx = ImGui.CreateContext(SCRIPT_NAME..SCRIPT_V)
local guiW, guiH = 375,600
local pin = false
--- Text Font
local font_text = ImGui.CreateFont('sans-serif', 14) -- Create the fonts you need
ImGui.Attach(ctx, font_text)-- Attach the fonts you need
--- Title Font
local font_title = ImGui.CreateFont('sans-serif', 24) 
ImGui.Attach(ctx, font_title)
--- Clipper
local clipper = ImGui.CreateListClipper(ctx)
ImGui.Attach(ctx, clipper)
--- Constants for GUI
local INT_MIN, INT_MAX = ImGui.NumericLimits_Int()
local FLT_MIN, FLT_MAX = ImGui.NumericLimits_Float()
local SLIDERS_W = 200
local SLIDERS_W2 = SLIDERS_W - (ImGui.GetFrameHeight(ctx) + 9)
local ENV_X = -60
local TAB_H = 150
local TABLE_W_COL = 75
local TABLE_FLAGS =     ImGui.TableFlags_ScrollY |
                        ImGui.TableFlags_RowBg           |
                        ImGui.TableFlags_BordersOuter    |
                        ImGui.TableFlags_BordersV        |
                        ImGui.TableFlags_NoSavedSettings |
                        ImGui.TableFlags_SizingStretchSame|
                        ImGui.TableFlags_ScrollX
local TOOLTIP_W = 300
local POPUPNAME = 'Buy Clouds'
local TIMER = {
    val = 15,
    last = reaper.time_precise()
}
Clouds.Tracks.Get()
local OPENBUYPOPUP = Clouds.Tracks.is_track == ''

-- Functions
local function tooltip(ctx, bol, text)
    if bol and ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_DelayNormal) then
        ImGui.SetNextWindowSize(ctx, ImGui.CalcTextSize(ctx, text), 0, ImGui.Cond_Appearing) 
        if ImGui.BeginTooltip(ctx) then
            ImGui.Text(ctx, text)
            ImGui.EndTooltip(ctx)
        end
    end 
end

local function chancepopup(chance, fx_id, conditions)
    local something_changed = false
    if conditions and ImGui.BeginPopupContextItem(ctx) then
        local change
        ImGui.SetNextItemWidth(ctx, 100)
        change, chance.val = ImGui.DragInt(ctx, 'Chance##'..fx_id, chance.val, nil, 0, 100, '%d%%')

        something_changed = something_changed or change 

        ImGui.SameLine(ctx)

        change, chance.env = Clouds.GUI.EnvCheck(conditions and chance.env, fx_id)
        something_changed = something_changed or change 
        ImGui.EndPopup(ctx)
    end

    if (not conditions) and chance.env then
        Clouds.Item.ShowHideEnvelope(conditions, fx_id)
        chance.env = false
    end

    return something_changed
end

-- Main Function
function Clouds.GUI.Main()
    --- Check selected Item for cloud items
    if FixedCloud then
        if not reaper.ValidatePtr2(Proj, FixedCloud, 'MediaItem*') then
            FixedCloud = nil
        end
    end
    
    Clouds.Item.CheckSelection(Proj)

    --- Keyboard shortcuts
    DL.imgui.SWSPassKeys(ctx, false)
    --- UI
    local window_flags = ImGui.WindowFlags_AlwaysAutoResize | ImGui.WindowFlags_MenuBar
    if pin then 
        window_flags = window_flags | ImGui.WindowFlags_TopMost
    end 
    
    Clouds.Themes[Settings.theme].Push(ctx)
    local pop_theme = Clouds.Themes[Settings.theme].Pop ---@type function Description

    --- Debug
    --demo.PushStyle(ctx)
    --demo.ShowDemoWindow(ctx)

    --- Window
    ImGui.SetNextWindowSize(ctx, guiW, guiH, ImGui.Cond_Once)
    ImGui.SetNextWindowSizeConstraints(ctx, guiW, 50, guiW, FLT_MAX)
    ImGui.PushFont(ctx, font_text)
    local visible, open = ImGui.Begin(ctx, SCRIPT_NAME..' '..SCRIPT_V, true, window_flags) 
    
    --- PopUp
    if OPENBUYPOPUP then
        OPENBUYPOPUP = nil
        ImGui.OpenPopup(ctx, POPUPNAME)
    end

    Clouds.GUI.BUY()
    local setting_change
    if visible then
        local ctrl = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)
        local alt = ImGui.IsKeyDown(ctx, ImGui.Mod_Alt)
        if ImGui.BeginMenuBar(ctx) then
            if ImGui.BeginMenu(ctx, "Settings") then
                local change = false
                -- Playback
                if ImGui.MenuItem(ctx, 'Stop Playback On Generate', nil, Settings.stop_playback) then
                    Settings.stop_playback = not Settings.stop_playback
                    setting_change = true
                end
                tooltip(ctx, Settings.tooltip, ToolTips.settings.stopongenerate)

                -- Erase
                if ImGui.MenuItem(ctx, 'Delete Only Overlapped Generations', nil, Settings.is_del_area) then
                    Settings.is_del_area = not Settings.is_del_area
                    setting_change = true
                end
                tooltip(ctx, Settings.tooltip, ToolTips.settings.is_del_area)

                -- Default Settings
                if ImGui.MenuItem(ctx, 'Default Settings') then
                    Settings = Clouds.Settings.Default()
                    setting_change = true
                end
                tooltip(ctx, Settings.tooltip, ToolTips.settings.default)

                ImGui.Separator(ctx)

                -- Tooltips
                change, Settings.tooltip= ImGui.MenuItem(ctx, 'Tooltips', nil, Settings.tooltip)
                setting_change = setting_change or change

                ImGui.Separator(ctx)
                -- Themes
                if ImGui.BeginMenu(ctx, 'Themes') then
                    for name, theme in pairs(Clouds.Themes) do
                        if ImGui.MenuItem(ctx, name..'##themeitem', nil, Settings.theme == name) and Settings.theme ~= name then
                            Settings.theme = name
                            setting_change = true
                        end
                    end

                    ImGui.EndMenu(ctx)
                end

                ImGui.EndMenu(ctx)
            end

            if ImGui.BeginMenu(ctx, "Actions") then
                if ImGui.MenuItem(ctx, 'Untag Selected Items') then
                    Clouds.Item.UntagSelected(Proj)
                end
                tooltip(ctx, Settings.tooltip, ToolTips.actions.untag)
                -- Delete
                ImGui.Separator(ctx)
                local which = ctrl and 'All' or 'Selected'
                if ImGui.MenuItem(ctx, string.format("Delete Generations at %s Clouds Position", which)) then
                    Clouds.Item.DeleteGenerations(Proj, not ctrl, true)
                end
                tooltip(ctx, Settings.tooltip, ToolTips.actions.deletepos)
                if ImGui.MenuItem(ctx, string.format('Delete All Generations from %s Clouds', which)) then
                    Clouds.Item.DeleteGenerations(Proj, not ctrl, false)
                end
                tooltip(ctx, Settings.tooltip, ToolTips.actions.delete)
                if ImGui.MenuItem(ctx, string.format('Delete All Generations', which)) then
                    Clouds.Item.DeleteAnyGeneration(Proj)
                end
                tooltip(ctx, Settings.tooltip, ToolTips.actions.deleteall)
                ImGui.EndMenu(ctx)
            end

            if ImGui.BeginMenu(ctx, 'About') then
                --[[ if ImGui.MenuItem(ctx, 'Manual') then
                    DL.url.OpenURL(URL.manual)
                end ]]
                if ImGui.MenuItem(ctx, 'Forum') then
                    DL.url.OpenURL(URL.thread)
                end
                if ImGui.MenuItem(ctx, 'Video') then
                    DL.url.OpenURL(URL.video)
                end

                ImGui.EndMenu(ctx)
            end

            if Clouds.Tracks.is_track == '' then
                local val = 4 *(Clouds.Tracks.time / Clouds.Tracks.len) * (1 - (Clouds.Tracks.time / Clouds.Tracks.len))
                val = 1/5 + (4 * (val / 5) )
                local col = ImGui.ColorConvertDouble4ToU32(1, 0.1, 0.1, val)
                ImGui.PushStyleColor(ctx, ImGui.Col_Text, col)
                if ImGui.MenuItem(ctx, "Buy Clouds!") then
                    OPENBUYPOPUP = true
                end
                ImGui.PopStyleColor(ctx)


                Clouds.Tracks.time = (Clouds.Tracks.time + (reaper.time_precise() - Clouds.Tracks.time)) % Clouds.Tracks.len
            end

            ImGui.EndMenuBar(ctx)
        end

        if CloudTable or CreatingClouds then
            local ww, wh = ImGui.GetWindowSize(ctx) -- window width, window hight
            ImGui.PushItemWidth(ctx, SLIDERS_W)
            local something_changed, change = false, nil
            -- Items
            if ImGui.CollapsingHeader(ctx, "Items##header") then
                tooltip(ctx, Settings.tooltip, ToolTips.items.head)
                if ImGui.Button(ctx, 'Set Items') then
                    Clouds.Item.SetItems(Proj)
                    something_changed = true
                end
                tooltip(ctx, Settings.tooltip, ToolTips.items.set)

                ImGui.SameLine(ctx)
                if ImGui.Button(ctx, 'Add Items') then
                    Clouds.Item.AddItems(Proj)
                    something_changed = true                    
                end
                tooltip(ctx, Settings.tooltip, ToolTips.items.add)

                ImGui.SameLine(ctx)
                if ImGui.Button(ctx, 'Select Items') then
                    Clouds.Item.SelectItems(Proj)
                end
                tooltip(ctx, Settings.tooltip, ToolTips.items.select)
                
                if ImGui.BeginTable(ctx, 'item_table', 2, TABLE_FLAGS, -FLT_MIN, TAB_H) then
                    ImGui.TableSetupScrollFreeze(ctx, 0, 1); -- Make top row always visible
                    ImGui.TableSetupColumn(ctx, 'Name', ImGui.TableColumnFlags_None,5)
                    ImGui.TableSetupColumn(ctx, 'Weight', ImGui.TableColumnFlags_WidthFixed, TABLE_W_COL)
                    ImGui.TableHeadersRow(ctx)
            
                    ImGui.ListClipper_Begin(clipper, #CloudTable.items)
                    while ImGui.ListClipper_Step(clipper) do
                        local display_start, display_end = ImGui.ListClipper_GetDisplayRange(clipper)
                        for row = display_start + 1, display_end do
                            local t = CloudTable.items[row]
                            ImGui.TableNextRow(ctx)
                            ImGui.TableNextColumn(ctx)

                            if t then
                                local item = t.item
                                local chance = t.chance
                                
                                local take = reaper.GetActiveTake(item)
                                local _, take_name = reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', '', false)
                                
                                ImGui.Text(ctx, take_name)
                                ImGui.SetNextWindowSize(ctx, 300, 0)
                                if #take_name > 40 and ImGui.IsItemHovered(ctx) and ImGui.BeginTooltip(ctx) then
                                    ImGui.TextWrapped(ctx, take_name)

                                    ImGui.EndTooltip(ctx)
                                end
                                ImGui.TableNextColumn(ctx)
                                --Chance Input
                                change, CloudTable.items[row].chance = ImGui.DragDouble(ctx, '##ItemChanceWeight'..row, CloudTable.items[row].chance, 0.05, 0, FLT_MAX, '%.1f')
                                tooltip(ctx, Settings.tooltip, ToolTips.items.w)
                                something_changed = something_changed or change
                                --Remove Button
                                ImGui.SameLine(ctx)
                                if ImGui.Button(ctx, 'X##itemremove'..row) then
                                    table.remove(CloudTable.items, row)
                                    something_changed = true
                                end
                                tooltip(ctx, Settings.tooltip, ToolTips.items.x)
                            end
                        end
                    end
                    ImGui.EndTable(ctx)
                end
            else
                tooltip(ctx, Settings.tooltip, ToolTips.items.head)
            end

            -- Density
            if (not CloudTable.midi_notes.is_synth) and ImGui.CollapsingHeader(ctx, "Density##header") then
                ----- Density
                change, CloudTable.density.density.val = ImGui.DragDouble(ctx, "Items/Second##Double", CloudTable.density.density.val, 0.05, 0, FLT_MAX)
                tooltip(ctx, Settings.tooltip, ToolTips.density.density.density)
                if ImGui.IsItemDeactivatedAfterEdit(ctx) then 
                    CloudTable.density.density.env_min =  DL.num.Clamp(CloudTable.density.density.env_min, 0, CloudTable.density.density.val)
                end
                something_changed = something_changed or change
                -- Right click
                if ImGui.BeginPopupContextItem(ctx, 'RatioDensity') then
                    TempRatioDensity = TempRatioDensity or (CloudTable.grains.size.val * CloudTable.density.density.val / 1000)*100
                    change, TempRatioDensity = ImGui.SliderInt(ctx, 'Grain Size / Density Ratio', math.floor(TempRatioDensity), 25, 200, '%.i%%')
                    tooltip(ctx, Settings.tooltip, ToolTips.density.density.density_ratio)
                    if ImGui.IsItemDeactivatedAfterEdit(ctx) then
                        CloudTable.density.density.val = (TempRatioDensity/100) * 1000 / CloudTable.grains.size.val 
                        something_changed = true
                    end
                    ImGui.EndPopup(ctx)
                elseif TempRatioDensity then
                    TempRatioDensity = nil
                end
                --Env
                ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, ww + ENV_X)
                change, CloudTable.density.density.envelope = Clouds.GUI.EnvCheck(CloudTable.density.density.envelope, FXENVELOPES.density, ToolTips.density.density.env)
                something_changed = something_changed or change
                if ImGui.BeginPopupContextItem(ctx,'densitymin') then
                    change, CloudTable.density.density.env_min = ImGui.SliderDouble(ctx, 'Min##SliderDensity', CloudTable.density.density.env_min, 0, CloudTable.density.density.val, nil, ImGui.SliderFlags_AlwaysClamp)
                    something_changed = something_changed or change
                    ImGui.EndPopup(ctx)
                end
                
                ----- Dust
                change, CloudTable.density.random.val = ImGui.DragDouble(ctx, "Dust##Slider", CloudTable.density.random.val, 0.01, 0, FLT_MAX)
                tooltip(ctx, Settings.tooltip, ToolTips.density.dust.dust)
                something_changed = something_changed or change
                --Env
                ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, ww + ENV_X)
                change, CloudTable.density.random.envelope = Clouds.GUI.EnvCheck(CloudTable.density.random.envelope, FXENVELOPES.dust, ToolTips.density.dust.env)
                something_changed = something_changed or change

                ----- Cap
                change, CloudTable.density.cap = ImGui.InputInt(ctx, 'Max N Items', CloudTable.density.cap)
                tooltip(ctx, Settings.tooltip, ToolTips.density.max)
                if ImGui.IsItemDeactivatedAfterEdit(ctx) then
                    CloudTable.density.cap = DL.num.Clamp(CloudTable.density.cap, 0)
                end
                something_changed = something_changed or change

                ----- Quantize
                change, CloudTable.density.quantize = ImGui.Checkbox(ctx, 'Quantize Items To Grid', CloudTable.density.quantize)
                something_changed = something_changed or change
            end

            -- Grains
            if ImGui.CollapsingHeader(ctx, "Grain##header") then
                tooltip(ctx, Settings.tooltip, ToolTips.grains.on)
                if not CloudTable.midi_notes.is_synth then
                    change, CloudTable.grains.on = ImGui.Checkbox(ctx, 'Cloud Grains', CloudTable.grains.on)
                    tooltip(ctx, Settings.tooltip, ToolTips.grains.on)
                    if change and not CloudTable.grains.on then
                        Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.grains.size)
                        Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.grains.randomize_size)
                        Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.grains.position)
                        Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.grains.randomize_position)
                    elseif change then
                        Clouds.Item.ShowHideEnvelope(CloudTable.grains.size.envelope,FXENVELOPES.grains.size)
                        Clouds.Item.ShowHideEnvelope(CloudTable.grains.randomize_size.envelope,FXENVELOPES.grains.randomize_size)
                        Clouds.Item.ShowHideEnvelope(CloudTable.grains.position.envelope,FXENVELOPES.grains.position)
                        Clouds.Item.ShowHideEnvelope(CloudTable.grains.randomize_position.envelope,FXENVELOPES.grains.randomize_position)
                    end
                    something_changed = something_changed or change
                end
                ImGui.BeginDisabled(ctx, not CloudTable.grains.on)

                ----- Size
                if not CloudTable.midi_notes.is_synth then
                    change, CloudTable.grains.size.val = ImGui.DragDouble(ctx, "Size##Double", CloudTable.grains.size.val, 1, CONSTRAINS.grain_low, FLT_MAX,'%.2f ms')
                    tooltip(ctx, Settings.tooltip, ToolTips.grains.size.size)
                    something_changed = something_changed or change
                    -- Right click
                    if ImGui.BeginPopupContextItem(ctx, 'RatioDensityGrain') then
                        TempRatioTime = TempRatioTime or (CloudTable.grains.size.val * CloudTable.density.density.val / 1000)*100
                        change, TempRatioTime = ImGui.SliderInt(ctx, 'Grain Size / Density Ratio', math.floor(TempRatioTime), 25, 200, '%.i%%')
                        tooltip(ctx, Settings.tooltip, ToolTips.grains.size.size_ratio)
                        if ImGui.IsItemDeactivatedAfterEdit(ctx) then
                            CloudTable.grains.size.val = (TempRatioTime/100) * 1000 / CloudTable.density.density.val
                            something_changed = true
                        end
                        ImGui.EndPopup(ctx)
                    elseif TempRatioTime then
                        TempRatioTime = nil
                    end
                    --Env
                    ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, ww + ENV_X)
                    change, CloudTable.grains.size.envelope = Clouds.GUI.EnvCheck(CloudTable.grains.size.envelope, FXENVELOPES.grains.size, ToolTips.grains.size.size_env)
                    something_changed = something_changed or change
                    if ImGui.BeginPopupContextItem(ctx,'Grainsmin') then
                        change, CloudTable.grains.size.env_min = ImGui.SliderDouble(ctx, 'Min##SliderGrains', CloudTable.grains.size.env_min, 0, CloudTable.grains.size.val, nil, ImGui.SliderFlags_AlwaysClamp)
                        something_changed = something_changed or change
                        ImGui.EndPopup(ctx)
                    end
                end

                ----- Drift Size
                --Checkbox
                change, CloudTable.grains.randomize_size.on = ImGui.Checkbox(ctx, '##DriftCheckbox', CloudTable.grains.randomize_size.on); ImGui.SameLine(ctx)
                tooltip(ctx, Settings.tooltip, ToolTips.grains.size_drift.on)
                if change and not CloudTable.grains.randomize_size.on then
                    Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.grains.randomize_size)         
                elseif change then
                    Clouds.Item.ShowHideEnvelope(CloudTable.grains.randomize_size.envelope,FXENVELOPES.grains.randomize_size)
                end
                something_changed = something_changed or change

                change = chancepopup(CloudTable.grains.randomize_size.chance, FXENVELOPES.grains.c_random_size, CloudTable.grains.randomize_size.on)
                something_changed = something_changed or change

                --Input
                ImGui.BeginDisabled(ctx, not CloudTable.grains.randomize_size.on)
                ImGui.SetNextItemWidth(ctx, SLIDERS_W2)
                local change, min, max = ImGui.DragDouble2(ctx, "Size Drift##randominput", CloudTable.grains.randomize_size.min, CloudTable.grains.randomize_size.max, 0.07, CONSTRAINS.grain_rand_low, FLT_MAX,'%.2f%%')
                tooltip(ctx, Settings.tooltip, ToolTips.grains.size_drift.size_drift)
                if change then -- clamp
                    if min > max then 
                        if min ~= CloudTable.grains.randomize_size.min then
                            max = min
                        else
                            min = max
                        end
                    end
                    CloudTable.grains.randomize_size.min = min
                    CloudTable.grains.randomize_size.max = max
                end
                something_changed = something_changed or change
                --Env
                ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, ww + ENV_X)
                change, CloudTable.grains.randomize_size.envelope = Clouds.GUI.EnvCheck(CloudTable.grains.randomize_size.envelope, FXENVELOPES.grains.randomize_size, ToolTips.grains.size_drift.env)
                something_changed = something_changed or change
                ImGui.EndDisabled(ctx)

                ----- Position
                --Checkbox
                change, CloudTable.grains.position.on = ImGui.Checkbox(ctx, '##PositionCheckbox', CloudTable.grains.position.on); ImGui.SameLine(ctx)
                tooltip(ctx, Settings.tooltip, ToolTips.grains.position.on)
                if change and not CloudTable.grains.position.on then
                    Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.grains.position)       
                    Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.grains.randomize_position)       
                elseif change then 
                    Clouds.Item.ShowHideEnvelope(CloudTable.grains.position.envelope,FXENVELOPES.grains.position)
                    Clouds.Item.ShowHideEnvelope(CloudTable.grains.randomize_position.envelope,FXENVELOPES.grains.randomize_position)
                end
                something_changed = something_changed or change
                ImGui.BeginDisabled(ctx, not CloudTable.grains.position.on)
                --Input
                ImGui.SetNextItemWidth(ctx, SLIDERS_W2)
                change, CloudTable.grains.position.val = ImGui.SliderDouble(ctx, "Position##Double", CloudTable.grains.position.val, 0, 100, '%.2f%%', ImGui.SliderFlags_AlwaysClamp)
                tooltip(ctx, Settings.tooltip, ToolTips.grains.position.position)
                something_changed = something_changed or change
                --Env
                ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, ww + ENV_X)
                change, CloudTable.grains.position.envelope = Clouds.GUI.EnvCheck(CloudTable.grains.position.envelope, FXENVELOPES.grains.position, ToolTips.grains.position.env)
                something_changed = something_changed or change
                ImGui.EndDisabled(ctx)

                ----- Position Drift
                --Checkbox
                ImGui.BeginDisabled(ctx, not CloudTable.grains.position.on)
                change, CloudTable.grains.randomize_position.on = ImGui.Checkbox(ctx, '##PositionDrift', CloudTable.grains.randomize_position.on); ImGui.SameLine(ctx)
                tooltip(ctx, Settings.tooltip, ToolTips.grains.position_drifts.on)
                if change and not CloudTable.grains.randomize_position.on then
                    Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.grains.randomize_position)       
                elseif change then
                    Clouds.Item.ShowHideEnvelope(CloudTable.grains.randomize_position.envelope,FXENVELOPES.grains.randomize_position)
                end
                something_changed = something_changed or change

                change = chancepopup(CloudTable.grains.randomize_position.chance, FXENVELOPES.grains.c_random_position, CloudTable.grains.position.on and CloudTable.grains.randomize_position.on)
                something_changed = something_changed or change

                --Input
                ImGui.BeginDisabled(ctx, not CloudTable.grains.randomize_position.on)
                ImGui.SetNextItemWidth(ctx, SLIDERS_W2)
                local change, min, max = ImGui.DragDouble2(ctx, "Position Drift##randominput", CloudTable.grains.randomize_position.min, CloudTable.grains.randomize_position.max, 1.4, -FLT_MAX, FLT_MAX, '%.2f ms')
                tooltip(ctx, Settings.tooltip, ToolTips.grains.position_drifts.drifts)
                if change then -- clamp
                    if min > max then 
                        if min ~= CloudTable.grains.randomize_position.min then
                            max = min
                        else
                            min = max
                        end
                    end
                    CloudTable.grains.randomize_position.min = min
                    CloudTable.grains.randomize_position.max = max
                end
                something_changed = something_changed or change
                --Env
                ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, ww + ENV_X)
                change, CloudTable.grains.randomize_position.envelope = Clouds.GUI.EnvCheck(CloudTable.grains.randomize_position.envelope, FXENVELOPES.grains.randomize_position, ToolTips.grains.position_drifts.env)
                something_changed = something_changed or change
                ImGui.EndDisabled(ctx) -- Drift
                ImGui.EndDisabled(ctx) -- Pos


                ----- Fade
                --Checkbox
                change, CloudTable.grains.fade.on = ImGui.Checkbox(ctx, '##fadegrian', CloudTable.grains.fade.on); ImGui.SameLine(ctx)
                something_changed = something_changed or change
                ImGui.BeginDisabled(ctx, not CloudTable.grains.fade.on)
                tooltip(ctx, Settings.tooltip, ToolTips.grains.fade)
                --Input
                ImGui.SetNextItemWidth(ctx, SLIDERS_W2)
                change, CloudTable.grains.fade.val = ImGui.SliderDouble(ctx, "Fade##Double", CloudTable.grains.fade.val, 0, 100, '%.2f%%', ImGui.SliderFlags_AlwaysClamp) 
                tooltip(ctx, Settings.tooltip, ToolTips.grains.fade)
                something_changed = something_changed or change
                ImGui.EndDisabled(ctx)
                ImGui.EndDisabled(ctx)
            else
                tooltip(ctx, Settings.tooltip, ToolTips.grains.on)
            end

            if ImGui.CollapsingHeader(ctx, 'MIDI Notes') then
                if not CloudTable.midi_notes.is_synth then
                    ImGui.SeparatorText(ctx, 'Transpose Mode')
                    change, CloudTable.midi_notes.solo_notes = ImGui.Checkbox(ctx, 'Only Generate Items at Notes', CloudTable.midi_notes.solo_notes)
                    tooltip(ctx, Settings.tooltip, ToolTips.midi.solo_notes)
                    something_changed = something_changed or change
                    ------ EDO Tuning
                    change, CloudTable.midi_notes.EDO = ImGui.InputInt(ctx, 'Tuning EDO', CloudTable.midi_notes.EDO, 0, 0)
                    tooltip(ctx, Settings.tooltip, ToolTips.midi.edo)
                    something_changed = something_changed or change
                    -- Clamp
                    if ImGui.IsItemDeactivatedAfterEdit(ctx) then CloudTable.midi_notes.EDO = ((CloudTable.midi_notes.EDO > 0) and CloudTable.midi_notes.EDO) or 1 end

                    change, CloudTable.midi_notes.center = ImGui.InputInt(ctx, 'MIDI Center', CloudTable.midi_notes.center, 0, 0)
                    tooltip(ctx, Settings.tooltip, ToolTips.midi.center)
                    something_changed = something_changed or change
                    if ImGui.IsItemDeactivatedAfterEdit(ctx) then CloudTable.midi_notes.center = ((CloudTable.midi_notes.center >= 0) and CloudTable.midi_notes.center) or 0 end
                end
                ImGui.SeparatorText(ctx, 'Synth Mode')
                ----- Synth
                change, CloudTable.midi_notes.is_synth = ImGui.Checkbox(ctx, 'On', CloudTable.midi_notes.is_synth)
                tooltip(ctx, Settings.tooltip, ToolTips.midi.synth.synth)
                if change and CloudTable.midi_notes.is_synth then
                    CloudTable.grains.on = true
                    Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.grains.size)
                    Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.density)
                    Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.dust)
                elseif change and not CloudTable.midi_notes.is_synth then
                    Clouds.Item.ShowHideEnvelope(CloudTable.grains.size.envelope, FXENVELOPES.grains.size)
                    Clouds.Item.ShowHideEnvelope(CloudTable.density.density.envelope,FXENVELOPES.density)
                    Clouds.Item.ShowHideEnvelope(CloudTable.density.random.envelope,FXENVELOPES.dust)
                end
                something_changed = something_changed or change

                if CloudTable.midi_notes.is_synth then
                    -- Tuning 
                    change, CloudTable.midi_notes.EDO = ImGui.InputInt(ctx, 'Tuning EDO', CloudTable.midi_notes.EDO, 0, 0)
                    tooltip(ctx, Settings.tooltip, ToolTips.midi.edo)
                    something_changed = something_changed or change
                    -- Clamp
                    if ImGui.IsItemDeactivatedAfterEdit(ctx) then CloudTable.midi_notes.EDO = ((CloudTable.midi_notes.EDO > 0) and CloudTable.midi_notes.EDO) or 1 end
                    -- A4
                    change, CloudTable.midi_notes.A4 = ImGui.InputInt(ctx, 'A4', CloudTable.midi_notes.A4, 0, 0)
                    tooltip(ctx, Settings.tooltip, ToolTips.midi.a4)
                    something_changed = something_changed or change
                    if ImGui.IsItemDeactivatedAfterEdit(ctx) then CloudTable.midi_notes.A4 = ((CloudTable.midi_notes.A4 > 0) and CloudTable.midi_notes.A4) or 1 end
                    -- Min Vol
                    change, CloudTable.midi_notes.synth.min_vol = ImGui.DragDouble(ctx, 'Min Volume', CloudTable.midi_notes.synth.min_vol, 0.1, -FLT_MAX, 0,'%.2f dB')
                    tooltip(ctx, Settings.tooltip, ToolTips.midi.synth.min_vol)
                    something_changed = something_changed or change
                    -- Hold Position
                    change, CloudTable.midi_notes.synth.hold_pos = ImGui.Checkbox(ctx, 'Hold Position', CloudTable.midi_notes.synth.hold_pos)
                    tooltip(ctx, Settings.tooltip, ToolTips.midi.synth.hold_pos)
                    something_changed = something_changed or change
                end
            end

            -- Randomization
            if ImGui.CollapsingHeader(ctx, "Randomization##header") then
                ----- Volume
                --Checkbox
                change, CloudTable.randomization.vol.on = ImGui.Checkbox(ctx, '##VolumeCheckbox', CloudTable.randomization.vol.on); ImGui.SameLine(ctx)
                tooltip(ctx, Settings.tooltip, ToolTips.randomization.volume.on)
                if change and not CloudTable.randomization.vol.on then
                    Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.randomization.vol)       
                elseif change then
                    Clouds.Item.ShowHideEnvelope(CloudTable.randomization.vol.envelope,FXENVELOPES.randomization.vol)
                end
                something_changed = something_changed or change

                change = chancepopup(CloudTable.randomization.vol.chance, FXENVELOPES.randomization.c_vol, CloudTable.randomization.vol.on)
                something_changed = something_changed or change

                --Input
                ImGui.BeginDisabled(ctx, not CloudTable.randomization.vol.on)
                ImGui.SetNextItemWidth(ctx, SLIDERS_W2)
                local change, min, max = ImGui.DragDouble2(ctx, "Volume##randominput", CloudTable.randomization.vol.min, CloudTable.randomization.vol.max, 0.07, -CONSTRAINS.db_minmax+1, FLT_MAX, '%.2f dB')
                if change then -- clamp
                    min = min < -CONSTRAINS.db_minmax+1 and -CONSTRAINS.db_minmax+1 or min
                    max = max < -CONSTRAINS.db_minmax+1 and -CONSTRAINS.db_minmax+1 or max
                    if min > max then 
                        if min ~= CloudTable.randomization.vol.min then
                            max = min
                        else
                            min = max
                        end
                    end
                    CloudTable.randomization.vol.min = min
                    CloudTable.randomization.vol.max = max
                end
                something_changed = something_changed or change
                --Env
                ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, ww + ENV_X)
                change, CloudTable.randomization.vol.envelope = Clouds.GUI.EnvCheck(CloudTable.randomization.vol.envelope, FXENVELOPES.randomization.vol, ToolTips.randomization.volume.env)
                something_changed = something_changed or change
                ImGui.EndDisabled(ctx)

                ----- Pan
                --Checkbox
                change, CloudTable.randomization.pan.on = ImGui.Checkbox(ctx, '##PanCheckbox', CloudTable.randomization.pan.on); ImGui.SameLine(ctx)
                tooltip(ctx, Settings.tooltip, ToolTips.randomization.pan.on)
                if change and not CloudTable.randomization.pan.on then
                    Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.randomization.pan)       
                elseif change then
                    Clouds.Item.ShowHideEnvelope(CloudTable.randomization.pan.envelope,FXENVELOPES.randomization.pan)
                end
                something_changed = something_changed or change

                change = chancepopup(CloudTable.randomization.pan.chance, FXENVELOPES.randomization.c_pan, CloudTable.randomization.pan.on)
                something_changed = something_changed or change

                --Input
                ImGui.BeginDisabled(ctx, not CloudTable.randomization.pan.on)
                ImGui.SetNextItemWidth(ctx, SLIDERS_W2)
                local change, min, max = ImGui.DragDouble2(ctx, "Pan##randominput", CloudTable.randomization.pan.min, CloudTable.randomization.pan.max, 0.01, -1, 1, '%.2f')
                if change then -- clamp
                    min = DL.num.Clamp(min, -1, 1)
                    max = DL.num.Clamp(max, -1, 1)
                    if min > max then 
                        if min ~= CloudTable.randomization.pan.min then
                            max = min
                        else
                            min = max
                        end
                    end
                    CloudTable.randomization.pan.min = min
                    CloudTable.randomization.pan.max = max
                end
                something_changed = something_changed or change
                --Env
                ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, ww + ENV_X)
                change, CloudTable.randomization.pan.envelope = Clouds.GUI.EnvCheck(CloudTable.randomization.pan.envelope, FXENVELOPES.randomization.pan, ToolTips.randomization.pan.env)
                something_changed = something_changed or change
                ImGui.EndDisabled(ctx)

                ----- Pitch
                --Checkbox
                change, CloudTable.randomization.pitch.on = ImGui.Checkbox(ctx, '##PitchCheckbox', CloudTable.randomization.pitch.on); ImGui.SameLine(ctx)
                tooltip(ctx, Settings.tooltip, ToolTips.randomization.pitch.on)
                if change and not CloudTable.randomization.pitch.on then
                    Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.randomization.pitch)       
                elseif change then
                    Clouds.Item.ShowHideEnvelope(CloudTable.randomization.pitch.envelope,FXENVELOPES.randomization.pitch)
                end
                something_changed = something_changed or change

                change = chancepopup(CloudTable.randomization.pitch.chance, FXENVELOPES.randomization.c_pitch, CloudTable.randomization.pitch.on)
                something_changed = something_changed or change

                --Input
                ImGui.BeginDisabled(ctx, not CloudTable.randomization.pitch.on)
                ImGui.SetNextItemWidth(ctx, SLIDERS_W2)
                change, min, max = ImGui.DragDouble2(ctx, "Pitch##randominput", CloudTable.randomization.pitch.min, CloudTable.randomization.pitch.max, 0.02, -FLT_MAX, FLT_MAX, '%.2f')
                if change then -- clamp
                    if min > max then 
                        if min ~= CloudTable.randomization.pitch.min then
                            max = min
                        else
                            min = max
                        end
                    end
                    CloudTable.randomization.pitch.min = min
                    CloudTable.randomization.pitch.max = max
                end
                something_changed = something_changed or change
                -- Quantize popup
                if ImGui.BeginPopupContextItem(ctx, 'Quantize Pitch') then
                    ImGui.SetNextItemWidth(ctx, SLIDERS_W/2)
                    change, CloudTable.randomization.pitch.quantize = ImGui.InputInt(ctx, 'Quantize Pitch (cents)', CloudTable.randomization.pitch.quantize,0,0)
                    something_changed = something_changed or change
                    ImGui.EndPopup(ctx)
                end
                --Env
                ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, ww + ENV_X)
                change, CloudTable.randomization.pitch.envelope = Clouds.GUI.EnvCheck(CloudTable.randomization.pitch.envelope, FXENVELOPES.randomization.pitch, ToolTips.randomization.pitch.env)
                something_changed = something_changed or change
                ImGui.EndDisabled(ctx)

                ----- Stretch
                --Checkbox
                change, CloudTable.randomization.stretch.on = ImGui.Checkbox(ctx, '##StretchCheckbox', CloudTable.randomization.stretch.on); ImGui.SameLine(ctx)
                tooltip(ctx, Settings.tooltip, ToolTips.randomization.playrate.on)
                if change and not CloudTable.randomization.stretch.on then
                    Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.randomization.stretch)       
                elseif change then
                    Clouds.Item.ShowHideEnvelope(CloudTable.randomization.stretch.envelope,FXENVELOPES.randomization.stretch)
                end
                something_changed = something_changed or change

                change = chancepopup(CloudTable.randomization.stretch.chance, FXENVELOPES.randomization.c_stretch, CloudTable.randomization.stretch.on)
                something_changed = something_changed or change

                --Input
                ImGui.BeginDisabled(ctx, not CloudTable.randomization.stretch.on)
                ImGui.SetNextItemWidth(ctx, SLIDERS_W2)
                local format_str =  CloudTable.randomization.stretch.min < 0.01 and '%.3f x' or '%.2f x'
                local change, min, max = ImGui.DragDouble2(ctx, "Playrate##randominput", CloudTable.randomization.stretch.min, CloudTable.randomization.stretch.max, 0.0009, CONSTRAINS.stretch_low, FLT_MAX, format_str)
                something_changed = something_changed or change
                if change then -- clamp
                    min = min < CONSTRAINS.stretch_low and CONSTRAINS.stretch_low or min
                    max = max < CONSTRAINS.stretch_low and CONSTRAINS.stretch_low or max
                    if min > max then 
                        if min ~= CloudTable.randomization.stretch.min then
                            max = min
                        else
                            min = max
                        end
                    end
                    CloudTable.randomization.stretch.min = min
                    CloudTable.randomization.stretch.max = max
                end
                --Env
                ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, ww + ENV_X)
                change, CloudTable.randomization.stretch.envelope = Clouds.GUI.EnvCheck(CloudTable.randomization.stretch.envelope, FXENVELOPES.randomization.stretch, ToolTips.randomization.playrate.env)
                something_changed = something_changed or change
                ImGui.EndDisabled(ctx)

                ----- Reverse
                --Checkbox
                change, CloudTable.randomization.reverse.on = ImGui.Checkbox(ctx, '##ReverserCheckbox', CloudTable.randomization.reverse.on); ImGui.SameLine(ctx)
                tooltip(ctx, Settings.tooltip, ToolTips.randomization.reverse.on)
                if change and not CloudTable.randomization.reverse.on then
                    Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.randomization.reverse)       
                elseif change then
                    Clouds.Item.ShowHideEnvelope(CloudTable.randomization.reverse.envelope,FXENVELOPES.randomization.reverse)
                end
                something_changed = something_changed or change

                --Input
                ImGui.BeginDisabled(ctx, not CloudTable.randomization.reverse.on)
                ImGui.SetNextItemWidth(ctx, SLIDERS_W2)
                change, CloudTable.randomization.reverse.val = ImGui.SliderInt(ctx, "Reverse##randominput", CloudTable.randomization.reverse.val, 0, 100, '%i%%', ImGui.SliderFlags_AlwaysClamp)
                --change, CloudTable.randomization.reverse.val = ImGui.InputDouble(ctx, "Reverse##randominput", CloudTable.randomization.reverse.val, nil, nil, '%.2f %')
                if ImGui.IsItemDeactivatedAfterEdit(ctx) then -- clamp
                    CloudTable.randomization.reverse.val = DL.num.Clamp(CloudTable.randomization.reverse.val, 0, 100)
                end
                something_changed = something_changed or change
                --Env
                ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, ww + ENV_X)
                change, CloudTable.randomization.reverse.envelope = Clouds.GUI.EnvCheck(CloudTable.randomization.reverse.envelope, FXENVELOPES.randomization.reverse, ToolTips.randomization.reverse.env)
                something_changed = something_changed or change
                ImGui.EndDisabled(ctx)
            end

            -- Tracks
            if ImGui.CollapsingHeader(ctx, "Tracks##header") then
                tooltip(ctx, Settings.tooltip, ToolTips.tracks.head) 
                if ImGui.Button(ctx, 'Set Tracks') then
                    Clouds.Item.SetTracks(Proj)
                    something_changed = true
                end
                tooltip(ctx, Settings.tooltip, ToolTips.tracks.set)
                ImGui.SameLine(ctx)
                if ImGui.Button(ctx, 'Add Tracks') then
                    Clouds.Item.AddTracks(Proj)
                    something_changed = true                    
                end
                tooltip(ctx, Settings.tooltip, ToolTips.tracks.add) 
                ImGui.SameLine(ctx)
                if ImGui.Button(ctx, 'Select Tracks') then
                    Clouds.Item.SelectTracks(Proj)
                end
                tooltip(ctx, Settings.tooltip, ToolTips.tracks.select) 
                if ImGui.BeginTable(ctx, 'track_table', 2, TABLE_FLAGS, -FLT_MIN, TAB_H) then
                    ImGui.TableSetupScrollFreeze(ctx, 0, 1); -- Make top row always visible
                    ImGui.TableSetupColumn(ctx, 'Name', ImGui.TableColumnFlags_None,5)
                    ImGui.TableSetupColumn(ctx, 'Weight', ImGui.TableColumnFlags_WidthFixed, TABLE_W_COL)
                    ImGui.TableHeadersRow(ctx)
            
                    ImGui.ListClipper_Begin(clipper, #CloudTable.tracks + 1)
                    while ImGui.ListClipper_Step(clipper) do
                        local display_start, display_end = ImGui.ListClipper_GetDisplayRange(clipper)
                        for row = display_start, display_end-1 do
                            local t
                            if row == 0 then 
                                t = CloudTable.tracks.self
                            else
                                t = CloudTable.tracks[row]
                            end
                            ImGui.TableNextRow(ctx)
                            ImGui.TableNextColumn(ctx)

                            if t then
                                local track = t.track
                                local chance = t.chance
                                
                                local _, track_name
                                if track then
                                    _, track_name = reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', '', false)
                                    track_name = track_name ~= '' and track_name or 'Track '..string.format("%.0f", reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER'))
                                else
                                    track_name = 'self'
                                end
                                
                                ImGui.Text(ctx, track_name)
                                ImGui.SetNextWindowSize(ctx, 300, 0)
                                if #track_name > 40 and ImGui.IsItemHovered(ctx) and ImGui.BeginTooltip(ctx) then
                                    ImGui.TextWrapped(ctx, track_name)

                                    ImGui.EndTooltip(ctx)
                                end

                                ImGui.TableNextColumn(ctx)
                                --Chance Input
                                change, t.chance = ImGui.DragDouble(ctx, '##trackChanceWeight'..row, t.chance, 0.05, 0, FLT_MAX, '%.1f')
                                tooltip(ctx, Settings.tooltip, ToolTips.tracks.w) 
                                something_changed = something_changed or change
                                --Remove Button
                                ImGui.SameLine(ctx)
                                if row ~= 0 then
                                    if ImGui.Button(ctx, 'X##trackremove'..row) then
                                        table.remove(CloudTable.tracks, row)
                                        something_changed = true
                                    end
                                    tooltip(ctx, Settings.tooltip, ToolTips.tracks.x)
                                end
                            end
                        end
                    end
                    ImGui.EndTable(ctx)
                end
            else
                tooltip(ctx, Settings.tooltip, ToolTips.tracks.head) 
            end
            
            

            ImGui.PopItemWidth(ctx)

            ImGui.Separator(ctx)

            -- Fixcloud Checkbox
            local change, val = ImGui.Checkbox(ctx, 'Pin Cloud', (FixedCloud ~= nil))
            tooltip(ctx, Settings.tooltip, ToolTips.buttons.fix)
            if change and val and CloudTable.cloud then
                FixedCloud = CloudTable.cloud
            elseif change then
                FixedCloud = nil
            end
            
            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, 'Copy Settings') then
                CopySettings = DL.t.DeepCopy(CloudTable)
            end
            tooltip(ctx, Settings.tooltip, ToolTips.buttons.copy)

            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, 'Paste Settings') and CopySettings then
                Clouds.Item.Paste(true)
            end
            tooltip(ctx, Settings.tooltip, ToolTips.buttons.paste)


            ImGui.SameLine(ctx)
            ImGui.SetNextItemWidth(ctx, -FLT_MIN)
            if ImGui.BeginCombo(ctx, '##PresetsCombo', 'Presets') then
                if not Presets then
                    Presets = Clouds.Presets.LoadTable(PRESETS.path)
                    PresetName = PRESETS.suggestions[PRESETS.i + 1]
                    PRESETS.i = (PRESETS.i + 1) % #PRESETS.suggestions
                end

                for idx, preset in ipairs(Presets) do
                    local name = preset.name
                    if ImGui.Selectable(ctx, name) then
                        reaper.PreventUIRefresh(1)
                        reaper.Undo_BeginBlock2(Proj)
                        local bol = Clouds.Presets.Load(preset.path)
                        Clouds.Item.ShowHideAllEnvelopes()
                        something_changed = something_changed or bol
                        reaper.Undo_EndBlock2(Proj, 'Clouds: Load Preset', -1)
                        reaper.PreventUIRefresh(-1)
                    end
                end

                ImGui.Separator(ctx)
                local _
                --_, PresetName = ImGui.InputText(ctx, 'Preset Name', PresetName)
                if ImGui.Button(ctx, 'Save', -FLT_MIN) then
                    local retval, fileName = reaper.JS_Dialog_BrowseForSaveFile( 'Save Cloud Preset', PRESETS.path, PresetName..'.json', '' )
                    if retval ~= 0 then
                        Clouds.Presets.SavePreset(fileName, CloudTable)
                    end
                end
                
                ImGui.EndCombo(ctx)
            elseif Presets then 
                Presets = nil
            end


            -- Apply Buttons
            -- Standard = Generate Clouds for selected clouds. Erasing existing items
            -- with Alt = + Don't Erase Previous Items
            -- with Ctrl = + All Clouds at the project  
            local text_help = 'Generate Clouds for'
            if not ctrl then
                text_help = text_help..' selected cloud items'
            else
                text_help = text_help..' all cloud items'
            end

            if not alt then
                text_help = text_help..', deleting previous clouds'
            end
            text_help = text_help .. '.\nCtrl or/and Alt for more options!'

            if ImGui.Button(ctx, 'Generate!', -FLT_MIN) then
                CreatingClouds = coroutine.wrap(Clouds.apply.GenerateClouds)
                --Clouds.apply.GenerateClouds(Proj, not ctrl, not alt)                    
            end
            ImGui.SetItemTooltip(ctx, text_help)
            if ImGui.BeginPopupContextItem(ctx, '') then
                local w = 200
                ImGui.Text(ctx, 'Fix Seed:')
                ImGui.SetNextItemWidth(ctx, w)
                something_changed, CloudTable.seed.seed = ImGui.InputInt(ctx, '##Fix Seed', CloudTable.seed.seed, 0, 0)

                ImGui.Text(ctx, 'Print N Seeds:')
                ImGui.SetNextItemWidth(ctx, w)
                setting_change, Settings.seed_print = ImGui.InputInt(ctx, '##Print Number', Settings.seed_print, 0, 0)

                if ImGui.Button(ctx, 'Print Seed History', w) then
                    Clouds.Item.PrintSeedHistory(CloudTable)
                end
                ImGui.EndPopup(ctx)
            end    

            -- Progress Bar
            if CreatingClouds then
                local is_finished, clouds, items = CreatingClouds(Proj, not ctrl, not alt)
                if is_finished then
                    CancelCreatingClouds = nil
                    CreatingClouds = nil
                else
                    ImGui.ProgressBar(ctx,  items.done/items.total, -FLT_MIN)
                    if ImGui.Button(ctx, 'Cancel', -FLT_MIN) then
                        CancelCreatingClouds = true
                    end
                end
            end

            -- Save
            if something_changed then
                --Clouds.Item.CheckEnvelopes(Proj)
                Clouds.Item.SaveSettings(Proj, CloudTable.cloud, CloudTable)
                reaper.UpdateArrange()
                reaper.Undo_OnStateChange_Item(Proj, 'Cloud: Change Setting', CloudTable.cloud)
            end
        else
            if ImGui.Button(ctx, 'Create Cloud Item', -FLT_MIN) then
                Clouds.Item.Create(Proj)
            end
            tooltip(ctx, Settings.tooltip, ToolTips.create_item)
        end
        ImGui.End(ctx)
    end

    
    if setting_change then
        Clouds.Settings.Save(SETTINGS.path, Settings)
    end

    ImGui.PopFont(ctx)
    --demo.PopStyle(ctx)
    pop_theme(ctx)
    --Clouds.Themes[Settings.theme].Pop(ctx)

    if open then
        reaper.defer(Clouds.GUI.Main)
    end
end

function Clouds.GUI.EnvCheck(val, env_n, tip)
    local something_changed = false
    --Env
    if ImGui.Checkbox(ctx, "Env##"..env_n, val) then
        val = not val
        Clouds.Item.ShowHideEnvelope(val, env_n)
        something_changed = true
    end
    if tip then 
        tooltip(ctx, Settings.tooltip, tip)
    end
    return something_changed, val
end

function Clouds.GUI.BuyPopUp(ctx, time)
    if ImGui.BeginPopupModal(ctx, 'Buy Clouds') then

        ImGui.EndPopup(ctx)
    end    
end

function Clouds.GUI.BUY()
    -- Always center this window when appearing
    ImGui.SetNextWindowSize(ctx, 350, 0, ImGui.Cond_Appearing)
    local center_x, center_y = ImGui.Viewport_GetCenter(ImGui.GetWindowViewport(ctx))
    local x, y = ImGui.Viewport_GetPos(ImGui.GetWindowViewport(ctx))
    ImGui.SetNextWindowPos(ctx, center_x, y, nil, 0.5, 0)
    local popflags = ImGui.WindowFlags_NoResize
    if ImGui.BeginPopupModal(ctx, POPUPNAME, nil, popflags) then
        if TIMER.val > 0 then
            local now = reaper.time_precise()
            TIMER.val = TIMER.val - (now - TIMER.last)
            TIMER.last = now
        end

        if not DAYS_EVAL then
            local first_day = reaper.GetExtState(EXT_NAME, 'first_run') ---@type string | number? 
            if first_day == '' then
                first_day = os.time(os.date("*t"))
                reaper.SetExtState(EXT_NAME, 'first_run', tostring(first_day), true)
            else
                first_day = tonumber(first_day)
            end
            local diff_in_seconds = os.difftime(os.time(), first_day)
            DAYS_EVAL = math.floor(diff_in_seconds / (24 * 60 * 60))
        end 
        
        ImGui.TextWrapped(ctx, string.format("Clouds is not free!\n\nIf you use it more than 7 days you are required to purchase a license.\n\nYou have been evaluating Clouds for approximately %d days.",DAYS_EVAL))

        ImGui.Separator(ctx)
        ImGui.TextWrapped(ctx, 'Insert Serial Key:')
        ImGui.SetNextItemWidth(ctx, 275)
        local _
        _, TrySerial = ImGui.InputText(ctx, '##serialinput', TrySerial or '')
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, 'Apply', -FLT_MIN) then
            local bol = Clouds.Tracks.Check(TrySerial)
            if bol then
                ImGui.CloseCurrentPopup(ctx)
            else
                reaper.ShowMessageBox("Hmmm. Serial key incorrect.\nTry again, check if everything is copied correctly, if problem persist contact me at the thread or via e-mail!", 'Clouds', 0)
            end
        end

        ImGui.Separator(ctx)

        -- Buy Button
        if ImGui.Button(ctx, 'Buy Clouds!',-FLT_MIN) then
            DL.url.OpenURL(URL.buy)
        end
        
        -- Skip Button
        local text
        if TIMER.val > 0 then 
            ImGui.BeginDisabled(ctx)
            text = 'Wait '..tostring(math.floor(TIMER.val))
        else 
            text = 'Continue'
        end
        if ImGui.Button(ctx, text, -FLT_MIN) then
            ImGui.CloseCurrentPopup(ctx)
        end
        if TIMER.val > 0 then ImGui.EndDisabled(ctx) end

        ImGui.EndPopup(ctx)
    end     
end


function Clouds.GUI.Guiless(proj, is_selection, is_delete)
    local w, h = 300, 80
    local gap = 15
    ImGui.SetNextWindowSize(ctx, w, h, ImGui.Cond_Once)
    ImGui.PushFont(ctx, font_text)
    Clouds.Themes[Settings.theme].Push(ctx)
    --local win_flags = ImGui.WindowFlags_AlwaysAutoResize
    local visible, open = ImGui.Begin(ctx, SCRIPT_NAME, false, ImGui.WindowFlags_NoResize | ImGui.WindowFlags_NoCollapse)
    if visible then
        local is_finished, clouds, items = CreatingClouds(proj, is_selection, is_delete)
        -- defer until ready
        if not is_finished and open then
            ImGui.ProgressBar(ctx,  items.done/items.total, w - gap)
            if ImGui.Button(ctx, 'Cancel', w - gap) then
                CancelCreatingClouds = true
            end
            reaper.defer(Clouds.GUI.Guiless)
        end

        ImGui.End(ctx)
    end
    Clouds.Themes[Settings.theme].Pop(ctx)
    ImGui.PopFont(ctx)
end

