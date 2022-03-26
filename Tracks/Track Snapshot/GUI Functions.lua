-- @noindex
function DrawRectLastItem(r,g,b,a)
    local minx, miny = reaper.ImGui_GetItemRectMin(ctx)
    local maxx, maxy = reaper.ImGui_GetItemRectMax(ctx)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    --local color =  reaper.ImGui_ColorConvertRGBtoHSV( r,  g,  b,  a )
    local color =  rgba2num(r,  g,  b,  a)
    
    reaper.ImGui_DrawList_AddRectFilled(draw_list, minx-50, miny, maxx, maxy, color)
end

function WriteShortkey(key, r,g,b,a)
    local minx, miny = reaper.ImGui_GetItemRectMin(ctx)
    local maxx, maxy = reaper.ImGui_GetItemRectMax(ctx)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    local color =  rgba2num(r,  g,  b,  a)
    local text_w, text_h = reaper.ImGui_CalcTextSize(ctx, key, 1, 1)
    local pad = 5
    reaper.ImGui_DrawList_AddText(draw_list, maxx-text_w-pad, miny, color, key)    
end

function SoloSelect(solo_key) -- list:list \n solo_key:string or number
    for k, v in pairs(Snapshot) do
        Snapshot[k].Selected = false
    end
    Snapshot[solo_key].Selected = true
end

function rgba2num(red, green, blue, alpha)

	local blue = blue * 256
	local green = green * 256 * 256
	local red = red * 256 * 256 * 256
	
	return red + green + blue + alpha
end

function ResetStyleCount()
    reaper.ImGui_PopStyleColor(ctx,CounterStyle) -- Reset The Styles (NEED FOR IMGUI TO WORK)
    CounterStyle = 0
end

function ChangeColor(H,S,V,A)
    reaper.ImGui_PushID(ctx, 3)
    local button = reaper.ImGui_ColorConvertHSVtoRGB( H, S, V, A)
    local hover =  reaper.ImGui_ColorConvertHSVtoRGB( H, S , (V+0.4 < 1) and V+0.4 or 1 , A)
    local active = reaper.ImGui_ColorConvertHSVtoRGB( H, S, (V+0.2 < 1) and V+0.2 or 1 , A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),  button)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), hover)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  active)
end

function ChangeColorText(H,S,V,A)
    local textcolor = reaper.ImGui_ColorConvertHSVtoRGB( H, S, V, A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(),  textcolor)
end

function ToolTip(text)
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_BeginTooltip(ctx)
        reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 35.0)
        reaper.ImGui_PushTextWrapPos(ctx, 200)
        reaper.ImGui_Text(ctx, text)
        reaper.ImGui_PopTextWrapPos(ctx)
        reaper.ImGui_EndTooltip(ctx)
    end
end

function BeginForcePreventShortcuts() --Change and Store Configs.PreventShortcut
    TempPreventShortCut = Configs.PreventShortcut
    Configs.PreventShortcut = true
end

function CloseForcePreventShortcuts() -- Restore Configs.PreventShortcut configs
    Configs.PreventShortcut = TempPreventShortCut
    TempPreventShortCut = nil
end

function RenamePopup(i)
    if reaper.ImGui_BeginPopupModal(ctx, 'Rename###RenamePopup', nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
        if not TempFirstTime then reaper.ImGui_SetKeyboardFocusHere(ctx); TempFirstTime = true end
        
        _, Snapshot[i].Name = reaper.ImGui_InputText(ctx, "##Rename"..i, Snapshot[i].Name)
        
        if reaper.ImGui_Button(ctx, 'Close', -1) or reaper.ImGui_IsKeyDown(ctx, 13) then
            if Snapshot[i].Name == '' then Snapshot[i].Name = 'Snapshot '..i end -- If Name == '' Is difficult to see in the GUI
            if Snapshot[i].Name == 'Stevie' then PrintStevie() end -- =)
            SaveSnapshotConfig() 
            CloseForcePreventShortcuts()
            TempPopup_i = nil
            TempFirstTime = nil -- Need to set focus on Text input first time run this modal pop up 
            reaper.ImGui_CloseCurrentPopup(ctx) 
        end
        reaper.ImGui_EndPopup(ctx)
    end     
end

