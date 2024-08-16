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
local POPUPNAME = 'Buy Clouds'
local TIMER = {
    val = 10,
    last = reaper.time_precise()
}
Clouds.Tracks.Get()
local OPENBUYPOPUP = Clouds.Tracks.is_track == ''

reaper.time_precise()
-- Main Function
function Clouds.GUI.Main()
    --- Check selected Item for cloud items
    if FixedCloud then
        if not reaper.ValidatePtr2(Proj, FixedCloud, 'MediaItem*') then
            FixedCloud = nil
        end
    end
    if (not CreatingClouds) and (not FixedCloud) then
        Clouds.Item.CheckSelection(Proj)
    end
    --checks if items/tracks exists
    if CloudTable then
        for k, v in DL.t.ipairs_reverse(CloudTable.items) do
            if not reaper.ValidatePtr2(Proj, v.item, 'MediaItem*') then
                table.remove(CloudTable.items,k)
            end
        end

        for k, v in DL.t.ipairs_reverse(CloudTable.tracks) do -- dont need to check self
            if not reaper.ValidatePtr2(Proj, v.track, 'MediaTrack*') then
                table.remove(CloudTable.tracks,k)
            end
        end
    end
    --- Keyboard shortcuts
    --DL.imgui.SWSPassKeys(ctx, false)
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
    ImGui.SetNextWindowSizeConstraints(ctx, 375, 50, guiW, FLT_MAX)
    ImGui.PushFont(ctx, font_text)
    local visible, open = ImGui.Begin(ctx, SCRIPT_NAME..' '..SCRIPT_V, true, window_flags) 
    
    --- PopUp
    if OPENBUYPOPUP then
        OPENBUYPOPUP = nil
        ImGui.OpenPopup(ctx, POPUPNAME)
    end

    Clouds.GUI.BUY()
    
    if visible then
        if ImGui.BeginMenuBar(ctx) then
            if ImGui.BeginMenu(ctx, "Settings") then
                local setting_change, change = false, false
                change, Settings.tooltip= ImGui.MenuItem(ctx, 'Tooltips', nil, Settings.tooltip)
                setting_change = setting_change or change
                if ImGui.BeginMenu(ctx, 'Themes') then
                    for name, theme in pairs(Clouds.Themes) do
                        if ImGui.MenuItem(ctx, name..'##themeitem', nil, Settings.theme == name) and Settings.theme ~= name then
                            Settings.theme = name
                            setting_change = true
                        end
                    end

                    ImGui.EndMenu(ctx)
                end
    
                if setting_change then
                    Clouds.Settings.Save(SETTINGS.path, Settings)
                end
                ImGui.EndMenu(ctx)
            end

            if ImGui.BeginMenu(ctx, 'About') then
                if ImGui.MenuItem(ctx, 'Manual') then
                    DL.url.OpenURL(URL.manual)
                end
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
                if ImGui.Button(ctx, 'Set Items') then
                    Clouds.Item.SetItems(Proj)
                    something_changed = true
                end
                ImGui.SameLine(ctx)
                if ImGui.Button(ctx, 'Add Items') then
                    Clouds.Item.AddItems(Proj)
                    something_changed = true                    
                end
                ImGui.SameLine(ctx)
                if ImGui.Button(ctx, 'Select Items') then
                    Clouds.Item.SelectItems(Proj)
                end
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
                                change, CloudTable.items[row].chance = ImGui.InputDouble(ctx, '##ItemChanceWeight'..row, CloudTable.items[row].chance, nil, nil, '%.1f')
                                if ImGui.IsItemDeactivatedAfterEdit(ctx) then
                                    CloudTable.items[row].chance = CloudTable.items[row].chance >= 0 and CloudTable.items[row].chance or 0
                                end
                                something_changed = something_changed or change
                                --Remove Button
                                ImGui.SameLine(ctx)
                                if ImGui.Button(ctx, 'X##itemremove'..row) then
                                    table.remove(CloudTable.items, row)
                                    something_changed = true
                                end
                            end
                        end
                    end
                    ImGui.EndTable(ctx)
                end
            end

            -- Density
            if (not CloudTable.midi_notes.is_synth) and ImGui.CollapsingHeader(ctx, "Density##header") then
                ----- Density
                change, CloudTable.density.density.val = ImGui.InputDouble(ctx, "Items/Second##Double", CloudTable.density.density.val)
                if ImGui.IsItemDeactivatedAfterEdit(ctx) then 
                    CloudTable.density.density.val = ((CloudTable.density.density.val > 0) and CloudTable.density.density.val) or 0 
                    CloudTable.density.density.env_min =  DL.num.Clamp(CloudTable.density.density.env_min, 0, CloudTable.density.density.val)
                end
                something_changed = something_changed or change
                -- Right click
                if ImGui.BeginPopupContextItem(ctx, 'RatioDensity') then
                    TempRatioDensity = TempRatioDensity or (CloudTable.grains.size.val * CloudTable.density.density.val / 1000)*100
                    change, TempRatioDensity = ImGui.SliderInt(ctx, 'Grain Size / Density Ratio', math.floor(TempRatioDensity), 25, 200, '%.i%%')
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
                change, CloudTable.density.density.envelope = Clouds.GUI.EnvCheck(CloudTable.density.density.envelope, FXENVELOPES.density)
                something_changed = something_changed or change
                if ImGui.BeginPopupContextItem(ctx,'densitymin') then
                    change, CloudTable.density.density.env_min = ImGui.SliderDouble(ctx, 'Min##SliderDensity', CloudTable.density.density.env_min, 0, CloudTable.density.density.val, nil, ImGui.SliderFlags_AlwaysClamp)
                    something_changed = something_changed or change
                    ImGui.EndPopup(ctx)
                end
                
                ----- Dust
                change, CloudTable.density.random.val = ImGui.InputDouble(ctx, "Dust##Slider", CloudTable.density.random.val)
                if ImGui.IsItemDeactivatedAfterEdit(ctx) then CloudTable.density.random.val = ((CloudTable.density.random.val > 0) and CloudTable.density.random.val) or 0 end
                something_changed = something_changed or change
                --Env
                ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, ww + ENV_X)
                change, CloudTable.density.random.envelope = Clouds.GUI.EnvCheck(CloudTable.density.random.envelope, FXENVELOPES.dust)
                something_changed = something_changed or change

                ----- Cap
                change, CloudTable.density.cap = ImGui.InputInt(ctx, 'Max N Items', CloudTable.density.cap)
                if ImGui.IsItemDeactivatedAfterEdit(ctx) then
                    CloudTable.density.cap = DL.num.Clamp(CloudTable.density.cap, 0)
                end
                something_changed = something_changed or change
            end

            -- Grains
            if ImGui.CollapsingHeader(ctx, "Grain##header") then
                if not CloudTable.midi_notes.is_synth then
                    change, CloudTable.grains.on = ImGui.Checkbox(ctx, 'Cloud Grains', CloudTable.grains.on)
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
                    change, CloudTable.grains.size.val = ImGui.InputDouble(ctx, "Size##Double", CloudTable.grains.size.val, nil, nil, '%.2f ms')
                    if ImGui.IsItemDeactivatedAfterEdit(ctx) then CloudTable.grains.size.val = ((CloudTable.grains.size.val > CONSTRAINS.grain_low) and CloudTable.grains.size.val) or CONSTRAINS.grain_low end
                    something_changed = something_changed or change
                    -- Right click
                    if ImGui.BeginPopupContextItem(ctx, 'RatioDensityGrain') then
                        TempRatioTime = TempRatioTime or (CloudTable.grains.size.val * CloudTable.density.density.val / 1000)*100
                        change, TempRatioTime = ImGui.SliderInt(ctx, 'Grain Size / Density Ratio', math.floor(TempRatioTime), 25, 200, '%.i%%')
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
                    change, CloudTable.grains.size.envelope = Clouds.GUI.EnvCheck(CloudTable.grains.size.envelope, FXENVELOPES.grains.size)
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
                if change and not CloudTable.grains.randomize_size.on then
                    Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.grains.randomize_size)         
                elseif change then
                    Clouds.Item.ShowHideEnvelope(CloudTable.grains.randomize_size.envelope,FXENVELOPES.grains.randomize_size)
                end
                something_changed = something_changed or change
                ImGui.BeginDisabled(ctx, not CloudTable.grains.randomize_size.on)
                --Input
                ImGui.SetNextItemWidth(ctx, SLIDERS_W2)
                change, CloudTable.grains.randomize_size.min, CloudTable.grains.randomize_size.max = ImGui.InputDouble2(ctx, "Size Drift##randominput", CloudTable.grains.randomize_size.min, CloudTable.grains.randomize_size.max, '%.2f%%')
                if ImGui.IsItemDeactivatedAfterEdit(ctx) then -- clamp
                    CloudTable.grains.randomize_size.min = DL.num.Clamp(CloudTable.grains.randomize_size.min, CONSTRAINS.grain_rand_low)
                    CloudTable.grains.randomize_size.max = DL.num.Clamp(CloudTable.grains.randomize_size.max, CONSTRAINS.grain_rand_low)
                    if CloudTable.grains.randomize_size.min > CloudTable.grains.randomize_size.max then 
                        CloudTable.grains.randomize_size.min = CloudTable.grains.randomize_size.max 
                    end
                end
                something_changed = something_changed or change
                --Env
                ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, ww + ENV_X)
                change, CloudTable.grains.randomize_size.envelope = Clouds.GUI.EnvCheck(CloudTable.grains.randomize_size.envelope, FXENVELOPES.grains.randomize_size)
                something_changed = something_changed or change
                ImGui.EndDisabled(ctx)

                ----- Position
                --Checkbox
                change, CloudTable.grains.position.on = ImGui.Checkbox(ctx, '##PositionCheckbox', CloudTable.grains.position.on); ImGui.SameLine(ctx)
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
                something_changed = something_changed or change
                --Env
                ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, ww + ENV_X)
                change, CloudTable.grains.position.envelope = Clouds.GUI.EnvCheck(CloudTable.grains.position.envelope, FXENVELOPES.grains.position)
                something_changed = something_changed or change
                ImGui.EndDisabled(ctx)

                ----- Position Drift
                --Checkbox
                ImGui.BeginDisabled(ctx, not CloudTable.grains.position.on)
                change, CloudTable.grains.randomize_position.on = ImGui.Checkbox(ctx, '##PositionDrift', CloudTable.grains.randomize_position.on); ImGui.SameLine(ctx)
                if change and not CloudTable.grains.randomize_position.on then
                    Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.grains.randomize_position)       
                elseif change then
                    Clouds.Item.ShowHideEnvelope(CloudTable.grains.randomize_position.envelope,FXENVELOPES.grains.randomize_position)
                end
                something_changed = something_changed or change
                ImGui.BeginDisabled(ctx, not CloudTable.grains.randomize_position.on)
                --Input
                ImGui.SetNextItemWidth(ctx, SLIDERS_W2)
                change, CloudTable.grains.randomize_position.min, CloudTable.grains.randomize_position.max = ImGui.InputDouble2(ctx, "Position Drift##randominput", CloudTable.grains.randomize_position.min, CloudTable.grains.randomize_position.max, '%.2f ms')
                if ImGui.IsItemDeactivatedAfterEdit(ctx) then -- clamp
                    if CloudTable.grains.randomize_position.min > CloudTable.grains.randomize_position.max then 
                        CloudTable.grains.randomize_position.min = CloudTable.grains.randomize_position.max 
                    end
                end
                something_changed = something_changed or change
                --Env
                ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, ww + ENV_X)
                change, CloudTable.grains.randomize_position.envelope = Clouds.GUI.EnvCheck(CloudTable.grains.randomize_position.envelope, FXENVELOPES.grains.randomize_position)
                something_changed = something_changed or change
                ImGui.EndDisabled(ctx) -- Drift
                ImGui.EndDisabled(ctx) -- Pos


                ----- Fade
                --Checkbox
                change, CloudTable.grains.fade.on = ImGui.Checkbox(ctx, '##fadegrian', CloudTable.grains.fade.on); ImGui.SameLine(ctx)
                something_changed = something_changed or change
                ImGui.BeginDisabled(ctx, not CloudTable.grains.fade.on)
                --Input
                ImGui.SetNextItemWidth(ctx, SLIDERS_W2)
                change, CloudTable.grains.fade.val = ImGui.SliderDouble(ctx, "Fade##Double", CloudTable.grains.fade.val, 0, 100, '%.2f%%', ImGui.SliderFlags_AlwaysClamp) 
                something_changed = something_changed or change
                ImGui.EndDisabled(ctx)

                ImGui.EndDisabled(ctx)
            end

            if ImGui.CollapsingHeader(ctx, 'MIDI Notes') then
                if not CloudTable.midi_notes.is_synth then
                    change, CloudTable.midi_notes.solo_notes = ImGui.Checkbox(ctx, 'Only Apply at Notes', CloudTable.midi_notes.solo_notes)
                    something_changed = something_changed or change
                end

                ------ EDO Tuning
                change, CloudTable.midi_notes.EDO = ImGui.InputInt(ctx, 'Tuning EDO', CloudTable.midi_notes.EDO, 0, 0)
                something_changed = something_changed or change
                -- Clamp
                if ImGui.IsItemDeactivatedAfterEdit(ctx) then CloudTable.midi_notes.EDO = ((CloudTable.midi_notes.EDO > 0) and CloudTable.midi_notes.EDO) or 1 end
               
                ----- Center or A4
                if not CloudTable.midi_notes.is_synth then
                    change, CloudTable.midi_notes.center = ImGui.InputInt(ctx, 'MIDI Center', CloudTable.midi_notes.center, 0, 0)
                    something_changed = something_changed or change
                    if ImGui.IsItemDeactivatedAfterEdit(ctx) then CloudTable.midi_notes.center = ((CloudTable.midi_notes.center >= 0) and CloudTable.midi_notes.center) or 0 end
                else
                    change, CloudTable.midi_notes.A4 = ImGui.InputInt(ctx, 'A4', CloudTable.midi_notes.A4, 0, 0)
                    something_changed = something_changed or change
                    if ImGui.IsItemDeactivatedAfterEdit(ctx) then CloudTable.midi_notes.A4 = ((CloudTable.midi_notes.A4 > 0) and CloudTable.midi_notes.A4) or 1 end
                end

                ImGui.Separator(ctx)
                ----- Synth
                change, CloudTable.midi_notes.is_synth = ImGui.Checkbox(ctx, 'Synth Mode', CloudTable.midi_notes.is_synth)
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
            end

            -- Randomization
            if ImGui.CollapsingHeader(ctx, "Randomization##header") then
                ----- Volume
                --Checkbox
                change, CloudTable.randomization.vol.on = ImGui.Checkbox(ctx, '##VolumeCheckbox', CloudTable.randomization.vol.on); ImGui.SameLine(ctx)
                if change and not CloudTable.randomization.vol.on then
                    Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.randomization.vol)       
                elseif change then
                    Clouds.Item.ShowHideEnvelope(CloudTable.randomization.vol.envelope,FXENVELOPES.randomization.vol)
                end
                something_changed = something_changed or change
                ImGui.BeginDisabled(ctx, not CloudTable.randomization.vol.on)
                --Input
                ImGui.SetNextItemWidth(ctx, SLIDERS_W2)
                change, CloudTable.randomization.vol.min, CloudTable.randomization.vol.max = ImGui.InputDouble2(ctx, "Volume##randominput", CloudTable.randomization.vol.min, CloudTable.randomization.vol.max, '%.2f dB')
                if ImGui.IsItemDeactivatedAfterEdit(ctx) and CloudTable.randomization.vol.min > CloudTable.randomization.vol.max then CloudTable.randomization.vol.min = CloudTable.randomization.vol.max end
                something_changed = something_changed or change
                --Env
                ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, ww + ENV_X)
                change, CloudTable.randomization.vol.envelope = Clouds.GUI.EnvCheck(CloudTable.randomization.vol.envelope, FXENVELOPES.randomization.vol)
                something_changed = something_changed or change
                ImGui.EndDisabled(ctx)

                ----- Pan
                --Checkbox
                change, CloudTable.randomization.pan.on = ImGui.Checkbox(ctx, '##PanCheckbox', CloudTable.randomization.pan.on); ImGui.SameLine(ctx)
                if change and not CloudTable.randomization.pan.on then
                    Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.randomization.pan)       
                elseif change then
                    Clouds.Item.ShowHideEnvelope(CloudTable.randomization.pan.envelope,FXENVELOPES.randomization.pan)
                end
                something_changed = something_changed or change
                ImGui.BeginDisabled(ctx, not CloudTable.randomization.pan.on)
                --Input
                ImGui.SetNextItemWidth(ctx, SLIDERS_W2)
                change, CloudTable.randomization.pan.min, CloudTable.randomization.pan.max = ImGui.InputDouble2(ctx, "Pan##randominput", CloudTable.randomization.pan.min, CloudTable.randomization.pan.max, '%.2f')
                if ImGui.IsItemDeactivatedAfterEdit(ctx) then -- clamp
                    CloudTable.randomization.pan.min = (CloudTable.randomization.pan.min >= -1 and CloudTable.randomization.pan.min <= 1) and CloudTable.randomization.pan.min or -1
                    CloudTable.randomization.pan.max = (CloudTable.randomization.pan.max >= -1 and CloudTable.randomization.pan.max <= 1) and CloudTable.randomization.pan.max or -1
                    if CloudTable.randomization.pan.min > CloudTable.randomization.pan.max then 
                        CloudTable.randomization.pan.min = CloudTable.randomization.pan.max 
                    end
                end
                something_changed = something_changed or change
                --Env
                ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, ww + ENV_X)
                change, CloudTable.randomization.pan.envelope = Clouds.GUI.EnvCheck(CloudTable.randomization.pan.envelope, FXENVELOPES.randomization.pan)
                something_changed = something_changed or change
                ImGui.EndDisabled(ctx)

                ----- Pitch
                --Checkbox
                change, CloudTable.randomization.pitch.on = ImGui.Checkbox(ctx, '##PitchCheckbox', CloudTable.randomization.pitch.on); ImGui.SameLine(ctx)
                if change and not CloudTable.randomization.pitch.on then
                    Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.randomization.pitch)       
                elseif change then
                    Clouds.Item.ShowHideEnvelope(CloudTable.randomization.pitch.envelope,FXENVELOPES.randomization.pitch)
                end
                something_changed = something_changed or change
                ImGui.BeginDisabled(ctx, not CloudTable.randomization.pitch.on)
                --Input
                ImGui.SetNextItemWidth(ctx, SLIDERS_W2)
                change, CloudTable.randomization.pitch.min, CloudTable.randomization.pitch.max = ImGui.InputDouble2(ctx, "Pitch##randominput", CloudTable.randomization.pitch.min, CloudTable.randomization.pitch.max, '%.2f')
                if ImGui.IsItemDeactivatedAfterEdit(ctx) and CloudTable.randomization.pitch.min > CloudTable.randomization.pitch.max then CloudTable.randomization.pitch.min = CloudTable.randomization.pitch.max end
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
                change, CloudTable.randomization.pitch.envelope = Clouds.GUI.EnvCheck(CloudTable.randomization.pitch.envelope, FXENVELOPES.randomization.pitch)
                something_changed = something_changed or change
                ImGui.EndDisabled(ctx)

                ----- Stretch
                --Checkbox
                change, CloudTable.randomization.stretch.on = ImGui.Checkbox(ctx, '##StretchCheckbox', CloudTable.randomization.stretch.on); ImGui.SameLine(ctx)
                if change and not CloudTable.randomization.stretch.on then
                    Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.randomization.stretch)       
                elseif change then
                    Clouds.Item.ShowHideEnvelope(CloudTable.randomization.stretch.envelope,FXENVELOPES.randomization.stretch)
                end
                something_changed = something_changed or change
                ImGui.BeginDisabled(ctx, not CloudTable.randomization.stretch.on)
                --Input
                ImGui.SetNextItemWidth(ctx, SLIDERS_W2)
                change, CloudTable.randomization.stretch.min, CloudTable.randomization.stretch.max = ImGui.InputDouble2(ctx, "Playrate##randominput", CloudTable.randomization.stretch.min, CloudTable.randomization.stretch.max, '%.2f')
                something_changed = something_changed or change
                if ImGui.IsItemDeactivatedAfterEdit(ctx) then -- clamp
                    CloudTable.randomization.stretch.min = (CloudTable.randomization.stretch.min > CONSTRAINS.stretch_low) and CloudTable.randomization.stretch.min or CONSTRAINS.stretch_low
                    CloudTable.randomization.stretch.max = (CloudTable.randomization.stretch.max > CONSTRAINS.stretch_low) and CloudTable.randomization.stretch.max or CONSTRAINS.stretch_low
                    if CloudTable.randomization.stretch.min > CloudTable.randomization.stretch.max then 
                        CloudTable.randomization.stretch.min = CloudTable.randomization.stretch.max 
                    end
                end
                --Env
                ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, ww + ENV_X)
                change, CloudTable.randomization.stretch.envelope = Clouds.GUI.EnvCheck(CloudTable.randomization.stretch.envelope, FXENVELOPES.randomization.stretch)
                something_changed = something_changed or change
                ImGui.EndDisabled(ctx)

                ----- Reverse
                --Checkbox
                change, CloudTable.randomization.reverse.on = ImGui.Checkbox(ctx, '##ReverserCheckbox', CloudTable.randomization.reverse.on); ImGui.SameLine(ctx)
                if change and not CloudTable.randomization.reverse.on then
                    Clouds.Item.ShowHideEnvelope(false,FXENVELOPES.randomization.reverse)       
                elseif change then
                    Clouds.Item.ShowHideEnvelope(CloudTable.randomization.reverse.envelope,FXENVELOPES.randomization.reverse)
                end
                something_changed = something_changed or change
                ImGui.BeginDisabled(ctx, not CloudTable.randomization.reverse.on)
                --Input
                ImGui.SetNextItemWidth(ctx, SLIDERS_W2)
                change, CloudTable.randomization.reverse.val = ImGui.SliderInt(ctx, "Reverse##randominput", CloudTable.randomization.reverse.val, 0, 100, '%i%%', ImGui.SliderFlags_AlwaysClamp)
                --change, CloudTable.randomization.reverse.val = ImGui.InputDouble(ctx, "Reverse##randominput", CloudTable.randomization.reverse.val, nil, nil, '%.2f %')
                if ImGui.IsItemDeactivatedAfterEdit(ctx) then -- clamp
                    CloudTable.randomization.reverse.val = DL.num.Clamp(CloudTable.randomization.reverse.val, 0, 100)
                end
                something_changed = something_changed or change
                --Env
                ImGui.SameLine(ctx); ImGui.SetCursorPosX(ctx, ww + ENV_X)
                change, CloudTable.randomization.reverse.envelope = Clouds.GUI.EnvCheck(CloudTable.randomization.reverse.envelope, FXENVELOPES.randomization.reverse)
                something_changed = something_changed or change
                ImGui.EndDisabled(ctx)
            end

            -- Tracks
            if ImGui.CollapsingHeader(ctx, "Tracks##header") then
                if ImGui.Button(ctx, 'Set Tracks') then
                    Clouds.Item.SetTracks(Proj)
                    something_changed = true
                end
                ImGui.SameLine(ctx)
                if ImGui.Button(ctx, 'Add Tracks') then
                    Clouds.Item.AddTracks(Proj)
                    something_changed = true                    
                end
                ImGui.SameLine(ctx)
                if ImGui.Button(ctx, 'Select Tracks') then
                    Clouds.Item.SelectTracks(Proj)
                end
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
                                change, t.chance = ImGui.InputDouble(ctx, '##trackChanceWeight'..row, t.chance, nil, nil, '%.1f')
                                if ImGui.IsItemDeactivatedAfterEdit(ctx) then
                                    t.chance = t.chance >= 0 and t.chance or 0
                                end
                                something_changed = something_changed or change
                                --Remove Button
                                ImGui.SameLine(ctx)
                                if row ~= 0 then
                                    if ImGui.Button(ctx, 'X##trackremove'..row) then
                                        table.remove(CloudTable.tracks, row)
                                        something_changed = true
                                    end
                                end
                            end
                        end
                    end
                    ImGui.EndTable(ctx)
                end
            end
            
            

            ImGui.PopItemWidth(ctx)

            ImGui.Separator(ctx)

            -- Fixcloud Checkbox
            local change, val = ImGui.Checkbox(ctx, 'Fix Cloud', (FixedCloud ~= nil))
            if change and val and CloudTable.cloud then
                FixedCloud = CloudTable.cloud
            elseif change then
                FixedCloud = nil
            end
            
            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, 'Copy Settings') then
                CopySettings = DL.t.DeepCopy(CloudTable)
            end

            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, 'Paste Settings') then
                local cloud = CloudTable.cloud
                CloudTable = DL.t.DeepCopy(CopySettings)
                CloudTable.cloud = cloud
                Clouds.Item.ShowHideAllEnvelopes()
                Clouds.Item.SaveSettings(Proj, CloudTable.cloud, CloudTable)
            end

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
                if ImGui.Button(ctx, 'Save', 150) then
                    local retval, fileName = reaper.JS_Dialog_BrowseForSaveFile( 'Save Cloud Preset', PRESETS.path, PresetName..'.json', 'json' )
                    Clouds.Presets.SavePreset(fileName, CloudTable)
                end
                
                ImGui.EndCombo(ctx)
            else 
                Presets = nil
            end


            -- Apply Buttons
            -- Standard = Generate Clouds for selected clouds. Erasing existing items
            -- with Alt = + Don't Erase Previous Items
            -- with Ctrl = + All Clouds at the project  
            local ctrl = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)
            local alt = ImGui.IsKeyDown(ctx, ImGui.Mod_Alt)
            local text_help = 'Generate Clouds for'
            if not ctrl then
                text_help = text_help..' selected cloud items'
            else
                text_help = text_help..' all cloud items'
            end

            if not alt then
                text_help = text_help..', deleting previous clouds'
            end
            text_help = text_help .. '.'

            if ImGui.Button(ctx, 'Generate Selected Clouds!', -FLT_MIN) then
                CreatingClouds = coroutine.wrap(Clouds.apply.GenerateClouds)
                --Clouds.apply.GenerateClouds(Proj, not ctrl, not alt)                    
            end
            ImGui.SetItemTooltip(ctx, text_help)

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
        end
        ImGui.End(ctx)
    end

    ImGui.PopFont(ctx)
    --demo.PopStyle(ctx)
    pop_theme(ctx)
    --Clouds.Themes[Settings.theme].Pop(ctx)

    if open then
        reaper.defer(Clouds.GUI.Main)
    end
end

function Clouds.GUI.EnvCheck(val, env_n)
    local something_changed = false
    --Env
    if ImGui.Checkbox(ctx, "Env##"..env_n, val) then
        val = not val
        Clouds.Item.ShowHideEnvelope(val, env_n)
        something_changed = true
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
    ImGui.SetNextWindowPos(ctx, center_x, center_y, nil, 0.5, 0.5)
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
        
        ImGui.TextWrapped(ctx, string.format("Clouds is not free!\n\nIt is a paid script.\n\nIf you use it more than 7 days you are required to purchase a license.\n\nYou have been evaluating Clouds for approximately %d days",DAYS_EVAL))

        ImGui.NewLine(ctx)
        ImGui.NewLine(ctx)

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
                reaper.ShowMessageBox("Hmmm. Serial key incorrect.\nTry again, check if everything is copied correctly, if problem persist contact me!", 'Clouds', 0)
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