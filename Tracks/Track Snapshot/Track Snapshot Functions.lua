-- @noindex
function SaveSnapshot() -- Set Snapshot table, Save State
    local sel_tracks = SaveSelectedTracks()
    if #sel_tracks == 0 then
        print('👨< Please Select Some Tracks ❤️)') 
        return 
    end
    local i = #Snapshot+1
    Snapshot[i] = {}
    Snapshot[i].Tracks = sel_tracks
    

    -- Set Chunk in Snapshot[i][track]
    Snapshot[i].Chunk = {} 
    for k , track in pairs(Snapshot[i].Tracks) do
        AutomationItemsPreferences(track) 
        local retval, chunk = reaper.GetTrackStateChunk( track, '', false )
        if retval then
            Snapshot[i].Chunk[track] = chunk
        end
    end

    VersionModeOverwrite(i) -- If Version mode on it will save last selected snapshot before saving this one
    --Snapshot[i].Shortcut = nil
    Snapshot[i].MissTrack = false
    Snapshot[i].Visible = true 
    SoloSelect(i) --set Snapshot[i].Selected
    Snapshot[i].Name = 'New Snapshot '..i
    SaveSend(i) -- set Snapshot[i].Sends[SnapshotSendTrackGUID] = {RTrack = ReceiveGUID, Chunk = ‘ChunkLine’},...} -- table each item is a track it sends 
    SaveReceive(i)

    if Configs.PromptName then
        TempRenamePopup = true -- If true open Rename Popup at  OpenPopups(i) --> RenamePopup(i)
        TempPopup_i = i
    end
    
    SaveSnapshotConfig()
end

function OverwriteSnapshot(i) -- Only Called via user UI
    VersionModeOverwrite(i) -- Should I VersionModeOverwrite(i) when overwriting? ->yes) duplicate current snapshot no) current progress is saved only in the the overwrited snap 
    for k,track in pairs(Snapshot[i].Tracks) do 
        if reaper.ValidatePtr2(0, track, 'MediaTrack*') then -- Edit if I add a check 
            AutomationItemsPreferences(track)
            local retval, chunk = reaper.GetTrackStateChunk( track, '', false )

            if retval then
                Snapshot[i].Chunk[track] = chunk
            end
        end
    end
    SaveSend(i)
    SaveReceive(i)

    SoloSelect(i)
    SaveSnapshotConfig()  
end

function VersionModeOverwrite(i) -- i to check which tracks group is using
    -- Track Versions mode
    -- Get last selected Snapshot for this group of tracks
    -- If there is then 
    -- OverwriteSnapshotVersionMode(last selected Snapshot i) that with current configs
    if Configs.VersionMode then
        local last_i = GetLastSelectedSnapshotForGroupOfTracks(Snapshot[i].Tracks)
        if i ~= last_i then
            if last_i then
                for k,track in pairs(Snapshot[last_i].Tracks) do 
                    if reaper.ValidatePtr2(0, track, 'MediaTrack*') then -- Edit if I add a check 
                        AutomationItemsPreferences(track)
                        local retval, chunk = reaper.GetTrackStateChunk( track, '', false )
            
                        if not Configs.Chunk.All then -- Change what will be saved on the chunk
                            chunk = ChunkSwap(chunk , Snapshot[last_i].Chunk[track])
                        end
            
                        if retval then
                            Snapshot[last_i].Chunk[track] = chunk
                        end
                    end
                end 
                SaveSend(last_i)
                SaveReceive(last_i)
            end
        end
    end
end

function AutomationItemsPreferences(track) -- depreciated!!! not used in the code
    if Configs.AutoDeleteAI then -- remove AI. Not very resourcefull
        RemoveAutomationItems(track)
    --[[ elseif Configs.StoreAI then --This tries to store AI in hidden tracks, I think I won't support this (to turn on uncomment this three lines and at LoadConfigs())
        CheckHiddenTrack()
        StoreAIinHiddenTrack(track)  ]]
    end 
end

