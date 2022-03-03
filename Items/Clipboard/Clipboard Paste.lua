-- @version 1.0
-- @author Daniel Lumertz
-- @provides
--    [nomain] utils/*.lua
--    [nomain] Clipboard Functions.lua
--    [nomain] General Functions.lua
--    [nomain] preset.lua
--    [nomain] Serialize Table.lua
--    Clipboard Copy.lua

-- @changelog
--    + Initial Release

local name = 'Clipboard '
local version = '1.0'

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
    reaper.ImGui_SetNextWindowSize(ctx, 250, 300, reaper.ImGui_Cond_Once())-- Set the size of the windows.  Use in the 4th argument reaper.ImGui_Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2
    reaper.ImGui_PushFont(ctx, FONT) -- Says you want to start using a specific font

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
                if not reaper.ImGui_IsKeyDown( ctx, 17 ) then -- is ctrl down? 
                    PasteList(items)
                    if Configs.AutoExit == true then open = false end
                else
                    ChangeSelection(items)
                end
            end
            --reaper.ImGui_ColorButton(ctx,  'desc_id', ColorList[k] ,  nil, nil, nil)
            if ColorList[k] then reaper.ImGui_PopStyleColor(ctx,1) end
            reaper.ImGui_PopID(ctx)
        end
        

        if reaper.ImGui_Checkbox(ctx, 'Auto Close', Configs.AutoExit) then
            Configs.AutoExit = not Configs.AutoExit
            save_json(script_path, configs_filename, Configs)
        end

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Checkbox(ctx, 'Auto Update', Configs.AutoUpdate) then
            Configs.AutoUpdate = not Configs.AutoUpdate
            save_json(script_path, configs_filename, Configs)
        end

        retval, Configs.Max = reaper.ImGui_InputInt(ctx, 'Max', Configs.Max)
        if retval then 
            save_json(script_path, configs_filename, Configs)
        end

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
