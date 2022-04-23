-- @version 1.1.3
-- @author Daniel Lumertz
-- @provides
--    [nomain] utils/*.lua
--    [nomain] Clipboard Functions.lua
--    [nomain] General Functions.lua
--    [nomain] preset.lua
--    [nomain] Serialize Table.lua
--    [main] Clipboard Copy.lua

-- @changelog
--    + Update to the new Imgui System

local name = 'Clipboard '
local version = '1.1.2'

-- Configs

--
local info = debug.getinfo(1, 'S');
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
configs_filename = 'configs' -- Json name

dofile(script_path .. 'Serialize Table.lua') -- General Functions needed
dofile(script_path .. 'preset.lua') -- preset to work with JSON
dofile(script_path .. 'Clipboard Functions.lua') -- Functions to this script
dofile(script_path .. 'General Functions.lua') -- General Functions needed

function GuiInit()
    ctx = reaper.ImGui_CreateContext('Item Sequencer') -- Add VERSION TODO
    FONT = reaper.ImGui_CreateFont('sans-serif', 15) -- Create the fonts you need
    reaper.ImGui_AttachFont(ctx, FONT)-- Attach the fonts you need
    Configs = LoadConfigs(script_path, configs_filename)
    ClipboardTable, NamesList, ColorList =  UpdatePasteClipboard()
end

function loop()

    --local window_flags = reaper.ImGui_WindowFlags_MenuBar() 
    reaper.ImGui_SetNextWindowSize(ctx, 385, 385, reaper.ImGui_Cond_Once())-- Set the size of the windows.  Use in the 4th argument reaper.ImGui_Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2
    reaper.ImGui_PushFont(ctx, FONT) -- Says you want to start using a specific font
    --local gui_w , gui_h = reaper.ImGui_GetContentRegionAvail(ctx)

    local visible, open  = reaper.ImGui_Begin(ctx, name..version, true, window_flags)

    if visible then

        if Configs.AutoUpdate == true then ClipboardTable, NamesList, ColorList = UpdatePasteClipboard() end
        --------
        --YOUR GUI HERE
        --------
        for k, items in pairs(ClipboardTable) do
            reaper.ImGui_PushID(ctx, k)
            if ColorList[k] then reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),  ColorList[k]) end
            if reaper.ImGui_Button(ctx, NamesList[k], -1) then
                if not reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_ModCtrl()) then -- is ctrl down? 
                    if Configs.AutoPaste == true then
                        PasteList(items)
                        if Configs.AutoExit == true then open = false end
                    else
                        CopyList(items)
                        if Configs.AutoExit == true then open = false end
                    end
                else
                    ChangeSelection(items)
                end
            end
            --reaper.ImGui_ColorButton(ctx,  'desc_id', ColorList[k] ,  nil, nil, nil)
            if ColorList[k] then reaper.ImGui_PopStyleColor(ctx,1) end
            reaper.ImGui_PopID(ctx)
        end
        
        --Checkboxes
        if reaper.ImGui_Checkbox(ctx, 'Auto Close', Configs.AutoExit) then
            Configs.AutoExit = not Configs.AutoExit
            save_json(script_path, configs_filename, Configs)
        end

        ToolTip('Close Clipboard GUI after paste')

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Checkbox(ctx, 'Auto Update', Configs.AutoUpdate) then
            Configs.AutoUpdate = not Configs.AutoUpdate
            save_json(script_path, configs_filename, Configs)
        end
        
        ToolTip('Auto Update Clipboard for new copies')

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Checkbox(ctx, 'Auto Paste', Configs.AutoPaste) then
            Configs.AutoPaste = not Configs.AutoPaste
            save_json(script_path, configs_filename, Configs)
        end

        ToolTip('ON: Clicking item button paste in the arrange\nOFF: Clicking item button copies item selection without pasting(user paste manually with Ctrl+V)')

        --Max
        retval, Configs.Max = reaper.ImGui_InputInt(ctx, 'Max', Configs.Max)
        if retval then 
            save_json(script_path, configs_filename, Configs)
        end

        --Buttons
        if reaper.ImGui_Button(ctx, 'Update', -1) then
            ClipboardTable, NamesList, ColorList =  UpdatePasteClipboard()
        end

        if reaper.ImGui_Button(ctx, 'Clean Clipboard', -1) then
            SaveClipboardTable({})
            ClipboardTable, NamesList, ColorList =  UpdatePasteClipboard()
        end
        

        --------
        reaper.ImGui_End(ctx)
    end 


    reaper.ImGui_PopFont(ctx) -- Pop Font

    if open then
        reaper.defer(loop)
    else
        reaper.ImGui_DestroyContext(ctx)
    end
end

function saida()
    save_json(script_path, configs_filename, Configs)
end

GuiInit()
loop()
reaper.atexit(saida)
