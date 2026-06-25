-- @noindex
DL = DL or {}
DL.imgui = DL.imgui or {}

---Stores key-related configuration for ImGui interactions, including keys to bypass from standard processing.
DL.imgui.keys = {
    --table with all keys to bypass from SWSPassKeys. Store the key code as indexes at this table, like this: DL.imgui.keys.bypass[	0x56] = true. https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
    bypass = {

    }
} 

local held_keys = {}
if reaper.JS_VKeys_GetState then -- add held notes at script start to the table
    local keys = reaper.JS_VKeys_GetState(0)
    for k = 1, #keys do
        if  keys:byte(k) ~= 0 then
            held_keys[k] = true
        end
    end
end
---Pass some key  to reaper
---@param ctx any
---@param is_midieditor any
function DL.imgui.SWSPassKeys(ctx, is_midieditor)
    if not reaper.CF_SendActionShortcut or not reaper.JS_VKeys_GetState then return end
    if (not ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_AnyWindow)) or ImGui.IsAnyItemActive(ctx) then return end -- Only when Script haves the focus

    local sel_window, section 
    if is_midieditor then
        local midi = reaper.MIDIEditor_GetActive()
        if midi then 
            sel_window = midi 
            section = 32060
        end
    end

    if not sel_window then -- Send to Main Window or Midi Editor closed
        sel_window = reaper.GetMainHwnd()
        section = 0
    end

    local keys = reaper.JS_VKeys_GetState(0)
    for k = 1, #keys do
        local is_key = keys:byte(k) ~= 0
        if k ~= 0xD and is_key and not held_keys[k] then
            if not DL.imgui.keys.bypass[k] then
                reaper.CF_SendActionShortcut(sel_window, section, k)
            end
            held_keys[k] = true
        elseif not is_key and held_keys[k] then
            held_keys[k] = nil
        end
    end

    if ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
        reaper.CF_SendActionShortcut(sel_window, section, 0xD)
    end
    if ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter) then
        reaper.CF_SendActionShortcut(sel_window, section, 0x800D)
    end  
end