function CheckHiddenTrack() -- Check if there is Hidden Track to save AI  depreciated!!! 
    if not Configs.HiddenTrack or not reaper.ValidatePtr2(0, Configs.HiddenTrack, 'MediaTrack*') then 
        local hidden_track = CreateHiddenTrack('Snapshot_Hidden Store AI')
        CreateEnvelopeInTrack(hidden_track,'WIDTHENV2') -- Could be any envelope
        -- Store it
        Configs.HiddenTrack = hidden_track
    end    
end

function SetSnapshot(i)
    -- Undo and refresh
    BeginUndo()

    VersionModeOverwrite(i)
    -- Check if the all tracks exist if no ask if the user want to assign a new track to it Show Last Name.  Currently it wont load missed tracks and load the rest
    for k,track in pairs(Snapshot[i].Tracks) do 
        -- Add loading bar (?) Could be cool 
        if reaper.ValidatePtr2(0, track, 'MediaTrack*') then -- Edit if I add a check
            local chunk = Snapshot[i].Chunk[track]
            if not Configs.Chunk.All then
                chunk = ChunkSwap(chunk, track)
            end 
            reaper.SetTrackStateChunk(track, chunk, false)
        end
        if Configs.Chunk.All or Configs.Chunk.Receive then
            RemakeReceive(i, track)
        end
        if Configs.Chunk.All or Configs.Chunk.Sends then
            RemakeSends(i,track)
        end
    end
    SoloSelect(i)
    
    --SaveSnapshotConfig() -- Need because of SoloSelect OR Just Save when Script closes
    EndUndo('Snapshot: Set Snapshot: '..Snapshot[i].Name)
end

function GetLastSelectedSnapshotForGroupOfTracks(group_list) -- return i or false
    for i, v in pairs(Snapshot) do
        if TableValuesCompareNoOrder(Snapshot[i].Tracks,group_list) then
            if Snapshot[i].Selected then
                return i
            end
        end
    end
    return false
end

function SetSnapshotForTrack(i,track, undo)
    -- Check if the all tracks exist if no ask if the user want to assign a new track to it Show Last Name.  Currently it wont load missed tracks and load the rest
    if reaper.ValidatePtr2(0, track, 'MediaTrack*') then -- Edit if I add a check 
        if undo then 
            BeginUndo()
        end

        local chunk = Snapshot[i].Chunk[track]
        if not Configs.Chunk.All then
            chunk = ChunkSwap(chunk, track)
        end 
        reaper.SetTrackStateChunk(track, chunk, false)

        if Configs.Chunk.All or Configs.Chunk.Receive then
            RemakeReceive(i, track)
        end
        if Configs.Chunk.All or Configs.Chunk.Sends then
            RemakeSends(i,track)
        end

        if undo then 
            EndUndo('Snapshot: Set Track Snapshot: '..Snapshot[i].Name)
        end
    end
end

function CreateTrackWithChunk(i,chunk,idx, new_guid)
    reaper.InsertTrackAtIndex( idx, false ) -- wantDefaults=TRUE for default envelopes/FX,otherwise no enabled fx/env
    local new_track = reaper.GetTrack(0, idx)
    if new_guid then
        local start = reaper.time_precise()
        chunk = ResetAllIndentifiers(chunk)
    end

    if not Configs.Chunk.All then -- To make this function general just remove this if section 
        chunk = ChunkSwap(chunk, new_track)
    end 

    reaper.SetTrackStateChunk(new_track, chunk, false)
    return new_track
end

function ChunkSwap(chunk, track) -- Use Configs To change current track_chunk with section from chunk(arg1)
    local retval, track_chunk
    if type(track) == 'string' then
        track_chunk = track
    else 
        retval, track_chunk = reaper.GetTrackStateChunk(track, '', false)
    end

    if Configs.Chunk.Items then
        track_chunk = SwapChunkSection('ITEM',chunk,track_chunk) -- chunk -> track_chunk
    end

    if Configs.Chunk.Fx then
        track_chunk = SwapChunkSection('FXCHAIN',chunk,track_chunk) -- chunk -> track_chunk
    end

    if Configs.Chunk.Env.Bool then
        for i , val in pairs(Configs.Chunk.Env.Envelope) do --Parse every track envelope 
            if Configs.Chunk.Env.Envelope[i].Bool then
                track_chunk = SwapChunkSection(Configs.Chunk.Env.Envelope[i].ChunkKey,chunk,track_chunk) -- chunk -> track_chunk
            end
        end
    end

    for i, value in pairs(Configs.Chunk.Misc) do
        if Configs.Chunk.Misc[i].Bool then
            track_chunk = SwapChunkValue(Configs.Chunk.Misc[i].ChunkKey, chunk, track_chunk)
        end
    end

    return track_chunk
