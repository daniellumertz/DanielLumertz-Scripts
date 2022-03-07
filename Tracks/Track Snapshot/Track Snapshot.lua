-- @version 1.0.2
-- @author Daniel Lumertz
-- @provides
--    [nomain] utils/*.lua
--    [nomain] Chunk Functions.lua
--    [main] Delete Snapshots on Project.lua
--    [nomain] General Functions.lua
--    [nomain] GUI Functions.lua
--    [nomain] Serialize Table.lua
--    [nomain] Track Snapshot Functions.lua

-- @changelog
--    + Small fix passing Redo Action to main

ScriptName = 'Track Snapshot' -- Use to call Extstate dont change
version = '1.0.2'

local info = debug.getinfo(1, 'S');
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
configs_filename = 'configs' -- Json ScriptName

dofile(script_path .. 'Serialize Table.lua') -- preset to work with Tables
dofile(script_path .. 'Track Snapshot Functions.lua') -- Functions to this script
dofile(script_path .. 'General Functions.lua') -- General Functions needed
dofile(script_path .. 'GUI Functions.lua') -- General Functions needed
dofile(script_path .. 'Chunk Functions.lua') -- General Functions needed

--- configs
Configs = {}
Configs.ShowAll = false

function GuiInit()
    ctx = reaper.ImGui_CreateContext('Item Sequencer') -- Add VERSION TODO
    FONT = reaper.ImGui_CreateFont('sans-serif', 15) -- Create the fonts you need
    font_mini = reaper.ImGui_CreateFont('sans-serif', 13) -- Create the fonts you need
    reaper.ImGui_AttachFont(ctx, FONT)-- Attach the fonts you need
    reaper.ImGui_AttachFont(ctx, font_mini)-- Attach the fonts you need
end

function Init()
    Snapshot = LoadSnapshot()
    Configs = LoadConfigs()
    GuiInit()
end

function loop()
    local window_flags = reaper.ImGui_WindowFlags_MenuBar() 
    reaper.ImGui_SetNextWindowSize(ctx, 200, 420, reaper.ImGui_Cond_Once())-- Set the size of the windows.  Use in the 4th argument reaper.ImGui_Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2
    reaper.ImGui_PushFont(ctx, FONT) -- Says you want to start using a specific font

    local visible, open  = reaper.ImGui_Begin(ctx, ScriptName..' '..version, true, window_flags)

    if visible then
        -------
        --MENU
        -------
        if reaper.ImGui_BeginMenuBar(ctx) then
            ConfigsMenu()
            reaper.ImGui_EndMenuBar(ctx)
        end

        --------
        -- GUI Body
        --------
        GuiLoadChunkOption()

        if reaper.ImGui_Button(ctx, 'Save Snapshot',-1) then
            SaveSnapshot()
        end


        -- Get Snapshots for selected tracks and set Snapshot[i].Visible
        -- List
        if Configs.ShowAll == false then
            UpdateSnapshotVisible()
        else
            CheckTracksMissing()
        end

        if reaper.ImGui_BeginListBox(ctx,  '###label',-1,-1) then
            for i, v in pairs(Snapshot) do
                if Snapshot[i].Visible == true or Configs.ShowAll == true then 
                    reaper.ImGui_PushID(ctx, i)
                    local click = reaper.ImGui_Selectable(ctx, Snapshot[i].Name..'###'..i, false)
                    if click then -- or Snapshot[i].Selected instead of false
                        if (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_KeyModFlags_Shift()) == 0 then 
                        -- Load Chunk in tracks
                            SetSnapshot(i)
                        elseif (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_KeyModFlags_Shift()) == 2 then
                            SetSnapshotInNewTracks(i)
                        end
                    end

                    if Snapshot[i].Shortcut and not Configs.PreventShortcut then 
                        WriteShortkey(Snapshot[i].Shortcut,255,255,255,100)
                        local keycode = GetKeycode(Snapshot[i].Shortcut)
                        if reaper.ImGui_IsKeyDown(ctx, keycode) then 
                            SetSnapshot(i)
                        end
                    end

                    if Snapshot[i].MissTrack then
                        DrawRectLastItem(200,100,20,66)
                        if Configs.ToolTips then ToolTip("Some track saved in this snapshot is missing in your project. Right click to see which one and recover it. You still can load this snapshot, it will only load in tracks that exist in the project") end
                    end
                    SnapshotRightClickPopUp(i)
                    reaper.ImGui_PopID(ctx)
                end
            end
            reaper.ImGui_EndListBox(ctx)
        end


        --------
        reaper.ImGui_End(ctx)
    end 

    PassThorugh()

    reaper.ImGui_PopFont(ctx) -- Pop Font

    if open then
        reaper.defer(loop)
    else
        reaper.ImGui_DestroyContext(ctx)
    end
end


Init()
loop()
reaper.atexit(saida)
