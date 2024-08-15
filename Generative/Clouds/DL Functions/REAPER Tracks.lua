--@noindex
--version: 0.0

DL = DL or {}
DL.track = {}

---Select A list of tracks or one item. Validate them first
---@param tracklist MediaTrack[]|MediaTrack List of tracks to select. {track1, track2, track3} as userdata. Or just a track
---@param unselect boolean optional, unselect before selecting? 
function DL.track.SelectTracks(tracklist, unselect, proj)
    if unselect == nil then unselect = true end -- make it optional
    proj = proj or 0
    if unselect then -- Deselect all (I suppose this is the fastest. I bench with looping all selected tracks and unselect them and this is a little bit faster )
        local master = reaper.GetMasterTrack(proj)
        reaper.SetOnlyTrackSelected(master)
        reaper.SetTrackSelected(master, false)
    end
    if type(tracklist) == 'userdata' then tracklist = {tracklist} end
    for i, track in ipairs(tracklist) do
        if reaper.ValidatePtr2(proj, track, 'MediaTrack*') then
            reaper.SetTrackSelected(track, true)
        end
    end
end

---Create a table with the selected Tracks
---@param proj 0|nil|ReaProject proj or nil(sane as 0)
---@param wantmaster boolean want master track?
---@return MediaTrack[] -- with tracks
function DL.track.CreateSelectedTracksTable(proj, wantmaster)
    local t = {} 
    for track in DL.enum.SelectedTracks2(proj, wantmaster) do
        t[#t+1] = track
    end
    return t
end

----- Get

---Get the first MediaTrack with `name` if it exists. Return false if it dont find.
---@param proj 0|ReaProject|nil Project number or project.
---@param name string Track name to find.
---@return MediaTrack|boolean
function DL.track.GetTrackByName(proj,name)
    local track_cnt = reaper.CountTracks(proj)
    for i = 0, track_cnt-1 do
        local loop_track = reaper.GetTrack(proj, i)
        local bol, loop_name = reaper.GetTrackName(loop_track)
        if loop_name == name then
            return loop_track
        end
    end
    return false
end
