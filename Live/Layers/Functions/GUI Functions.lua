-- @noindex
function GuiInit()
    ctx = reaper.ImGui_CreateContext(ScriptName, reaper.ImGui_ConfigFlags_DockingEnable()) -- Add VERSION TODO
    --- Text Font
    FontText = reaper.ImGui_CreateFont('sans-serif', 14) -- Create the fonts you need
    reaper.ImGui_Attach(ctx, FontText)-- Attach the fonts you need
    --- Smaller Font for smaller widgets
    FontBigger = reaper.ImGui_CreateFont('sans-serif', 24) 
    reaper.ImGui_Attach(ctx, FontBigger)

end

---------   
-- Center GUI
---------
function ParametersTabs()
    local _
    local proj_table = ProjConfigs[FocusedProj]
    local parameters = proj_table.parameters
    -- tabs
    if reaper.ImGui_BeginTabBar(ctx, 'Parameters',  reaper.ImGui_TabBarFlags_AutoSelectNewTabs() ) then
        local is_save

        -- For every parameter
        for parameter_key, parameter in ipairs(parameters) do -- iterate every playlist
            local open, keep = reaper.ImGui_BeginTabItem(ctx, ('%s###tab%d'):format(parameter.name, parameter_key), false) -- Start each tab

            -- Popup to rename and delete
            if reaper.ImGui_BeginPopupContextItem(ctx) then 
                RenameParameter(parameter, parameter_key) 
                reaper.ImGui_EndPopup(ctx)
            elseif PreventKeys.parameter_popup == parameter_key then
                is_save = true
                PreventKeys.parameter_popup = nil
            end

            -- Show Targets
            if open then
                if reaper.ImGui_BeginChild(ctx, 'Parameter'..parameter_key, -FLTMIN, 0, true, reaper.ImGui_WindowFlags_NoScrollbar()) then
                    -- Targets
                    TargetsTab(parameter, parameter_key)
                    reaper.ImGui_EndChild(ctx)
                end
                -- Targets part
                reaper.ImGui_EndTabItem(ctx) 
            end

        end

        -- All parameters sliders
        if reaper.ImGui_BeginTabItem(ctx, 'All', false) then-- Start each tab
            if reaper.ImGui_BeginChild(ctx, 'AllParameters', -FLTMIN, 0, true, reaper.ImGui_WindowFlags_NoScrollbar()) then
                for parameter_key, parameter in ipairs(parameters) do -- iterate every playlist
                    SliderParameter(parameter,parameter_key)
                end
                reaper.ImGui_EndChild(ctx)
            end
            reaper.ImGui_EndTabItem(ctx)
        end

        -- Add Parameter
        if reaper.ImGui_TabItemButton(ctx, '+', reaper.ImGui_TabItemFlags_Trailing() | reaper.ImGui_TabItemFlags_NoTooltip()) then -- Start each tab
            table.insert(parameters,CreateParameterTable('P'..#parameters+1)) -- TODO
            is_save = true
        end

        if is_save then -- Save settings
            SaveProjectSettings(FocusedProj, ProjConfigs[FocusedProj]) -- TODO
        end
        
        reaper.ImGui_EndTabBar(ctx)
    end 
end


function SliderParameter(parameter,parameter_key)
    local _
    -- Slider size
    reaper.ImGui_PushFont(ctx,FontBigger)
    reaper.ImGui_SetNextItemWidth(ctx, -FLTMIN)

    -- slider
    local is_mark = parameter.slopeup ~= 0 or parameter.slopedown ~= 0
    _, parameter.value = ImGui_SliderWithMark(ctx, '##'..parameter.name..parameter_key, parameter.value, parameter.true_value, is_mark, 0, 1,0x42FAD248 ,'')

    -- pop size
    reaper.ImGui_PopFont(ctx)

    -- tooltip
    if reaper.ImGui_IsItemHovered(ctx) then
        ToolTipSimple(parameter.name..' : '..RemoveDecimals(parameter.value,2))
    end

    -- Popup
    SliderPopUp(parameter, parameter_key)
end

function TargetsTab(parameter, parameter_key)
    local is_save = false
    ---- Slider
    SliderParameter(parameter,parameter_key)
    ---- Button add track
    if reaper.ImGui_Button(ctx, 'Add Track', -FLTMIN) then
        -- if holding alt then set targets to selected tracks, else add to the current targets
        if reaper.ImGui_GetKeyMods(ctx) == reaper.ImGui_Mod_Alt() then 
            parameter.targets = {}
        end
        AddSelectedTracksToTargets(FocusedProj,parameter.targets)
        is_save = true
    end


    ---- Targets Curves and options

    --Get the table in project order
    local targets_organized = {}
    for track, target in pairs(parameter.targets) do
        local idx = reaper.GetMediaTrackInfo_Value( track, 'IP_TRACKNUMBER' )
        targets_organized[idx] = target
    end
    targets_organized = TableRemoveSpaceKeys(targets_organized)

    reaper.ImGui_Separator(ctx)
    for target_idx, target in pairs(targets_organized) do
        local track = target.track
        local _, name = reaper.GetTrackName(track)
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_IndentSpacing(), 0)

        local open = reaper.ImGui_TreeNode(ctx, 'Track : '..name)
        -- Right click node
        TargetRightClick(parameter,target,track)
        -- Curve inside tree node
        if open then
            local curve_editor_height = 75
            ce_draw(ctx, target.curve, 'target'..name, -FLTMIN, curve_editor_height, {target.value})

            reaper.ImGui_TreePop(ctx)
        end

        reaper.ImGui_PopStyleVar(ctx)
    end
    if is_save then -- Save settings
        SaveProjectSettings(FocusedProj, ProjConfigs[FocusedProj]) -- TODO
    end
end

function TargetRightClick(parameter,target,track)
    reaper.ImGui_SetNextWindowSizeConstraints( ctx,  150, -1, FLTMAX, FLTMAX)
    reaper.ImGui_SetNextWindowBgAlpha(ctx, 0.75)
    if reaper.ImGui_BeginPopupContextItem(ctx) then

        TextCenter('Curve')
        if reaper.ImGui_Button(ctx, 'Invert Horizontal',-FLTMIN) then
            ce_invert_points(target.curve, true, false)
            reaper.ImGui_CloseCurrentPopup(ctx)
        end

        if reaper.ImGui_Button(ctx, 'Invert Vertical',-FLTMIN) then
            ce_invert_points(target.curve, false, true)
            reaper.ImGui_CloseCurrentPopup(ctx)
        end

        if reaper.ImGui_Button(ctx, 'Copy Points',-FLTMIN) then
            TempCopyPoints = target.curve
            reaper.ImGui_CloseCurrentPopup(ctx)
        end

        if reaper.ImGui_Button(ctx, 'Paste Points',-FLTMIN) and TempCopyPoints then
            target.curve = TableDeepCopy(TempCopyPoints)
            --TempCopyPoints = nil -- why to destroy?
            reaper.ImGui_CloseCurrentPopup(ctx)
        end
        reaper.ImGui_Separator(ctx)

        TextCenter('Target')
        -- Slope Up
        reaper.ImGui_SetNextItemWidth(ctx, 45)
        _, target.slopeup = reaper.ImGui_InputDouble(ctx, 'Slope Up', target.slopeup, 0, 0, '%.2f')
        target.slopeup = LimitNumber(target.slopeup,0)
        -- Slope Down
        reaper.ImGui_SetNextItemWidth(ctx, 45)
        _, target.slopedown = reaper.ImGui_InputDouble(ctx, 'Slope Down', target.slopedown, 0, 0, '%.2f')
        target.slopedown = LimitNumber(target.slopedown,0)
        -- Remove button
        if reaper.ImGui_Button(ctx, 'Remove Target',-FLTMIN) then
            parameter.targets[track] = nil
            reaper.ImGui_CloseCurrentPopup(ctx)
        end

        reaper.ImGui_EndPopup(ctx)
    end
    
end

---------   
-- Popups
---------

function RenameParameter(parameter, parameter_key)
    local _ 
    reaper.ImGui_Text(ctx, 'Parameter Name:')
    if reaper.ImGui_IsWindowAppearing(ctx) then
        PreventKeys.parameter_popup = parameter_key
        reaper.ImGui_SetKeyboardFocusHere(ctx)
    end
    reaper.ImGui_SetNextItemWidth(ctx, -FLTMIN)
    _, parameter.name = reaper.ImGui_InputText(ctx, "##renameinput", parameter.name)
    -- delete
    if reaper.ImGui_Button(ctx, 'Delete Group',-FLTMIN) then
        reaper.ImGui_CloseCurrentPopup(ctx)
        table.remove(ProjConfigs[FocusedProj].parameters,parameter_key)
    end

    -- Enter Close it fucking down
    if reaper.ImGui_IsKeyDown(ctx, 13) then
        reaper.ImGui_CloseCurrentPopup(ctx)
    end    
end



function SliderPopUp(parameter, parameter_key)
    reaper.ImGui_SetNextWindowSizeConstraints( ctx,  175, -1, FLTMAX, FLTMAX)
    if reaper.ImGui_BeginPopupContextItem(ctx) then
        --- Slopeup
        reaper.ImGui_SetNextItemWidth(ctx, 90)
        _, parameter.slopeup = reaper.ImGui_InputDouble(ctx, 'Slope Up', parameter.slopeup, 0, 0, '%.2f') -- TODO add tooltip saying this is the time it takes to get from 0 to 1
        parameter.slopeup = LimitNumber(parameter.slopeup,0)

        --- Slopedown
        reaper.ImGui_SetNextItemWidth(ctx, 90)
        _, parameter.slopedown = reaper.ImGui_InputDouble(ctx, 'Slope Down', parameter.slopedown, 0, 0, '%.2f') -- TODO add tooltip saying this is the time it takes to get from 1 to 0
        parameter.slopedown = LimitNumber(parameter.slopedown,0)

        --- MIDI
        reaper.ImGui_Separator(ctx)
        MIDILearn(parameter.midi)

        -- Envelopes
        reaper.ImGui_Separator(ctx)
        EnvelopePopup(parameter)

        reaper.ImGui_EndPopup(ctx)
        TempSliderPopUp = parameter_key  -- to save when popup close
    elseif TempSliderPopUp == parameter_key then
        TempSliderPopUp = nil
        SaveProjectSettings(FocusedProj, ProjConfigs[FocusedProj]) -- TODO
    end
end

function EnvelopePopup(parameter)
    --- Envelope 
    reaper.ImGui_Text(ctx, 'Envelope Follower')
    if reaper.ImGui_Button(ctx, 'Get Selected Envelope', -FLTMIN) then -- TODO Check if is a track envelope instad of an item envelope
        local env = reaper.GetSelectedEnvelope(FocusedProj)
        if env then
            parameter.envelope = env
        else
            reaper.ShowMessageBox('Select some envelope!', ScriptName, 0)
        end
    end
    if parameter.envelope then
        local retval, env_name = reaper.GetEnvelopeName(parameter.envelope)
        local track = reaper.GetEnvelopeInfo_Value( parameter.envelope, 'P_TRACK' )
        local host_name, host_type
        if track ~= 0 then
            host_type = 'Track'
            local _ 
            _, host_name = reaper.GetTrackName(track)
        else
            host_type = 'Take'
            local take = reaper.GetEnvelopeInfo_Value( parameter.envelope, 'P_TAKE' )
            host_name = reaper.GetTakeName(take)
        end

        ---- Write Information and  remove button
        ImPrint('Envelope : ',env_name)
        -- remove button
        local w = reaper.ImGui_GetContentRegionAvail(ctx)
        local x_pos = w - 10 -- position of X buttons
        reaper.ImGui_SameLine(ctx, x_pos)
        if reaper.ImGui_Button(ctx, 'X##envelope'..env_name) then
            parameter.envelope = false
        end
        ImPrint('From '..host_type..' : ',host_name)
    end
end


---------   
-- MIDI
---------



function MenuBar()
    local function DockBtn()
        local reval_dock =  reaper.ImGui_IsWindowDocked(ctx)
        local dock_text =  reval_dock and  'Undock' or 'Dock'
    
        if reaper.ImGui_MenuItem(ctx,dock_text ) then
            if reval_dock then -- Already Docked
                SetDock = 0
            else -- Not docked
                SetDock = -3 -- Dock to the right 
            end
        end
    end
    
    local _

    if reaper.ImGui_BeginMenuBar(ctx) then

        if reaper.ImGui_BeginMenu(ctx, 'Settings') then
            local change1
            change1, UserConfigs.only_focus_project = reaper.ImGui_MenuItem(ctx, 'Only Focused Project', optional_shortcutIn, UserConfigs.only_focus_project)
    
            if change1 or change2 or change3 or change4 then
                SaveSettings(ScriptPath,SettingsFileName)
            end

            reaper.ImGui_EndMenu(ctx)
        end


        if reaper.ImGui_BeginMenu(ctx, 'About') then
            if reaper.ImGui_MenuItem(ctx, 'Donate') then
                open_url('https://www.paypal.com/donate/?hosted_button_id=RWA58GZTYMZ3N')
            end

            --if reaper.ImGui_MenuItem(ctx, 'Forum') then
            --    open_url('https://forum.cockos.com/showthread.php?p=2606674#post2606674')
            --end

            reaper.ImGui_EndMenu(ctx)
        end
        _, GuiSettings.Pin = reaper.ImGui_MenuItem(ctx, 'Pin', optional_shortcutIn, GuiSettings.Pin)

        DockBtn()

        reaper.ImGui_EndMenuBar(ctx)
    end
end