end

function SetSnapshotInNewTracks(i)
    BeginUndo()
    for track , chunk in pairs(Snapshot[i].Chunk) do 
        SetSnapshotForTrackInNewTracks(i, track, false)
    end
    EndUndo('Snapshot: Set Snapshot: '..Snapshot[i].Name..' in New Tracks')
end

function SetSnapshotForTrackInNewTracks(i, track, undo)
    -- if is master continue
    if IsMasterTrack(track) then
        goto continue
    end
    --
    if undo then 
        BeginUndo()
    end
    
    local chunk = Snapshot[i].Chunk[track]
    local new_track_index
    if type(track) == 'userdata' then   -------TIDO
        new_track_index = reaper.GetMediaTrackInfo_Value( track, 'IP_TRACKNUMBER' ) -- This is 1 Based (In the end dont need to add +1 )
    elseif type(track) == 'string' then
        new_track_index =  reaper.CountTracks(0) -- This is 1 Based (In the end dont need to add +1 )
    end

    local new_track = CreateTrackWithChunk(i, chunk, new_track_index, true) -- This is 0 Based
        if Configs.Chunk.All or Configs.Chunk.Receive then
            RemakeReceive(i, track, new_track)
        end
        if Configs.Chunk.All or Configs.Chunk.Sends then
            RemakeSends(i, track, new_track)
        end
    
    if undo then 
        EndUndo('Snapshot: Set Track Snapshot: '..Snapshot[i].Name)
    end
    ::continue::
end

function UpdateSnapshotVisible()
    local sel_tracks = SaveSelectedTracks()
    
    for i, value in pairs(Snapshot) do
        Snapshot[i].Visible = TableValuesCompareNoOrder(sel_tracks, Snapshot[i].Tracks) -- Here makes sense to have this group so is faster instead of GetKeys(Snapshot[i].Chunk)
    end
end

function CheckTracksMissing()-- Checks if all tracks in Snapshot Exist (To Catch Tracks deleted with Snapshot open)
    for i, v in pairs(Snapshot) do
        for key, track in pairs(Snapshot[i].Tracks) do
            if type(track) == 'userdata' then 
                if not reaper.ValidatePtr2(0, track, 'MediaTrack*') then
                    Snapshot[i].Tracks[key] = '#$$$#'..tostring(track)
                    Snapshot[i].Chunk['#$$$#'..tostring(track)] = Snapshot[i].Chunk[track] -- Save Chunk
                    Snapshot[i].Chunk[track] = nil
                    Snapshot[i].MissTrack  = true
                end
            end
        end

        if Snapshot[i].MissTrack == true then
            TryToFindMissTracks(i)
            Snapshot[i].MissTrack = not CheckTrackList(Snapshot[i].Tracks) -- Check If MissTrack can be == false
        end
    end
end

function TryToFindMissTracks(i)
    for key, track in pairs(Snapshot[i].Tracks) do

       if type(track) == 'string' then -- Check if this track is missing
            local chunk = Snapshot[i].Chunk[track]
            local guid = GetChunkVal(chunk,'TRACKID')
            local guid_track = GetTrackByGUID(guid)

            if guid_track then
                Snapshot[i].Tracks[key] = guid_track
                Snapshot[i].Chunk[guid_track] = chunk
                Snapshot[i].Chunk[track] = nil
            end
       end         
    end    
end

