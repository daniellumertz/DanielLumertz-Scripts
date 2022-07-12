-- @version 0.1
-- @author Daniel Lumertz
-- @provides
--    [nomain] Functions/*.lua
-- @changelog
--    + Initial Release
local info = debug.getinfo(1,'S')
local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]] -- this script folder

dofile(script_path..'Functions/General Lua Functions.lua')
dofile(script_path..'Functions/FX Functions.lua')

local is_new_value,filename,sectionID,cmdID,mode,resolution,val = reaper.get_action_context() -- It might jump values if too fast. This because the frequency reaper looks for the shortcuts. Using Get Recent Input Events will return the same thing.  
local retval, tracknumber, fxnumber, paramnumber = reaper.GetLastTouchedFX()

if retval then
    local track_idx, fx_idx, item_idx, take_idx, is_recordFX = GetLastFXTrackItem(tracknumber, fxnumber)
    local track = reaper.GetTrack(0, track_idx)
    local track_or_take, setParamFunction -- track_or_take = track or take with last touched FX. setParamFunction function to set param (may be TakeFX_SetParam or TrackFX_SetParam)
    if item_idx then 
        local item = reaper.GetTrackMediaItem(track, item_idx)
        local take = reaper.GetTake(item, take_idx)
        track_or_take = take
        setParamFunction =  reaper.TakeFX_SetParamNormalized  --  reaper.TakeFX_SetParam( take, fx, param, val ) fx is integer
    else
        track_or_take = track
        setParamFunction =   reaper.TrackFX_SetParamNormalized --  reaper.TrackFX_SetParam(track, fx, param, val ) fx is integer
    end

    val = val/127
    setParamFunction(track_or_take,fx_idx,paramnumber,val)

end

reaper.defer(function () end)

