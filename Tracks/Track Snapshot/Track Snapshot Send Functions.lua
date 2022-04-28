-- @noindex
function SaveSend(i)
    Snapshot[i].Sends = {}
    for index, track in pairs(Snapshot[i].Tracks) do
        Snapshot[i].Sends[track] = {}
        local cnt_sends = reaper.GetTrackNumSends( track, 0 ) -- category is <0 for receives, 0=sends, >0 for hardware outputs
        if cnt_sends < 1 then goto continue end -- continue
        local send_idx = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER') - 1
        send_idx = tostring(math.floor(send_idx))

        for send_i = 0, cnt_sends-1 do
            local dest_track = reaper.GetTrackSendInfo_Value( track, 0, send_i, 'P_DESTTRACK' )
            if not Snapshot[i].Sends[track][dest_track] then
                Snapshot[i].Sends[track][dest_track] = {} -- May have more than one send between two tracks so need to be a table
            else
                goto continue2
            end

            local retval, chunk = reaper.GetTrackStateChunk(dest_track, '', false)
            for k,send_chunk in pairs(GetSendChunk(chunk, send_idx)) do -- I need to insert all Send Envelope Together here
                table.insert(Snapshot[i].Sends[track][dest_track],send_chunk)
            end
            ::continue2::
        end
        ::continue::
    end
end

--- Set!
function RemakeSends(i, track, new_track)
    local track_change = new_track or track

    if not reaper.ValidatePtr2(0, track_change, 'MediaTrack*') then return end
    if not Snapshot[i].Sends then return end
    
    -- Remove all Sends 
    local cnt_sends = reaper.GetTrackNumSends( track_change, 0 ) -- category is <0 for receives, 0=sends, >0 for hardware outputs
    for send_i = cnt_sends-1, 0, -1 do
        reaper.RemoveTrackSend( track_change, 0, send_i )
    end

    if Snapshot[i].Sends[track] then
        local send_idx = reaper.GetMediaTrackInfo_Value(track_change, 'IP_TRACKNUMBER') - 1
        send_idx = tostring(math.floor(send_idx))
        for dest_track, t2 in pairs(Snapshot[i].Sends[track])do
            if not reaper.ValidatePtr2(0, dest_track, 'MediaTrack*') then goto continue end

            local retval, chunk = reaper.GetTrackStateChunk(dest_track, '', false)
            --Create Sends
            for k, send_chunk in pairs(Snapshot[i].Sends[track][dest_track])do
                local send_chunk = string.gsub(send_chunk, 'AUXRECV %d+', 'AUXRECV '..send_idx) -- Change track IDX
                chunk = AddSectionToChunk(chunk, send_chunk)
            end
            reaper.SetTrackStateChunk(dest_track, chunk, false)
            ::continue::
        end
    end
end

--- Receives
function SaveReceive(i)
    Snapshot[i].Receives = {}
    for index, track in pairs(Snapshot[i].Tracks) do
        Snapshot[i].Receives[track] = {}

        local retval, chunk = reaper.GetTrackStateChunk(track, '', false)
        for k, send_chunk in pairs(GetSendChunk(chunk, send_idx)) do
            local track_idx = string.match(send_chunk,'AUXRECV '.."(%d+)")
            local source_track = reaper.GetTrack(0, track_idx)
            if not Snapshot[i].Receives[track][source_track] then
                Snapshot[i].Receives[track][source_track] = {}
            end
            table.insert(Snapshot[i].Receives[track][source_track],send_chunk)
        end
    end
end
--- Set!
function RemakeReceive(i, track, new_track)
    if not reaper.ValidatePtr2(0, track, 'MediaTrack*') then return end
    if not Snapshot[i].Receives then return end
    
    local track_change = new_track or track

    -- Remove all Sends 
    local cnt_receives = reaper.GetTrackNumSends( track_change, -1 ) -- category is <0 for receives, 0=receives, >0 for hardware outputs
    for receive_i = cnt_receives-1, 0, -1 do
        reaper.RemoveTrackSend( track_change, -1, receive_i )
    end

    local retval, chunk = reaper.GetTrackStateChunk(track_change, '', false)

    if Snapshot[i].Receives[track] then
        for source_track, t2 in pairs(Snapshot[i].Receives[track])do
            if not reaper.ValidatePtr2(0, source_track, 'MediaTrack*') then goto continue end
            local send_idx = reaper.GetMediaTrackInfo_Value(source_track, 'IP_TRACKNUMBER') - 1
            send_idx = tostring(math.floor(send_idx))

            --Create Sends
            for k, send_chunk in pairs(Snapshot[i].Receives[track][source_track])do
                local send_chunk = string.gsub(send_chunk, 'AUXRECV %d+', 'AUXRECV '..send_idx) -- Change track IDX
                chunk = AddSectionToChunk(chunk, send_chunk)
            end
            ::continue::
        end
    end

    reaper.SetTrackStateChunk(track_change, chunk, false)
end

function SubstituteSendsReceives(track, new_track)
    if track == new_track then return end
    local miss_track_symbol = '#$$$#'
    for i, value in pairs(Snapshot) do
        --[[print(Snapshot[i].Name) -- Debug
        print('---------OLD---------')
        print('Snapshot[i].Sends')
        tprint(Snapshot[i].Sends)
        print('Snapshot[i].Receives')
        tprint(Snapshot[i].Receives) ]]
        for send_track, value in pairs(Snapshot[i].Sends) do
            for receive_track, chunk_table  in pairs (Snapshot[i].Sends[send_track]) do
                if receive_track == track or receive_track == miss_track_symbol..tostring(track) then
                    Snapshot[i].Sends[send_track][new_track] = Snapshot[i].Sends[send_track][receive_track]
                    Snapshot[i].Sends[send_track][receive_track] = nil
                end
            end
            if send_track == track or send_track == miss_track_symbol..tostring(track) then
                Snapshot[i].Sends[new_track] = Snapshot[i].Sends[send_track]
                Snapshot[i].Sends[send_track] = nil
            end
        end

        for receive_track, value in pairs(Snapshot[i].Receives) do
            for send_track, chunk_table  in pairs (Snapshot[i].Receives[receive_track]) do
                if send_track == track or send_track == miss_track_symbol..tostring(track) then
                    Snapshot[i].Receives[receive_track][new_track] = Snapshot[i].Receives[receive_track][send_track]
                    Snapshot[i].Receives[receive_track][send_track] = nil
                end
            end
            if receive_track == track or receive_track == miss_track_symbol..tostring(track) then
                Snapshot[i].Receives[new_track] = Snapshot[i].Receives[receive_track]
                Snapshot[i].Receives[receive_track] = nil
            end
        end

        --[[print('---------NEW---------')
        print('Snapshot[i].Sends')
        tprint(Snapshot[i].Sends)
        print('Snapshot[i].Receives')
        tprint(Snapshot[i].Receives) ]]
    end
end