function SubstituteTrack(i,track, new_track, undo)
    local new_track = new_track or reaper.GetSelectedTrack(0, 0)
    if not new_track then print('👨< Please Select Some Tracks ❤️)') return end 
    -- Check if Already in Snapshot and  Check if track is in the list of tracks
    local bol = false
    for k ,v in pairs(Snapshot[i].Tracks) do
        if new_track== v then 
            --print('Track Already In The Snapshot '..Snapshot[i].Name) -- Catch if track already in this snapshot, still working I just removed the print I used to debug
            return
        end
        if v == track then -- Track is in this snapshot
            bol = true
        end
    end
    if not bol then return end -- Catch Snapshots without this track (this function might be using to iterate every snapshot)

    if undo then 
        BeginUndo()
    end
    -- Change Chunks for the old track (if track still exists it must have another GUID else in next run it can be selected)
    if type(track) == 'userdata' then
        if reaper.ValidatePtr2(0, track, 'MediaTrack*') then
            ResetTrackIndentifiers(track)
        end
    end

    for k ,v in pairs(Snapshot[i].Tracks) do
        if v == track then
            Snapshot[i].Chunk[new_track] = Snapshot[i].Chunk[track]
            Snapshot[i].Chunk[track] = nil
            Snapshot[i].Tracks[k] = new_track
        end
    end
    SetSnapshotForTrack(i,new_track,false)

    if undo then -- will be true when is executed only once via user 
        SaveSnapshotConfig() 
        EndUndo('Snapshot: Substitute Track'..Snapshot[i].Name)
    end
end

function SubstituteTrackAll(track)
    local new_track = new_track or reaper.GetSelectedTrack(0, 0)
    if not new_track then print('👨< Please Select Some Tracks ❤️)') return end 
    BeginUndo() 
    for i, value in pairs(Snapshot) do
        SubstituteTrack(i,track, new_track,false)
    end
    SubstituteSendsReceives(track, new_track)
    SaveSnapshotConfig()
    EndUndo('Snapshot: Substitute Track in All Snapshot')
end

function SubstituteTrackWithNew(i, track)
    BeginUndo()
    local cnt = reaper.CountTracks(0)
    reaper.InsertTrackAtIndex(cnt, false)
    local new_track = reaper.GetTrack(0, cnt)
    SubstituteTrack(i,track,new_track,false)
    SubstituteSendsReceives(track, new_track)
    SaveSnapshotConfig()
    EndUndo('Snapshot: Substitute Track With a New in Snapshot '..Snapshot[i].Name)
end

function SubstituteTrackWithNewAll(i, track)
    BeginUndo()
    local cnt = reaper.CountTracks(0)
    reaper.InsertTrackAtIndex(cnt, false)
    local new_track = reaper.GetTrack(0, cnt)
    
    for i, value in pairs(Snapshot) do
        SubstituteTrack(i,track,new_track,false)
    end 
    SaveSnapshotConfig()
    EndUndo('Snapshot: Substitute Track With a New in All Snapshot')
end

function DeleteSnapshot(i)
    Snapshot[i] = nil
    SaveSnapshotConfig()
end

function RemoveTrackFromSnapshot(i, track)
    for k , v in pairs(Snapshot[i].Tracks) do
        if v == track then
            Snapshot[i].Tracks[k] = nil
        end
        Snapshot[i].Chunk[track] = nil
    end
    SaveSnapshotConfig()
end

function RemoveTrackFromSnapshotAll(track)
    for i , v in pairs(Snapshot) do
        RemoveTrackFromSnapshot(i, track)  
    end
    SaveSnapshotConfig()
end

function SelectSnapshotTracks(i)
    BeginUndo()
    LoadSelectedTracks(Snapshot[i].Tracks)
    EndUndo('Snapshot: Select Tracks Snapshot: '..Snapshot[i].Name)
end

function CheckProjChange() 
    local current_proj = reaper.EnumProjects(-1)
    local current_path = GetFullProjectPath()
    if OldProj or OldPath  then  -- Not First run
        if OldProj ~= current_proj or OldPath ~= current_path then -- Changed the path (can be caused by a new save or dif project but it doesnt matter as it will just reload Snapshot and Configs)
            Snapshot = LoadSnapshot()
            Configs = LoadConfigs()
        end
    end 
    OldPath = current_path
    OldProj = current_proj        