function OpenPopups(i) -- Need This function to be called outside a menu (else it wouldnt run the popup every loop)... i =  TempPopup_i. Need to TempPopup_i = nil when closing a popup. TempPopup_i = Snaphot[i] that called a popup rename/shortcut
    if i then
        if TempRenamePopup then
            BeginForcePreventShortcuts()
            reaper.ImGui_OpenPopup(ctx, 'Rename###RenamePopup')
            TempRenamePopup = nil
        end
        RenamePopup(i)

        if TempLearnPopup then
            BeginForcePreventShortcuts()
            reaper.ImGui_OpenPopup(ctx, 'Learn')
            TempLearnPopup = nil
        end
        LearnWindow(i)
    end
end

function SnapshotRightClickPopUp(i) 
    if reaper.ImGui_BeginPopupContextItem(ctx) then -- use last item id as popup id

        --Overwrite
        if reaper.ImGui_MenuItem(ctx, 'Overwrite') then
            OverwriteSnapshot(i)
        end

        --Load in new Tracks
        if reaper.ImGui_MenuItem(ctx, 'Load In New Tracks') then
            SetSnapshotInNewTracks(i)
        end

        --Delete
        if reaper.ImGui_MenuItem(ctx, 'Delete') then
            DeleteSnapshot(i)
            goto endpopup
        end

        --Rename

        if reaper.ImGui_MenuItem(ctx, 'Rename') then
            TempRenamePopup = true -- If true open Rename Popup at  OpenPopups(i) --> RenamePopup(i)
            TempPopup_i = i
        end

        if reaper.ImGui_MenuItem(ctx, 'Shortcut') then
            TempLearnPopup = true -- If true open Learn Popup at  OpenPopups(i) --> LearnWindow(i)
            TempPopup_i = i
        end

        reaper.ImGui_Separator(ctx)------------------------------------------------------------

        --Select Tracks
        if reaper.ImGui_MenuItem(ctx, 'Select Snapshot Tracks') then
            SelectSnapshotTracks(i)
        end

        for idx, track in pairs(Snapshot[i].Tracks) do
            if reaper.ValidatePtr2(0, track, 'MediaTrack*') then
                local retval, name = reaper.GetTrackName(track)
                ---------------------------------------------------------------------Tracks Submenu
                if reaper.ImGui_BeginMenu(ctx, 'Track: '..name..'###'..idx) then
                    if reaper.ImGui_MenuItem(ctx, 'Load Just This Track Snapshot') then
                        SetSnapshotForTrack(i,track,true)
                    end

                    if reaper.ImGui_MenuItem(ctx, 'Load Just This Track Snapshot In a New Track') then
                        SetSnapshotForTrackInNewTracks(i,track,true)
                    end

                    reaper.ImGui_Separator(ctx)

                    if reaper.ImGui_MenuItem(ctx, 'Remove Track From Snapshot') then
                        if (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_KeyModFlags_Shift()) == 0 then
                            RemoveTrackFromSnapshot(i, track)
                        elseif (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_KeyModFlags_Shift()) == 2 then
                            RemoveTrackFromSnapshotAll(track)
                        end
                    end
                    if Configs.ToolTips then ToolTip("Remove this track from this Snapshot.  Hold shift to apply to all snapshots that use track: "..name) end

                    
                    if reaper.ImGui_MenuItem(ctx, 'Substitute This Track With Track Selected') then -- Hold Shift For Substituing in all Snapshots 
                        if (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_KeyModFlags_Shift()) == 0 then
                            SubstituteTrack(i,track)
                        elseif (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_KeyModFlags_Shift()) == 2 then
                            SubstituteTrackAll(track)
                        end
                    end
                    if Configs.ToolTips then ToolTip("Use first selected track as the target when loading this snapshot. Hold shift to apply to all snapshots that use track: "..name) end


                    reaper.ImGui_EndMenu(ctx)
                end
                ----------------------------------------------------------------------
            elseif type(track) == "string" then
                local name = GetChunkVal(Snapshot[i].Chunk[track], 'NAME')
                if name == '""' then name = 'Unnamed Track '..idx end
                ChangeColorText(1,1,1,1) -- Red Text
                ---------------------------------------------------------------------Missed Tracks Submenu
                if reaper.ImGui_BeginMenu(ctx, 'Track: '..name..'###'..idx) then
                    reaper.ImGui_PopStyleColor(ctx) -- Pop Red Text
                    ChangeColorText(0,0,1,1) -- White Text

                    if reaper.ImGui_MenuItem(ctx, 'Substitute This Track With Track Selected') then -- Hold Shift For Substituing in all Snapshots 
                        if (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_KeyModFlags_Shift()) == 0 then
                            SubstituteTrack(i,track)
                        elseif (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_KeyModFlags_Shift()) == 2 then
                            SubstituteTrackAll(track)
                        end
                    end
                    if Configs.ToolTips then ToolTip("Use first selected track as the target when loading this snapshot. Hold shift to apply to all snapshots that use track: "..name) end


                    if reaper.ImGui_MenuItem(ctx, 'Create New Track For The Track Missing') then
                        if (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_KeyModFlags_Shift()) == 0 then
                            SubstituteTrackWithNew(i,track)
                        elseif (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_KeyModFlags_Shift()) == 2 then
                            SubstituteTrackWithNewAll(i,track)
                        end
                    end
                    if Configs.ToolTips then ToolTip("Create a new track and use it as the target when loading this Snapshot. Hold shift to apply to all snapshots that use track: "..name) end


                    if reaper.ImGui_MenuItem(ctx, 'Remove Track From Snapshot') then
                        if (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_KeyModFlags_Shift()) == 0 then
                            RemoveTrackFromSnapshot(i, track)
                        elseif (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_KeyModFlags_Shift()) == 2 then
                            RemoveTrackFromSnapshotAll(track)
                        end
                    end

                    reaper.ImGui_Separator(ctx)

                    if reaper.ImGui_MenuItem(ctx, 'Load Just This Track Snapshot In a New Track') then
                        SetSnapshotForTrackInNewTracks(i,track,true)
                    end
                    reaper.ImGui_EndMenu(ctx)
                end
                reaper.ImGui_PopStyleColor(ctx) -- Pop White Text
            end
        end

        ::endpopup::
        reaper.ImGui_EndPopup(ctx)
    end
