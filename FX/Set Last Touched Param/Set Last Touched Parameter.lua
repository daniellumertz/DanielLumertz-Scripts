-- @version 0.2
-- @author Daniel Lumertz
-- @provides
--    [nomain] Functions/*.lua
-- @changelog
--    + Add Relative MIDI Support



--------- User Setting!

local sensivity = 0.5 -- Only for MIDI Relative input. Normally a number between 0 and 1. Values close to 0 will result in smoother/slower changes. Bigger/Smaller numbers will result in jumps/faster changes.  Negative values will flip the oriantation. Default is 0.5

-----------------------
local info = debug.getinfo(1,'S')
local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]] -- this script folder

dofile(script_path..'Functions/General Lua Functions.lua')
dofile(script_path..'Functions/FX Functions.lua')

local is_new_value,filename,sectionID,cmdID,mode,resolution,val = reaper.get_action_context() -- It might jump values if too fast. This because the frequency reaper looks for the shortcuts. Using Get Recent Input Events will return the same thing.  

local retval, tracknumber, fxnumber, paramnumber = reaper.GetLastTouchedFX()

if retval then
    local track_idx, fx_idx, item_idx, take_idx, is_recordFX = GetLastFXTrackItem(tracknumber, fxnumber)
    local track = reaper.GetTrack(0, track_idx)
    local track_or_take, setParamFunction, getParamFunction -- track_or_take = track or take with last touched FX. setParamFunction function to set param (may be TakeFX_SetParam or TrackFX_SetParam)
    if item_idx then 
        local item = reaper.GetTrackMediaItem(track, item_idx)
        local take = reaper.GetTake(item, take_idx)
        track_or_take = take
        setParamFunction =  reaper.TakeFX_SetParamNormalized  --  reaper.TakeFX_SetParam( take, fx, param, val ) fx is integer
        getParamFunction = reaper.TakeFX_GetParamNormalized   --  reaper.TakeFX_GetParamNormalized(take, fx, param)
    else
        track_or_take = track
        setParamFunction =   reaper.TrackFX_SetParamNormalized --  reaper.TrackFX_SetParam(track, fx, param, val ) fx is integer
        getParamFunction = reaper.TrackFX_GetParamNormalized   --  reaper.TrackFX_GetParamNormalized(track, fx, param)

    end


    if mode == 0 then
        val = val/127 -- make val from 0 to 1
        setParamFunction(track_or_take,fx_idx,paramnumber,val)
    else
        local actual_value = getParamFunction(track_or_take, fx_idx, paramnumber)
        -- Map input to -1 to +1
        if mode == 1 then
            val = MapRange(val,-64,63,-1,1) -- dont have 0, goes to -64
        elseif mode == 2 then
            val = MapRange(val,-63,63,-1,1) -- have 0 at midi input 64
        elseif mode == 3 then
            val = MapRange(val,-63,63,-1,1) -- have 0 at midi input 64
        end
        val = sensivity * val
        local new_val = val + actual_value
        new_val = LimitNumber(new_val,0,1)
        setParamFunction(track_or_take,fx_idx,paramnumber,new_val)
    end

end

reaper.defer(function () end)

