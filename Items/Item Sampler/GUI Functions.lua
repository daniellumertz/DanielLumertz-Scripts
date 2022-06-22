-- @noindex
function PassThorugh() -- Might be a little tough on resource. Also set Ctrl Shift Alt global variables

    --Get keys pressed
    local keycodes = KeyCodeList()
    local active_keys = {}
    for key_name, key_val in pairs(keycodes) do
        --if FilterPassThorugh(key_name) then goto continue end 
        if reaper.ImGui_IsKeyPressed(ctx, key_val, true) then -- true so holding will perform many times
            active_keys[#active_keys+1] = key_val
        end
        --::continue::
    end
    
    -- mods
    local mods = reaper.ImGui_GetKeyMods(ctx)
    if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_ModCtrl()) then 
        active_keys[#active_keys+1] = 17 
    end -- ctrl
    if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_ModShift()) then
        active_keys[#active_keys+1] = 16 
    end -- Shift
    if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_ModAlt()) then
        active_keys[#active_keys+1] = 18
    end -- Alt


    --Send Message
    if LastWindowFocus then 
        if #active_keys > 0  then
            for k, key_val in pairs(active_keys) do
                PostKey(LastWindowFocus, key_val)
            end
        end
    end

    -- Get focus window (if not == Script Title)
    local win_focus = reaper.JS_Window_GetFocus()
    local win_name = reaper.JS_Window_GetTitle( win_focus )

    if LastWindowFocus ~= win_focus and (win_name == 'trackview' or win_name == 'midiview')  then -- focused win title is different from script title? INSERT HERE HOW YOU NAME THE SCRIPT
        LastWindowFocus = win_focus
    end    
end

function GetModKeys()
    -- mods
    local mods = reaper.ImGui_GetKeyMods(ctx)
    Ctrl =  reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_ModCtrl())
    Shift = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_ModShift())
    Alt =   reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_ModAlt())
    return Ctrl, Shift, Alt
end

function CheckPreventPassThrough(condition, name, preventpasskey) -- add an identifier from the source that turned off the PassThrough

    local key_used = GetSourceKey(name, preventpasskey)

    if condition and (not preventpasskey or not key_used)then -- Check if there is the condition to turn true preventpasskey and if it is already on the list(if any)
        preventpasskey = preventpasskey or {}
        local new_val = {
            source = name,
            bol = true
        }
        table.insert(preventpasskey,new_val)

    elseif not condition and preventpasskey and key_used then
        table.remove(preventpasskey,key_used)
    end

    if preventpasskey and #preventpasskey == 0 then

        preventpasskey = nil
    end 

    return preventpasskey
end

function GetSourceKey(name, preventpasskey)
    local key_used
    if preventpasskey then 
        for key, value in pairs(preventpasskey) do
            if preventpasskey[key].source == name then
                key_used = key
                break
            end 
        end
    end
    return key_used
end



