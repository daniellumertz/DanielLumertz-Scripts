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



function MenuBar(ctx, UserSettings, GUI, config, version, Pro)
    if ImGui.BeginMenuBar(ctx) then
        if ImGui.BeginMenu(ctx, 'Options') then
            if ImGui.MenuItem(ctx, 'Show Tool Tips', nil, UserSettings.tips) then
                UserSettings.tips = not UserSettings.tips
                GUI.is_save_us.check = true
            end

            if ImGui.MenuItem(ctx, 'Reset Settings') then
                UserSettings = config.default(version)
                GUI.is_save_us.check = true
            end

            if ImGui.MenuItem(ctx, 'Activated Sequencer Follows Selection', nil, UserSettings.activate.follow_selection) then
                UserSettings.activate.follow_selection = not UserSettings.activate.follow_selection 
                GUI.is_save_us.check = true
            end

            if ImGui.MenuItem(ctx, 'MIDI Note Names Follow Group Names', nil, UserSettings.activate.follow_selection) then
                UserSettings.sequencers.rename_note_names = not UserSettings.sequencers.rename_note_names
                -- Cleans or update the note names
                if UserSettings.sequencers.rename_note_names then
                end
                GUI.is_save_us.check = true    
            end


            ImGui.Separator(ctx)

            if ImGui.MenuItem(ctx, 'Draw Over Items/Tracks',"",UserSettings.gui.draw.active.is_draw) then
                UserSettings.gui.draw.active.is_draw = not UserSettings.gui.draw.active.is_draw
                GUI.is_save_us.check = true
            end
            if UserSettings.gui.draw.active.is_draw then
                if ImGui.BeginMenu(ctx, 'Draw Options') then
                    local dmenu = {
                        {
                            text = 'Focused Sequencers:',
                            configs = UserSettings.gui.draw.focused
                        },
                        {
                            text = 'Active Sequencers:',
                            configs = UserSettings.gui.draw.active
                        },
                        {
                            text = 'Target Tracks:',
                            configs = UserSettings.gui.draw.target_tracks
                        },
                        {
                            text = 'Sources:',
                            configs = UserSettings.gui.draw.sources
                        },
                    }
                    for k, menu in ipairs(dmenu) do          
                        ImGui.Text(ctx, menu.text)
                        local change
                        if not menu.configs.is_multicolor then
                            GUI.is_save_us.check, menu.configs.color = ImGui.ColorEdit4(ctx, '##color'..k, menu.configs.color, ImGui.ColorEditFlags_NoInputs)
                        end
                        ImGui.SameLine(ctx)
                        --change, menu.configs.is_multicolor = ImGui.Checkbox(ctx, 'Use Multi-Color##'..k, menu.configs.is_multicolor)
                        ImGui.SetNextItemWidth(ctx, 150)
                        GUI.is_save_us.check, menu.configs.thick = ImGui.SliderInt(ctx, '##Thickness##'..k, menu.configs.thick, 1, 10)
                        if k ~= #dmenu then 
                            ImGui.Separator(ctx)
                        end
                    end
                    ImGui.EndMenu(ctx)
                end
            end
            ImGui.EndMenu(ctx)
        end
        
        if UserSettings.Tips then ToolTip("Save/Load Presets Globally. Store Groups and Settings") end

        -- Dock
        local reval_dock =  ImGui.IsWindowDocked(ctx)
        local dock_text =  reval_dock and  'Undock' or 'Dock'

        if ImGui.MenuItem(ctx,dock_text) then
            if reval_dock then -- Already Docked
                SetDock = 0
            else -- Not docked
                SetDock = -3 -- Dock to the right 
            end
        end
        ImGui.EndMenuBar(ctx)
    end
    return UserSettings
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