end

function LearnWindow(i)
    if reaper.ImGui_BeginPopupModal(ctx, 'Learn', nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
        reaper.ImGui_Text(ctx, 'Key: '..(Snapshot[i].Shortcut or ''))
        

        for char, keycode in pairs(KeyCodeList()) do
            if reaper.ImGui_IsKeyReleased(ctx, keycode) then
                local check = true
                -- Check if Key is already used
                for check_i, value in pairs(Snapshot) do 
                    if  Snapshot[check_i].Shortcut == char then
                        check = false
                    end
                end
                
                if check then 
                    Snapshot[i].Shortcut = char
                    CloseForcePreventShortcuts()
                    TempPopup_i = nil
                    SaveSnapshotConfig()
                    reaper.ImGui_CloseCurrentPopup(ctx)
                else -- Key Clicked is in Use
                    print('Key Already Used In Snapshot')
                end
            end
        end

        if reaper.ImGui_Button(ctx, 'REMOVE', 120, 0) then 
            Snapshot[i].Shortcut = false
            CloseForcePreventShortcuts()
            TempPopup_i = nil
            SaveSnapshotConfig() 
            reaper.ImGui_CloseCurrentPopup(ctx) 
        end
        reaper.ImGui_EndPopup(ctx)
    end
end


function GuiLoadChunkOption()
    if reaper.ImGui_TreeNode(ctx, 'Load Snapshot Options') then
        if Configs.ToolTips then ToolTip("Filter Things To Be Loaded") end


        reaper.ImGui_PushFont(ctx, font_mini) -- Says you want to start using a specific font

        reaper.ImGui_PushItemWidth(ctx, 100)

        if reaper.ImGui_Checkbox(ctx, 'Load All', Configs.Chunk.All) then
            Configs.Chunk.All = not Configs.Chunk.All
            SaveConfig() 
        end

        if not Configs.Chunk.All then 
            reaper.ImGui_Separator(ctx)

            if reaper.ImGui_Checkbox(ctx, 'Items', Configs.Chunk.Items) then
                Configs.Chunk.Items = not Configs.Chunk.Items
                SaveConfig() 
            end
            if reaper.ImGui_Checkbox(ctx, 'FX', Configs.Chunk.Fx) then
                Configs.Chunk.Fx = not Configs.Chunk.Fx
                SaveConfig() 
            end
            if reaper.ImGui_Checkbox(ctx, 'Track Envelopes', Configs.Chunk.Env.Bool) then
                Configs.Chunk.Env.Bool = not Configs.Chunk.Env.Bool
                SaveConfig() 
            end
            if Configs.ToolTips then ToolTip("Right Click For More Options") end

            -- Right Click Track Envelopes
            if reaper.ImGui_BeginPopupContextItem(ctx) then
                for i, value in pairs(Configs.Chunk.Env.Envelope) do
                    if reaper.ImGui_Checkbox(ctx, Configs.Chunk.Env.Envelope[i].Name, Configs.Chunk.Env.Envelope[i].Bool) then
                        Configs.Chunk.Env.Envelope[i].Bool = not Configs.Chunk.Env.Envelope[i].Bool
                        SaveConfig()
                    end
                end

                reaper.ImGui_EndPopup(ctx)
            end

            reaper.ImGui_Spacing(ctx)

            for i, value in pairs(Configs.Chunk.Misc) do
                if reaper.ImGui_Checkbox(ctx, Configs.Chunk.Misc[i].Name, Configs.Chunk.Misc[i].Bool) then
                    Configs.Chunk.Misc[i].Bool = not Configs.Chunk.Misc[i].Bool
                    SaveConfig()
                end
            end
        end

        reaper.ImGui_PopItemWidth(ctx)

        reaper.ImGui_PopFont(ctx) -- Pop Font
        reaper.ImGui_TreePop(ctx)
    end
end

function PassThorugh() -- Actions to pass keys though GUI to REAPER. Find a better way
    if reaper.ImGui_IsKeyPressed(ctx, 32, false) then-- Space
        
        reaper.Main_OnCommand(40044, 0) -- Transport: Play/stop
    end

    local ctrl = (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_KeyModFlags_Ctrl()) == 1
    local shift = (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_KeyModFlags_Shift()) == 2

    if ctrl and shift then 
        if reaper.ImGui_IsKeyPressed(ctx, 90, false) then-- z
            reaper.Main_OnCommand(40030, 0) -- Edit: Redo
        end
    elseif ctrl then 
        if reaper.ImGui_IsKeyPressed(ctx, 90, false) then-- z
            reaper.Main_OnCommand(40029, 0) -- Edit: Undo
        end
    end
end

function ConfigsMenu()
    if reaper.ImGui_BeginMenu(ctx, 'Configs') then

        if reaper.ImGui_MenuItem(ctx, 'Only Show Selected Tracks Snapshots',"", not Configs.ShowAll) then
            Configs.ShowAll = not Configs.ShowAll
            SaveConfig()
        end

        if reaper.ImGui_MenuItem(ctx, 'Prevent Snapshot Shortcuts',"",  Configs.PreventShortcut) then
            Configs.PreventShortcut = not  Configs.PreventShortcut
            SaveConfig()
        end

        if reaper.ImGui_MenuItem(ctx, 'Prompt Snapshot Name When Saving',"",  Configs.PromptName) then
            Configs.PromptName = not  Configs.PromptName
            SaveConfig()
        end
        
        if reaper.ImGui_MenuItem(ctx, 'Delete Automation Items When Saving Snapshots',"", Configs.AutoDeleteAI) then
            Configs.AutoDeleteAI = not Configs.AutoDeleteAI
            SaveConfig()
        end
        
        if Configs.ToolTips then ToolTip('(DEFAULT AND RECOMMENDED)\nThis remove all automation items preserving the points before saving the snapshot\nThis create an Undo Point!') end


        reaper.ImGui_Separator(ctx)

        if reaper.ImGui_MenuItem(ctx, 'Show Tooltips',"",  Configs.ToolTips) then
            Configs.ToolTips = not  Configs.ToolTips
            SaveConfig()
        end

        reaper.ImGui_Separator(ctx)


        --Delete All
        if reaper.ImGui_MenuItem(ctx, 'Delete All Snapshots') then
            Snapshot = {}
            SaveSnapshotConfig()
        end

        reaper.ImGui_EndMenu(ctx)
    end
end

function AboutMenu()
    if reaper.ImGui_BeginMenu(ctx, 'About') then

        if reaper.ImGui_MenuItem(ctx, 'Donate!') then
            open_url('https://www.paypal.com/donate/?hosted_button_id=RWA58GZTYMZ3N')
        end

        if reaper.ImGui_MenuItem(ctx, 'Forum Thread') then
            open_url('https://forum.cockos.com/showthread.php?t=264124')
        end

        if reaper.ImGui_MenuItem(ctx, 'Video') then
            open_url('https://youtu.be/-y8TsehRYzo')
        end
        reaper.ImGui_EndMenu(ctx)

    end
end

function DockBtn()
    local reval_dock =  reaper.ImGui_IsWindowDocked(ctx)
    local dock_text =  reval_dock and  'Undock' or 'Dock'

    if reaper.ImGui_Button(ctx,dock_text ) then
        if reval_dock then -- Already Docked
            SetDock = 0
        else -- Not docked
            SetDock = -3 -- Dock to the right 
        end
    end
end

