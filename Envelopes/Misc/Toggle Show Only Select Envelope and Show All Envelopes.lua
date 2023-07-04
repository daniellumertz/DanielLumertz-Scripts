-- @version 1.0
-- @author Daniel Lumertz
-- @changelog
--    + Initial Release

function env_show_more_1() -- Is there more than 1 envelopes being displayed ? return boolean
    local display_env_count = 0
    for i = 0 , (reaper.CountTracks(0)-1) do
        local track = reaper.GetTrack(0, i)
        for i = 0, (reaper.CountTrackEnvelopes(track)-1) do
            local envelope = reaper.GetTrackEnvelope( track, i )
            local retval, chunk = reaper.GetEnvelopeStateChunk(envelope, '', false)
            local is_show = tonumber(string.match(chunk,"VIS (%d) %d %d"))
            if is_show == 1 then -- Count as being displayed
                display_env_count = display_env_count + 1
            end
            --break env and track loop if MORE than 1 
            if display_env_count > 1 then return true end
        end
    end
    return false
end


if env_show_more_1() and reaper.GetSelectedEnvelope(0) then -- Is there more than one envelope being displayed AND is there a selected envelope?
    reaper.Main_OnCommand( reaper.NamedCommandLookup( "_BR_ENV_HIDE_ALL_BUT_ACTIVE_NO_TR_L" ), 0) -- SWS/BR: Hide all but selected track envelope for all tracks (except envelopes in track lanes)
else
    reaper.Main_OnCommand(41149, 0) -- Envelope: Show all envelopes for all tracks
end