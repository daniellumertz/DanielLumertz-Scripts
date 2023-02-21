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
            ToolTip(UserConfigs.tooltips,'This is a parameter tab. Right Click to rename or remove.')

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
        local open = reaper.ImGui_BeginTabItem(ctx, 'All', false)
        ToolTip(UserConfigs.tooltips,'This is a parameter tab. Right Click to rename or delete.')
        if open then-- Start each tab
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
        ToolTip(UserConfigs.tooltips,'Create a new parameter.')


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
    _, parameter.value = ImGui_SliderWithMark(ctx, '##'..parameter.name..parameter_key, parameter.value, parameter.true_value, is_mark, 0, 1,TRUE_VALUE_COLOR ,'')

    -- pop size
    reaper.ImGui_PopFont(ctx)

    -- Show value
    ToolTip(UserConfigs.tooltips,'This is the parameter slider, drag to change the parameter value.\nRight click for more options')
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
    ToolTip(UserConfigs.tooltips,'ADD selected track as targets for this parameter.\nHold alt to SET selected tracks as the targets for this parameter.\nEach track will only be in one parameter at the same time.')

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

        local open = reaper.ImGui_TreeNode(ctx, 'Track : '..name..'##'..target_idx)
        ToolTip(UserConfigs.tooltips,'This is a track target. Right Click for more options.\n\nAt the curve editor:\nDouble Click = Add Point\nRight Click = Remove Point\nAlt + Left drag = Adjust segment tension\nAlt + Right Click = Reset segment tension\nShift drag = More Precision',400)

        -- Right click node
        TargetRightClick(parameter,target,track)
        -- Curve inside tree node
        if open then
            local curve_editor_height = 75
            local change = ce_draw(ctx, target.curve, 'target'..name, -FLTMIN, curve_editor_height, {target.value})
            if change then -- if the curve was changed need to update the value, as it could have change (if change the Y for the current X)
                target.is_update_ce = true
            end
            is_save = is_save or change

            reaper.ImGui_TreePop(ctx)
        end

        reaper.ImGui_PopStyleVar(ctx)
    end
    if is_save then -- Save settings
        SaveProjectSettings(FocusedProj, ProjConfigs[FocusedProj]) 
    end
end

function TargetRightClick(parameter,target,track)
    reaper.ImGui_SetNextWindowSizeConstraints( ctx,  150, -1, FLTMAX, FLTMAX)
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
        --------------------------
        reaper.ImGui_Separator(ctx)
        TextCenter('FX')

        if reaper.ImGui_BeginMenu(ctx, 'FX Position') then
            _, target.is_force_fx = reaper.ImGui_Checkbox(ctx, "Force FX Position", target.is_force_fx)
            ToolTip(true,'Force the '..FXNAME..' to be at a position in the FX chain.')
            if target.is_force_fx then
                reaper.ImGui_Text(ctx, 'FX Pos:')
                reaper.ImGui_SetNextItemWidth(ctx, -FLTMIN)
                _, target.force_fx_pos = reaper.ImGui_InputInt(ctx, '##InputPos', target.force_fx_pos , 0, 0)
                ToolTip(true,'0 = Last Fx.\n-1 -2 -3... = Fx postition counting from the end.\n1 2 3... = Fx position counting from the start.')
            end
            reaper.ImGui_EndMenu(ctx)
        end

        if reaper.ImGui_BeginMenu(ctx, 'FX MIDI Options') then
            _, target.is_force_fx_settings = reaper.ImGui_Checkbox(ctx, "Force FX Settings", target.is_force_fx_settings)
            ToolTip(true,'Force the '..FXNAME..' settings. Optionally is to set manually at the FX UI.')
            if target.is_force_fx_settings then
                _, target.is_fx_midi_chase = reaper.ImGui_Checkbox(ctx, "Chase MIDI", target.is_fx_midi_chase)
                ToolTip(true,'When the parameter value is 1 it will chase midi notes that were filtered and are still playing.')
                _, target.is_fx_chase_only_once = reaper.ImGui_Checkbox(ctx, "Chase MIDI Only Once", target.is_fx_chase_only_once)
                ToolTip(true,'Chase each midi note just once. For cases where the parameter will be oscilating between 1(playing) and <1(not playing).')
                _, target.is_fx_midi_scale = reaper.ImGui_Checkbox(ctx, "Scale MIDI Velocity", target.is_fx_midi_scale)
                ToolTip(true,'Scale the MIDI Note Velocity when curve value is between 0 and 1.')
            end
            reaper.ImGui_EndMenu(ctx)
        end
        --bypass:
        _, target.bypass = reaper.ImGui_Checkbox(ctx, 'Bypass FX', target.bypass) -- will change at next loop
        ToolTip(UserConfigs.tooltips,'Bypass target FX')        

        --------------------
        reaper.ImGui_Separator(ctx)
        TextCenter('Target')

        -- Slope Up
        reaper.ImGui_SetNextItemWidth(ctx, 45)
        _, target.slopeup = reaper.ImGui_InputDouble(ctx, 'Slope Up', target.slopeup, 0, 0, '%.2f')
        target.slopeup = LimitNumber(target.slopeup,0)
        ToolTip(UserConfigs.tooltips,'How much time it will take to go from 0 to 1. This will be added to the Slope up from the parameter.')        

        -- Slope Down
        reaper.ImGui_SetNextItemWidth(ctx, 45)
        _, target.slopedown = reaper.ImGui_InputDouble(ctx, 'Slope Down', target.slopedown, 0, 0, '%.2f')
        target.slopedown = LimitNumber(target.slopedown,0)
        ToolTip(UserConfigs.tooltips,'How much time it will take to go from 1 to 0. This will be added to the Slope down from the parameter.')        

        -- Remove button
        if reaper.ImGui_Button(ctx, 'Remove Target',-FLTMIN) then
            RemoveTarget(parameter, track)
            SaveProjectSettings(FocusedProj, ProjConfigs[FocusedProj]) 
            TempTargetRightClick = nil
            reaper.ImGui_CloseCurrentPopup(ctx)
        end

        TempTargetRightClick = target -- save when this closes
        reaper.ImGui_EndPopup(ctx)
    elseif TempTargetRightClick == target then
        TempTargetRightClick = nil
        SaveProjectSettings(FocusedProj, ProjConfigs[FocusedProj]) 
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
        RemoveGroup(FocusedProj, parameter_key)
        --table.remove(ProjConfigs[FocusedProj].parameters,parameter_key)
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
        ToolTip(UserConfigs.tooltips,'How much time it will take to go from 0 to 1. In seconds.')


        --- Slopedown
        reaper.ImGui_SetNextItemWidth(ctx, 90)
        _, parameter.slopedown = reaper.ImGui_InputDouble(ctx, 'Slope Down', parameter.slopedown, 0, 0, '%.2f') -- TODO add tooltip saying this is the time it takes to get from 1 to 0
        parameter.slopedown = LimitNumber(parameter.slopedown,0)
        ToolTip(UserConfigs.tooltips,'How much time it will take to go from 1 to 0. In seconds.')

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
    ToolTip(UserConfigs.tooltips,'Control this parameter with a REAPER envelope.')

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
        ToolTip(UserConfigs.tooltips,'Remove envelope follower.')

        ImPrint('From '..host_type..' : ',host_name)
    end