function PushStyle(ctx)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text,                      0xFFFFFFFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_TextDisabled,              0x808080FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg,                  0x2C2C2CFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg,                   0x212121FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg,                   0x232323FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_Border,                    0x6E6E8080)
    ImGui.PushStyleColor(ctx, ImGui.Col_BorderShadow,              0x00000000)
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg,                   0x6969698A)
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered,            0x87C28E66)
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive,             0x6DF17D66)
    ImGui.PushStyleColor(ctx, ImGui.Col_TitleBg,                   0x383838DC)
    ImGui.PushStyleColor(ctx, ImGui.Col_TitleBgActive,             0x4E4E4EDC)
    ImGui.PushStyleColor(ctx, ImGui.Col_TitleBgCollapsed,          0x00000082)
    ImGui.PushStyleColor(ctx, ImGui.Col_MenuBarBg,                 0x242424FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_ScrollbarBg,               0x24242487)
    ImGui.PushStyleColor(ctx, ImGui.Col_ScrollbarGrab,             0x4F4F4FFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_ScrollbarGrabHovered,      0x696969FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_ScrollbarGrabActive,       0x828282FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_CheckMark,                 0x79BA8BFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrab,                0x79BA8BFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrabActive,          0x6BDC8AFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_Button,                    0x6969698A)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered,             0x87C28E66)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive,              0x6DF17D66)
    ImGui.PushStyleColor(ctx, ImGui.Col_Header,                    0x42FA514F)
    ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered,             0x87C28E66)
    ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive,              0x6DF17D66)
    ImGui.PushStyleColor(ctx, ImGui.Col_Separator,                 0xD8D8D880)
    ImGui.PushStyleColor(ctx, ImGui.Col_SeparatorHovered,          0xD8D8D880)
    ImGui.PushStyleColor(ctx, ImGui.Col_SeparatorActive,           0xD8D8D880)
    ImGui.PushStyleColor(ctx, ImGui.Col_ResizeGrip,                0x8EC19466)
    ImGui.PushStyleColor(ctx, ImGui.Col_ResizeGripHovered,         0x6DE67C66)
    ImGui.PushStyleColor(ctx, ImGui.Col_ResizeGripActive,          0x47F35A66)
    ImGui.PushStyleColor(ctx, ImGui.Col_InputTextCursor,           0xFFFFFFFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_TabHovered,                0x87C28E66)
    ImGui.PushStyleColor(ctx, ImGui.Col_Tab,                       0x6969698A)
    ImGui.PushStyleColor(ctx, ImGui.Col_TabSelected,               0xFFFFFF40)
    ImGui.PushStyleColor(ctx, ImGui.Col_TabSelectedOverline,       0x4296FAFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_TabDimmed,                 0x111A26F8)
    ImGui.PushStyleColor(ctx, ImGui.Col_TabDimmedSelected,         0x23436CFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_TabDimmedSelectedOverline, 0x80808000)
    ImGui.PushStyleColor(ctx, ImGui.Col_DockingPreview,            0x42FA68B3)
    ImGui.PushStyleColor(ctx, ImGui.Col_DockingEmptyBg,            0x333333FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_PlotLines,                 0x9C9C9CFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_PlotLinesHovered,          0xFF6E59FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_PlotHistogram,             0xE6B300FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_PlotHistogramHovered,      0xFF9900FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_TableHeaderBg,             0x303033FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_TableBorderStrong,         0x4F4F59FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_TableBorderLight,          0x9F9F9FFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_TableRowBg,                0x00000000)
    ImGui.PushStyleColor(ctx, ImGui.Col_TableRowBgAlt,             0xFFFFFF0F)
    ImGui.PushStyleColor(ctx, ImGui.Col_TextLink,                  0x4296FAFF)
    ImGui.PushStyleColor(ctx, ImGui.Col_TextSelectedBg,            0x42FA6859)
    ImGui.PushStyleColor(ctx, ImGui.Col_TreeLines,                 0x6E6E8080)
    ImGui.PushStyleColor(ctx, ImGui.Col_DragDropTarget,            0xFFFF00E6)
    ImGui.PushStyleColor(ctx, ImGui.Col_NavCursor,                 0x42FA89FF)
    ImGui.PushStyleColor(ctx, ImGui.Col_NavWindowingHighlight,     0xFFFFFFB3)
    ImGui.PushStyleColor(ctx, ImGui.Col_NavWindowingDimBg,         0xCCCCCC33)
    ImGui.PushStyleColor(ctx, ImGui.Col_ModalWindowDimBg,          0xCCCCCC59)





    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding,   6)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildRounding,    3)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding,     7, 2)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding,    3)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize,  1)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_TabRounding,      0)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_TabBorderSize,    1)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_TabBarBorderSize, 2)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_TreeLinesSize,    2)



end

function PopStyle()
    ImGui.PopStyleVar(ctx, 9)
    
    ImGui.PopStyleColor(ctx, 60)
    
end