end

function LoadSnapshot()
    local Snapshot = LoadExtStateTable(ScriptName, 'SnapshotTable', true)

    if Snapshot == false then
        Snapshot = {} 
    end

    for i, value in pairs(Snapshot) do-- For catching Snapshots that lost Tracks while script want running
        for key, track in pairs(Snapshot[i].Tracks) do
            if  type(track) == 'string' and Snapshot[i].MissTrack == false then 
                Snapshot[i].MissTrack  = true
            end 
        end
    end

    return Snapshot
end

function LoadConfigs()
    local Configs = LoadExtStateTable(ScriptName, 'ConfigTable', true)

    if Configs == false then
        Configs = {}
        Configs.ShowAll = false -- Show All Snapshots Not only the selected tracks (Name on GUI is the opposite (Show selected tracks only))
        Configs.PreventShortcut = false -- Prevent Shortcuts
        Configs.ToolTips = false -- Show ToolTips
        Configs.PromptName = true
        Configs.AutoDeleteAI = true -- Automatically Delete Automation Items (have preference over StoreAI)
        Configs.Select = false -- Show Last Snapshot Loaded per group of tracks
        Configs.VersionMode = false -- Show Last Snapshot Loaded per group of tracks
        --Configs.StoreAI = false -- Saves AI in a Hidden Track (descontinued for now) (To enable uncomment this line and at SaveSnapshot Function)

        ----Load Chunk options
        Configs.Chunk = {}
        Configs.Chunk.All = true
        Configs.Chunk.Fx = false
        Configs.Chunk.Items = false

        Configs.Chunk.Env = {} -- User Could select which envelopes to load,  for that make this : 1) table like Configs.Chunk.Misc. 2) Change Gui to appear all options 3) Change ChunkSwap so it checks for every option. Done, could be cool but I guess I will not use it :P
        Configs.Chunk.Env.Bool = false
        Configs.Chunk.Env.Envelope = {}

        local env = {-- Add here things to be on the Misc List [Chunk def = Button name]
            {'Volume (pre FX)', 'VOLENV'},
            {'Volume', 'VOLENV2'},
            {'Trim Volume', 'VOLENV3'},
            {'Pan (Pre-FX)', 'PANENV'},
            {'Pan', 'PANENV2'},
            {'Mute', 'MUTEENV'},
            {'Width (Pre-FX)', 'WIDTHENV'},
            {'Width', 'WIDTHENV2'},
            {'Receive Volume', 'AUXVOLENV'},
            {'Receive Pan', 'AUXPANENV'},
            {'Receive Mute', 'AUXMUTEENV'}

        } 
        for i , table in pairs(env) do
            Configs.Chunk.Env.Envelope[i] = {}
            Configs.Chunk.Env.Envelope[i].Bool = true
            Configs.Chunk.Env.Envelope[i].Name = table[1] 
            Configs.Chunk.Env.Envelope[i].ChunkKey = table[2]  
        end

        Configs.Chunk.Sends = false
        Configs.Chunk.Receive = false


        Configs.Chunk.Misc = {}

        local misc = { -- Add here things to be on the Misc List [Chunk def = Button name]
            {'VOLPAN',  'Volume & Pan'},
            {'REC',  'Rec & Monitor Modes'},
            {'MUTESOLO', 'Mute & Solo'},
            {'IPHASE', 'Phase'},
            {'NAME', 'Name'},
            {'PEAKCOL', 'Color'},
            {'AUTOMODE', 'Automation Mode'}
        }

        for i , table in pairs(misc) do
            Configs.Chunk.Misc[i] = {}
            Configs.Chunk.Misc[i].Bool = false
            Configs.Chunk.Misc[i].Name = table[2] 
            Configs.Chunk.Misc[i].ChunkKey = table[1]  
        end


    end

    return Configs
end

function SaveSnapshotConfig()
    SaveExtStateTable(ScriptName, 'SnapshotTable',table_copy_regressive(Snapshot), true)
    SaveConfig() 
end

function SaveConfig()
    SaveExtStateTable(ScriptName, 'ConfigTable',table_copy(Configs), false) 
end
