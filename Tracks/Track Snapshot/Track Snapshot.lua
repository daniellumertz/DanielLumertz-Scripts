-- @version 1.4.11
-- @author Daniel Lumertz
-- @license MIT
-- @provides
--    [nomain] utils/*.lua
--    [nomain] Chunk Functions.lua
--    [main] Delete Snapshots on Project.lua
--    [nomain] General Functions.lua
--    [nomain] GUI Functions.lua
--    [nomain] Serialize Table.lua
--    [nomain] Track Snapshot Functions.lua
--    [nomain] Track Snapshot Send Functions.lua
--    [nomain] theme.lua
--    [nomain] Style Editor.lua
--    [nomain] REAPER Functions.lua
-- @changelog
--    + Revert to 0.9 key management

--dofile("C:/Users/DSL/AppData/Roaming/REAPER/Scripts/Meus/Debug VS/DL Debug.lua")

ScriptName = 'Track Snapshot' -- Use to call Extstate dont change
ScriptVersion = '1.4.11'

local info = debug.getinfo(1, 'S');
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
configs_filename = 'configs' -- Json ScriptName


dofile(script_path .. 'Serialize Table.lua') -- preset to work with Tables
dofile(script_path .. 'Track Snapshot Functions.lua') -- Functions to this script
dofile(script_path .. 'General Functions.lua') -- General Functions needed
dofile(script_path .. 'GUI Functions.lua') -- General Functions needed
dofile(script_path .. 'Chunk Functions.lua') -- General Functions needed
dofile(script_path .. 'theme.lua') -- General Functions needed
dofile(script_path .. 'Track Snapshot Send Functions.lua') -- General Functions needed
dofile(script_path .. 'REAPER Functions.lua') -- preset to work with Tables


if not CheckSWS() or not CheckReaImGUI() or not CheckJS() then return end
-- Imgui shims to 0.7.2 (added after the news at 0.8)
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.7.2')


--dofile(script_path .. 'Style Editor.lua') -- Remember to remove


--- configs
Configs = {}
Configs.ShowAll = false

function GuiInit()
    ctx = reaper.ImGui_CreateContext('Track Snapshot',reaper.ImGui_ConfigFlags_DockingEnable()) 
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
    if not PreventPassKeys then -- Passthrough keys
        PassThorugh()
    end

    PushTheme() -- Theme
    --StyleLoop()
    --PushStyle()
    CheckProjChange()
    
    local window_flags = reaper.ImGui_WindowFlags_MenuBar() 
    reaper.ImGui_SetNextWindowSize(ctx, 200, 420, reaper.ImGui_Cond_Once())-- Set the size of the windows.  Use in the 4th argument reaper.ImGui_Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2
    reaper.ImGui_PushFont(ctx, FONT) -- Says you want to start using a specific font

    if SetDock then
        reaper.ImGui_SetNextWindowDockID(ctx, SetDock)
        if SetDock== 0 then
            reaper.ImGui_SetNextWindowSize(ctx, 200, 420)
        end
        SetDock = nil
    end

    local visible, open  = reaper.ImGui_Begin(ctx, ScriptName..' '..ScriptVersion, true, window_flags)

    if visible then
        -------
        --MENU
        -------
        if reaper.ImGui_BeginMenuBar(ctx) then
            ConfigsMenu()
            AboutMenu()
            DockBtn()
            if Configs.VersionMode then
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(),   0xFF4848FF)
                reaper.ImGui_Text(ctx, 'V.')
                reaper.ImGui_PopStyleColor(ctx, 1)
                if Configs.ToolTips then ToolTip('Track Version Mode ON') end
            end
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
                    local selected = (Configs.Select or Configs.VersionMode) and Snapshot[i].Selected -- If Configs.Select  or Configs.VersionMode is false then false. If one is true then Snaphot[i].Selected
                    local click = reaper.ImGui_Selectable(ctx, Snapshot[i].Name..'###'..i, selected) 
                    if click then
                        if not reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_ModShift()) then 
                        -- Load Chunk in tracks
                            SetSnapshot(i)
                        elseif reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_ModShift()) then
                            SetSnapshotInNewTracks(i)
                        end
                    end

                    if Snapshot[i].Shortcut and not Configs.PreventShortcut then 
                        WriteShortkey(Snapshot[i].Shortcut,255,255,255,100)
                        local keycode = GetKeycode(Snapshot[i].Shortcut)
                        if reaper.ImGui_IsKeyPressed(ctx, keycode, false) then 
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

        OpenPopups(TempPopup_i)
        --------
        reaper.ImGui_End(ctx)
    end
    --PopStyle()
    PopTheme()
 


    reaper.ImGui_PopFont(ctx) -- Pop Font

    if open and reaper.ImGui_IsKeyPressed(ctx, 27) == false then
        reaper.defer(loop)
    else
        reaper.ImGui_DestroyContext(ctx)
    end
end


Init()
loop()
reaper.atexit(SaveSnapshotConfig)