function GetModKeys()
    -- mods
    local mods = ImGui.GetKeyMods(ctx)
    Ctrl =  ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)
    Shift = ImGui.IsKeyDown(ctx, ImGui.Mod_Shift)
    Alt =   ImGui.IsKeyDown(ctx, ImGui.Mod_Alt)
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
    if ImGui.BeginMenuBar(ctx) then
        if ImGui.BeginMenu(ctx, 'Extra') then
            if ImGui.MenuItem(ctx, 'Show Tool Tips',"",Settings.Tips) then
                Settings.Tips = not Settings.Tips
            end
            ImGui.EndMenu(ctx)
        end

        --[[ if ImGui.BeginMenu(ctx, 'Project Presets') then
            -- Save

            if ImGui.Button(ctx, 'Save Preset') then
                --PreventPassKeys = true
                PreventPassKeys2 = CheckPreventPassThrough(true, 'save preset', PreventPassKeys2)
                ImGui.OpenPopup(ctx, 'Save Preset')
            end

            local center = {ImGui.Viewport_GetCenter(ImGui.GetMainViewport(ctx))}
            ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing(), 0.5, 0.5)

            if ImGui.BeginPopupModal(ctx, 'Save Preset', nil, ImGui.WindowFlags_AlwaysAutoResize()) then
                PreventPassKeys = true
                _, GUI_String_save = ImGui.InputText( ctx, 'Preset Name', GUI_String_save)
                ImGui.Separator(ctx)

                if ImGui.Button(ctx, 'Save', 120, 0) then
                    if GUI_String_save == '' then
                        GUI_String_save = 'Preset Nº '..(TableLen2(GlobalPresets)+1)
                    end
                    UserPresets[GUI_String_save] = {
                        Setting = table_copy(Settings),
                        Groups = table_copy(Groups)
                    }
                    PreventPassKeys2 = CheckPreventPassThrough(false, 'save preset', PreventPassKeys2)
                    ImGui.CloseCurrentPopup(ctx)
                end
                ImGui.SameLine(ctx)
                if ImGui.Button(ctx, 'Cancel', 120, 0) then
                    --PreventPassKeys = false
                    PreventPassKeys2 = CheckPreventPassThrough(false, 'save preset', PreventPassKeys2)
                    ImGui.CloseCurrentPopup(ctx)
                end
                ImGui.EndPopup(ctx)
            end

            -- Load
            if ImGui.BeginMenu(ctx, 'Load') then

                for key, value in pairs(UserPresets) do
                    if key == 'Settings' then 
                        goto gui_continue 
                    end
                    if key == 'Groups' then 
                        goto gui_continue 
                    end
                    if ImGui.MenuItem( ctx,  key) then
                       Settings = UserPresets[key].Setting
                       Groups = UserPresets[key].Groups
                    end

                   ::gui_continue::
                end
                ImGui.EndMenu(ctx)
            end

            --Remove
            if ImGui.BeginMenu(ctx, 'Remove') then

                for key, value in pairs(UserPresets) do
                    if key == 'Settings' then 
                        goto gui_continue 
                    end
                    if key == 'Groups' then 
                        goto gui_continue 
                    end

                   if ImGui.MenuItem( ctx,  key) then
                        UserPresets[key] = nil
                   end

                   ::gui_continue::
                end
                ImGui.EndMenu(ctx)
            end
            
            ImGui.EndMenu(ctx)
        end ]]

        --[[ if ImGui.BeginMenu(ctx, 'Presets') then
            -- Save

            if ImGui.Button(ctx, 'Save Preset') then
                --PreventPassKeys = true
                PreventPassKeys2 = CheckPreventPassThrough(true, 'save preset', PreventPassKeys2)
                ImGui.OpenPopup(ctx, 'Save Preset')
            end

            local center = {ImGui.Viewport_GetCenter(ImGui.GetMainViewport(ctx))}
            ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing(), 0.5, 0.5)

            if ImGui.BeginPopupModal(ctx, 'Save Preset', nil, ImGui.WindowFlags_AlwaysAutoResize()) then
                _, GUI_String_save = ImGui.InputText( ctx, 'Preset Name', GUI_String_save)
                ImGui.Separator(ctx)

                if ImGui.Button(ctx, 'Save', 120, 0) then
                    if GUI_String_save == '' then
                        GUI_String_save = 'Preset Nº '..(TableLen2(GlobalPresets)+1)
                    end

                    --PreventPassKeys = false
                    PreventPassKeys2 = CheckPreventPassThrough(false, 'save preset', PreventPassKeys2)
                    GlobalPresets[GUI_String_save] = {
                        Groups = table_copy(Groups)
                    }
                    -- Dont Save Project Userdata
                    for k , v in pairs(GlobalPresets[GUI_String_save].Groups) do 
                        GlobalPresets[GUI_String_save].Groups[k].Settings.list_sequence = nil
                        GlobalPresets[GUI_String_save].Groups[k].Settings.Targets = nil
                    end

                    GlobalPresets[GUI_String_save].Settings.ListMidi = nil -- ????? PRECISA
                    save_json(script_path, 'user_presets_complete', GlobalPresets)

                    ImGui.CloseCurrentPopup(ctx)
                end
                ImGui.SameLine(ctx)
                if ImGui.Button(ctx, 'Cancel', 120, 0) then
                    --PreventPassKeys = false
                    PreventPassKeys2 = CheckPreventPassThrough(false, 'save preset', PreventPassKeys2)
                    ImGui.CloseCurrentPopup(ctx) 
                end
                ImGui.EndPopup(ctx)
            end

            -- Load
            if ImGui.BeginMenu(ctx, 'Load') then

                for key, value in pairs(GlobalPresets) do
                    if ImGui.MenuItem( ctx,  key) then
                        Settings = table_copy(GlobalPresets[key].Settings)
                        Groups = table_copy(GlobalPresets[key].Groups)
                    end
                end
                ImGui.EndMenu(ctx)
            end

            --Remove
            if ImGui.BeginMenu(ctx, 'Remove') then

                for key, value in pairs(GlobalPresets) do
                    if key == 'Settings' then 
                        goto gui_continue 
                    end
                    if key == 'Groups' then 
                        goto gui_continue 
                    end

                   if ImGui.MenuItem( ctx,  key) then
                        GlobalPresets[key] = nil
                        save_json(script_path, 'user_presets_complete', GlobalPresets)
                   end

                   ::gui_continue::
                end
                ImGui.EndMenu(ctx)
            end
            
            ImGui.EndMenu(ctx)
        end ]]
        if Settings.Tips then ToolTip("Save/Load Presets Globally. Store Groups and Settings") end

        -- Dock
        local reval_dock =  ImGui.IsWindowDocked(ctx)
        local dock_text =  reval_dock and  'Undock' or 'Dock'

        if ImGui.MenuItem(ctx,dock_text ) then
            if reval_dock then -- Already Docked
                SetDock = 0
            else -- Not docked
                SetDock = -3 -- Dock to the right 
            end
        end
        ImGui.EndMenuBar(ctx)
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

    --print(ImGui.GetVersion())
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
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha,               1)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_DisabledAlpha,       0.62)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,       8, 8)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding,      0)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowBorderSize,    1)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowMinSize,       32, 32)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowTitleAlign,    0, 0.5)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildRounding,       0)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildBorderSize,     1)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding,       0)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupBorderSize,     1)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding,        4, 3)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding,       3)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize,     1)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing,         8, 4)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemInnerSpacing,    4, 4)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_IndentSpacing,       21)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_CellPadding,         4, 2)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ScrollbarSize,       14)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ScrollbarRounding,   9)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_GrabMinSize,         10)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_GrabRounding,        3)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_TabRounding,         4)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ButtonTextAlign,     0.5, 0.5)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_SelectableTextAlign, 0, 0)


    ImGui.PushStyleColor(ctx, ImGui.Col_Text,                  0xFFFFFFFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_TextDisabled,          0x808080FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg,              0x000000FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg,               0x00000000)
    ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg,               0x141414F0)
    ImGui.PushStyleColor(ctx, ImGui.Col_Border,                0x6E6E8080)
    ImGui.PushStyleColor(ctx, ImGui.Col_BorderShadow,          0x00000000)
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg,               0x5C5C5C8A)
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered,        0x42FA8366)
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive,         0x44FA42AB)
    ImGui.PushStyleColor(ctx, ImGui.Col_TitleBg,               0x0A0A0AFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_TitleBgActive,         0x294A7AFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_TitleBgCollapsed,      0x00000082)
    ImGui.PushStyleColor(ctx, ImGui.Col_MenuBarBg,             0x242424FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_ScrollbarBg,           0x05050587)
    ImGui.PushStyleColor(ctx, ImGui.Col_ScrollbarGrab,         0x4F4F4FFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_ScrollbarGrabHovered,  0x696969FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_ScrollbarGrabActive,   0x828282FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_CheckMark,             0x00FE49FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrab,            0x79BB6BFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrabActive,      0xFFFFFFFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_Button,                0x5A5A5A66)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered,         0xD7D8D6FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive,          0x74BBFFFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_Header,                0xB9F8C347)
    ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered,         0xFFFFFF72)
    ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive,          0xFFFFFFC0)
    ImGui.PushStyleColor(ctx, ImGui.Col_Separator,             0x6E6E8080)
    ImGui.PushStyleColor(ctx, ImGui.Col_SeparatorHovered,      0x1A66BFC7)
    ImGui.PushStyleColor(ctx, ImGui.Col_SeparatorActive,       0x1A66BFFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_ResizeGrip,            0x4296FA33)
    ImGui.PushStyleColor(ctx, ImGui.Col_ResizeGripHovered,     0x4296FAAB)
    ImGui.PushStyleColor(ctx, ImGui.Col_ResizeGripActive,      0x4296FAF2)
    ImGui.PushStyleColor(ctx, ImGui.Col_Tab,                   0x2E5994DC)
    ImGui.PushStyleColor(ctx, ImGui.Col_TabHovered,            0x4296FACC)
    --ImGui.PushStyleColor(ctx, ImGui.Col_TabActive,             0x3369ADFF)
    --ImGui.PushStyleColor(ctx, ImGui.Col_TabUnfocused,          0x111A26F8)
    --ImGui.PushStyleColor(ctx, ImGui.Col_TabUnfocusedActive,    0x23436CFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_DockingPreview,        0x4296FAB3)
    ImGui.PushStyleColor(ctx, ImGui.Col_DockingEmptyBg,        0x333333FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_PlotLines,             0x9C9C9CFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_PlotLinesHovered,      0xFF6E59FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_PlotHistogram,         0xE6B300FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_PlotHistogramHovered,  0xFF9900FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_TableHeaderBg,         0x303033FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_TableBorderStrong,     0x4F4F59FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_TableBorderLight,      0x3B3B40FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_TableRowBg,            0x00000000)
    ImGui.PushStyleColor(ctx, ImGui.Col_TableRowBgAlt,         0xFFFFFF0F)
    ImGui.PushStyleColor(ctx, ImGui.Col_TextSelectedBg,        0x4AFA4259)
    ImGui.PushStyleColor(ctx, ImGui.Col_DragDropTarget,        0xFFFF00E6)
    --ImGui.PushStyleColor(ctx, ImGui.Col_NavHighlight,          0x4296FAFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_NavWindowingHighlight, 0xFFFFFFB3)
    ImGui.PushStyleColor(ctx, ImGui.Col_NavWindowingDimBg,     0xCCCCCC33)
    ImGui.PushStyleColor(ctx, ImGui.Col_ModalWindowDimBg,      0xCCCCCC59)
end

function PopStyle()
    ImGui.PopStyleVar(ctx, 25)
    
    ImGui.PopStyleColor(ctx, 51)
    
end