end

---------   
-- Menu
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
            
            if reaper.ImGui_BeginMenu(ctx, 'Script Settings') then
                local change1, change2
                change1, UserConfigs.only_focus_project = reaper.ImGui_MenuItem(ctx, 'Only Focused Project', optional_shortcutIn, UserConfigs.only_focus_project)
                ToolTip(true, 'Only change parameters at the focused project.')

                change2, UserConfigs.tooltips = reaper.ImGui_MenuItem(ctx, 'Show Tooltips', optional_shortcutIn, UserConfigs.tooltips)

                if change1 or change2 then
                    SaveSettings(ScriptPath,SettingsFileName)
                end

                reaper.ImGui_EndMenu(ctx)
            end

            if reaper.ImGui_BeginMenu(ctx, 'Script Project Settings') then
                local change1, change2
                change1, ProjConfigs[FocusedProj].remove_fx_atexit = reaper.ImGui_MenuItem(ctx, 'At Exit Remove FXs', optional_shortcutIn, ProjConfigs[FocusedProj].remove_fx_atexit)
                ToolTip(true,'Remove Volume Layer FX from all target tracks when the script closes.')
                change2, ProjConfigs[FocusedProj].bypass = reaper.ImGui_MenuItem(ctx, 'Bypass', optional_shortcutIn, ProjConfigs[FocusedProj].bypass)
                ToolTip(UserConfigs.tooltips,'Bypass all Volume Layers FX in the project.')

        
                if change1 or change2  then
                    SaveSettings(ScriptPath,SettingsFileName)
                end
    
                reaper.ImGui_EndMenu(ctx)
            end

            reaper.ImGui_EndMenu(ctx)
        end



        if reaper.ImGui_BeginMenu(ctx, 'About') then
            if reaper.ImGui_MenuItem(ctx, 'Donate') then
                open_url('https://www.paypal.com/donate/?hosted_button_id=RWA58GZTYMZ3N')
            end
            ToolTip(true, 'Recommended donation 20$ - 40$')

            if reaper.ImGui_MenuItem(ctx, 'Forum') then
                open_url('https://forum.cockos.com/showthread.php?t=276313')
            end

            if reaper.ImGui_BeginMenu(ctx, 'Videos') then
                if reaper.ImGui_MenuItem(ctx, 'Introduction') then
                    open_url('https://youtu.be/dyoWlduQIAg')
                end  

                if reaper.ImGui_MenuItem(ctx, 'Layers') then
                    open_url('https://youtu.be/qfoRAYN-1q4')
                end  

                if reaper.ImGui_MenuItem(ctx, 'Alternator') then
                    open_url('https://youtu.be/Oh1xKXGrSFA')
                end  

                if reaper.ImGui_MenuItem(ctx, 'ReaGoTo') then
                    open_url('https://youtu.be/mwXdwAlXXuU')
                end  

                if reaper.ImGui_MenuItem(ctx, 'Advanced Settings') then
                    open_url('https://youtu.be/KWM4EhEz8aY')
                end  

                reaper.ImGui_EndMenu(ctx)
            end

            reaper.ImGui_EndMenu(ctx)
        end
        _, GuiSettings.Pin = reaper.ImGui_MenuItem(ctx, 'Pin', optional_shortcutIn, GuiSettings.Pin)

        DockBtn()

        reaper.ImGui_EndMenuBar(ctx)
    end
end