function MenuBar()
    if reaper.ImGui_BeginMenuBar(ctx) then
        if reaper.ImGui_BeginMenu(ctx, 'Extra') then

            if reaper.ImGui_MenuItem(ctx, 'Show Tool Tips',"",Settings.Tips) then
                Settings.Tips = not Settings.Tips
            end

            reaper.ImGui_EndMenu(ctx)

        end
        reaper.ImGui_EndMenuBar(ctx)
    end

    if reaper.ImGui_BeginMenuBar(ctx) then
        if reaper.ImGui_BeginMenu(ctx, 'Project Presets') then
            -- Save

            if reaper.ImGui_Button(ctx, 'Save Preset') then
                --PreventPassKeys = true
                PreventPassKeys2 = CheckPreventPassThrough(true, 'save preset', PreventPassKeys2)
                reaper.ImGui_OpenPopup(ctx, 'Save Preset')
            end

            local center = {reaper.ImGui_Viewport_GetCenter(reaper.ImGui_GetMainViewport(ctx))}
            reaper.ImGui_SetNextWindowPos(ctx, center[1], center[2], reaper.ImGui_Cond_Appearing(), 0.5, 0.5)

            if reaper.ImGui_BeginPopupModal(ctx, 'Save Preset', nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
                PreventPassKeys = true
                _, GUI_String_save = reaper.ImGui_InputText( ctx, 'Preset Name', GUI_String_save)
                reaper.ImGui_Separator(ctx)

                if reaper.ImGui_Button(ctx, 'Save', 120, 0) then
                    if GUI_String_save == '' then
                        GUI_String_save = 'Preset Nº '..(TableLen2(GlobalPresets)+1)
                    end
                    UserPresets[GUI_String_save] = {
                        Setting = table_copy(Settings),
                        Groups = table_copy(Groups)
                    }
                    PreventPassKeys2 = CheckPreventPassThrough(false, 'save preset', PreventPassKeys2)
                    reaper.ImGui_CloseCurrentPopup(ctx)
                end
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, 'Cancel', 120, 0) then
                    --PreventPassKeys = false
                    PreventPassKeys2 = CheckPreventPassThrough(false, 'save preset', PreventPassKeys2)
                    reaper.ImGui_CloseCurrentPopup(ctx)
                end
                reaper.ImGui_EndPopup(ctx)
            end

            -- Load
            if reaper.ImGui_BeginMenu(ctx, 'Load') then

                for key, value in pairs(UserPresets) do
                    if key == 'Settings' then 
                        goto gui_continue 
                    end
                    if key == 'Groups' then 
                        goto gui_continue 
                    end
                    if reaper.ImGui_MenuItem( ctx,  key) then
                       Settings = UserPresets[key].Setting
                       Groups = UserPresets[key].Groups
                    end

                   ::gui_continue::
                end
                reaper.ImGui_EndMenu(ctx)
            end

            --Remove
            if reaper.ImGui_BeginMenu(ctx, 'Remove') then

                for key, value in pairs(UserPresets) do
                    if key == 'Settings' then 
                        goto gui_continue 
                    end
                    if key == 'Groups' then 
                        goto gui_continue 
                    end

                   if reaper.ImGui_MenuItem( ctx,  key) then
                        UserPresets[key] = nil
                   end

                   ::gui_continue::
                end
                reaper.ImGui_EndMenu(ctx)
            end
            
            reaper.ImGui_EndMenu(ctx)
        end
        reaper.ImGui_EndMenuBar(ctx)
    end
    if Settings.Tips then ToolTip("Save/Load Presets in the Project. Store Groups, Item Selection and Settings") end


    if reaper.ImGui_BeginMenuBar(ctx) then
        if reaper.ImGui_BeginMenu(ctx, 'Presets') then
            -- Save

            if reaper.ImGui_Button(ctx, 'Save Preset') then
                --PreventPassKeys = true
                PreventPassKeys2 = CheckPreventPassThrough(true, 'save preset', PreventPassKeys2)
                reaper.ImGui_OpenPopup(ctx, 'Save Preset')
            end

            local center = {reaper.ImGui_Viewport_GetCenter(reaper.ImGui_GetMainViewport(ctx))}
            reaper.ImGui_SetNextWindowPos(ctx, center[1], center[2], reaper.ImGui_Cond_Appearing(), 0.5, 0.5)

            if reaper.ImGui_BeginPopupModal(ctx, 'Save Preset', nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
                _, GUI_String_save = reaper.ImGui_InputText( ctx, 'Preset Name', GUI_String_save)
                reaper.ImGui_Separator(ctx)

                if reaper.ImGui_Button(ctx, 'Save', 120, 0) then
                    if GUI_String_save == '' then
                        GUI_String_save = 'Preset Nº '..(TableLen2(GlobalPresets)+1)
                    end

                    --PreventPassKeys = false
                    PreventPassKeys2 = CheckPreventPassThrough(false, 'save preset', PreventPassKeys2)
                    GlobalPresets[GUI_String_save] = {
                        Settings = table_copy(Settings),
                        Groups = table_copy(Groups)
                    }
                    -- Dont Save Project Userdata
                    for k , v in pairs(GlobalPresets[GUI_String_save].Groups) do 
                        GlobalPresets[GUI_String_save].Groups[k].list_sequence = nil
                    end

                    GlobalPresets[GUI_String_save].Settings.ListMidi = nil -- ????? PRECISA
                    save_json(script_path, 'user_presets_complete', GlobalPresets)

                    reaper.ImGui_CloseCurrentPopup(ctx)
                end
                reaper.ImGui_SameLine(ctx)
                if reaper.ImGui_Button(ctx, 'Cancel', 120, 0) then
                    --PreventPassKeys = false
                    PreventPassKeys2 = CheckPreventPassThrough(false, 'save preset', PreventPassKeys2)
                    reaper.ImGui_CloseCurrentPopup(ctx) 
                end
                reaper.ImGui_EndPopup(ctx)
            end

            -- Load
            if reaper.ImGui_BeginMenu(ctx, 'Load') then

                for key, value in pairs(GlobalPresets) do
                    if reaper.ImGui_MenuItem( ctx,  key) then
                        Settings = table_copy(GlobalPresets[key].Settings)
                        Groups = table_copy(GlobalPresets[key].Groups)
                    end
                end
                reaper.ImGui_EndMenu(ctx)
            end

            --Remove
            if reaper.ImGui_BeginMenu(ctx, 'Remove') then

                for key, value in pairs(GlobalPresets) do
                    if key == 'Settings' then 
                        goto gui_continue 
                    end
                    if key == 'Groups' then 
                        goto gui_continue 
                    end

                   if reaper.ImGui_MenuItem( ctx,  key) then
                        GlobalPresets[key] = nil
                        save_json(script_path, 'user_presets_complete', GlobalPresets)
                   end

                   ::gui_continue::
                end
                reaper.ImGui_EndMenu(ctx)
            end
            
            reaper.ImGui_EndMenu(ctx)
        end
        if Settings.Tips then ToolTip("Save/Load Presets Globally. Store Groups and Settings") end


        -- Dock
        local reval_dock =  reaper.ImGui_IsWindowDocked(ctx)
        local dock_text =  reval_dock and  'Undock' or 'Dock'

        if reaper.ImGui_MenuItem(ctx,dock_text ) then
            if reval_dock then -- Already Docked
                SetDock = 0
            else -- Not docked
                SetDock = -3 -- Dock to the right 
            end
        end
        reaper.ImGui_EndMenuBar(ctx)
    end
    
end

function CheckRequirements()
    local wind_name = 'Item Sampler'
    if not reaper.APIExists('ImGui_GetVersion') then
        reaper.ShowMessageBox('Please Install ReaImGui at ReaPack', wind_name, 0)
        return false
    end    

    if not reaper.APIExists('JS_ReaScriptAPI_Version') then
        reaper.ShowMessageBox('Please Install js_ReaScriptAPI at ReaPack', wind_name, 0)
        return false
    end    

    if  not reaper.APIExists('CF_GetSWSVersion') then
        reaper.ShowMessageBox('Please Install SWS at www.sws-extension.org', wind_name, 0)
        return false
    end
    --[[  -- meh for comparing versions
    --local major, minor, patch = string.match(AppVersion, "(%d+)%.(%d+)%.(%d+)")
    local sws_version = reaper.CF_GetSWSVersion()
    local sws_min = '2.12.1'

    if not CompareVersions(sws_version,sws_min) then
        local bol = reaper.ShowMessageBox('Please Update SWS at www.sws-extension.org\nYou are running version: '..sws_version..'\nMin Version is: '..sws_min..'\nRun Anyway?', wind_name, 4)
        return bol == 6
    end

    local version =  reaper.GetAppVersion()
    print(version)
    local min = '6.50'

    if not CompareVersions(version,min) then
        local bol = reaper.ShowMessageBox('Please Update Reaper\nYou are running version: '..version..'\nMin Version is: '..min..'\nRun Anyway?', wind_name, 4)
        return bol == 6
    end ]]

    --print(reaper.ImGui_GetVersion())
    --print(reaper.JS_ReaScriptAPI_Version())
    --print(reaper.CF_GetSWSVersion())
    return true 
end

function CheckProjChange() 
    local current_proj = reaper.EnumProjects(-1)
    local current_path = GetFullProjectPath()
    if OldProj or OldPath  then  -- Not First run
        if OldProj ~= current_proj or OldPath ~= current_path then -- Changed the path (can be caused by a new save or dif project but it doesnt matter as it will just reload Snapshot and Configs)
            salvar(OldProj)
            ProjectPath = GetProjectPath()
            LoadInitialPreseetGroups()
        end
    end 
    OldPath = current_path
    OldProj = current_proj        
end

function PushStyle()
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_Alpha(),               1)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_DisabledAlpha(),       0.62)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(),       8, 8)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(),      0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowBorderSize(),    1)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowMinSize(),       32, 32)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowTitleAlign(),    0, 0.5)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(),       0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildBorderSize(),     1)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_PopupRounding(),       0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_PopupBorderSize(),     1)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(),        4, 3)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(),       3)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(),     1)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(),         8, 4)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemInnerSpacing(),    4, 4)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_IndentSpacing(),       21)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_CellPadding(),         4, 2)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarSize(),       14)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarRounding(),   9)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabMinSize(),         10)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabRounding(),        3)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_TabRounding(),         4)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ButtonTextAlign(),     0.5, 0.5)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_SelectableTextAlign(), 0, 0)


    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(),                  0xFFFFFFFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextDisabled(),          0x808080FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(),              0x000000FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(),               0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PopupBg(),               0x141414F0)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(),                0x6E6E8080)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_BorderShadow(),          0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(),               0x5C5C5C8A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(),        0x42FA8366)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(),         0x44FA42AB)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(),               0x0A0A0AFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(),         0x294A7AFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgCollapsed(),      0x00000082)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_MenuBarBg(),             0x242424FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarBg(),           0x05050587)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrab(),         0x4F4F4FFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrabHovered(),  0x696969FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrabActive(),   0x828282FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(),             0x00FE49FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(),            0x79BB6BFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(),      0xFFFFFFFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),                0x5A5A5A66)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(),         0xD7D8D6FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),          0x74BBFFFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(),                0xB9F8C347)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(),         0xFFFFFF72)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(),          0xFFFFFFC0)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Separator(),             0x6E6E8080)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SeparatorHovered(),      0x1A66BFC7)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SeparatorActive(),       0x1A66BFFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGrip(),            0x4296FA33)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGripHovered(),     0x4296FAAB)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGripActive(),      0x4296FAF2)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Tab(),                   0x2E5994DC)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabHovered(),            0x4296FACC)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabActive(),             0x3369ADFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabUnfocused(),          0x111A26F8)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabUnfocusedActive(),    0x23436CFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_DockingPreview(),        0x4296FAB3)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_DockingEmptyBg(),        0x333333FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PlotLines(),             0x9C9C9CFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PlotLinesHovered(),      0xFF6E59FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PlotHistogram(),         0xE6B300FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PlotHistogramHovered(),  0xFF9900FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableHeaderBg(),         0x303033FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableBorderStrong(),     0x4F4F59FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableBorderLight(),      0x3B3B40FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableRowBg(),            0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableRowBgAlt(),         0xFFFFFF0F)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextSelectedBg(),        0x4AFA4259)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_DragDropTarget(),        0xFFFF00E6)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_NavHighlight(),          0x4296FAFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_NavWindowingHighlight(), 0xFFFFFFB3)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_NavWindowingDimBg(),     0xCCCCCC33)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ModalWindowDimBg(),      0xCCCCCC59)
end

function PopStyle()
    reaper.ImGui_PopStyleVar(ctx, 25)
    
    reaper.ImGui_PopStyleColor(ctx, 55)
    
end


