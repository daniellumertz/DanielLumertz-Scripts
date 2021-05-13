-- @version 1.2
-- @author Daniel Lumertz
-- @changelog
--    + Only 3 points if need
--    + return if no time selection


-- User Configs
local dB_change = -0.5 
local points_shape = 0
local undo_points = true

function print(...)
    for k,v in ipairs({...}) do
        reaper.ShowConsoleMsg(tostring(v))
    end
    reaper.ShowConsoleMsg("\n")
end

--[[ function DeleteEvelopePointAtPositions(envelope, ...) -- Envelope and time positions of the points
    local countPts = reaper.CountEnvelopePoints(envelope)
    for i = countPts-1, 0, -1  do
        local retval, time, value, shape, tension, selected = reaper.GetEnvelopePoint(envelope, i)
        for k,v in ipairs({...}) do
            if time == v then  
                reaper.DeleteEnvelopePointEx( envelope, -1, i ) 
            end
        end
    end
end 
-- Maybe I use someday will leave here
]]

function SetEvelopePointInRange(envelope,offset,start,fim) -- Envelope and time positions of the points
    local countPts = reaper.CountEnvelopePoints(envelope)
    for i = 0, countPts-1  do
        local retval, time, value, shape, tension, selected = reaper.GetEnvelopePoint(envelope, i)
        if time > start and time < fim then
            local newval = AddDBinLinear(value, offset )
            reaper.SetEnvelopePoint(envelope, i, nil, newval, nil, nil, nil, true)
        end
    end
end 

function AddDBinLinear(valbefore, addval )
    local val_before_in_DB = 20 * math.log(valbefore,10) -- Linear to dB
    local dB_newval = val_before_in_DB + addval -- add to dB
    local new_linear = 10^(dB_newval/20) -- dB to Linear
    return new_linear
end

--If User put with mouse wheel it invert the db_change value
local _,_,_,_,_,_,val = reaper.get_action_context()
if val >= 0 then
    dB_change = dB_change * -1
end

-- Get Env info
local window, segment, details = reaper.BR_GetMouseCursorContext()
local envelope, _ = reaper.BR_GetMouseCursorContext_Envelope()
if not envelope then return end
--local _, envname = reaper.GetEnvelopeName( envelope )
--local isvol = string.match(envname, "Volume")

-- Get Time pos
local time1, time4 = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
local time2 = reaper.BR_GetNextGridDivision( time1 ) -- You can set another time offset here I am using grid
local time3 = reaper.BR_GetPrevGridDivision( time4 ) -- You can set another time offset here I am using grid
if time1 == time4 then return end -- if no TS

if undo_points then reaper.Undo_BeginBlock() end
reaper.PreventUIRefresh(1)

-- Get Value info where will add points
local retval, value_before1, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate( envelope, time1, reaper.format_timestr_pos( 1, '', 4 ), 1 )
local retval, value_before2, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate( envelope, time2, reaper.format_timestr_pos( 1, '', 4 ), 1 )
local retval, value_before3, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate( envelope, time3, reaper.format_timestr_pos( 1, '', 4 ), 1 )
local retval, value_before4, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate( envelope, time4, reaper.format_timestr_pos( 1, '', 4 ), 1 )

-- Add Value
--if isvol then
local new_value2 = AddDBinLinear(value_before2, dB_change)
local new_value3 = AddDBinLinear(value_before3, dB_change)
--[[ local scaling_mode = reaper.GetEnvelopeScalingMode( envelope )
local value_before2_linear = reaper.ScaleFromEnvelopeMode( 1, value_before2 )
print(value_before2) ]]

-- To delete points at same time position
reaper.DeleteEnvelopePointRange( envelope, time1-(10^-10), time1+(10^-10))
reaper.DeleteEnvelopePointRange( envelope, time2-(10^-10), time2+(10^-10))
reaper.DeleteEnvelopePointRange( envelope, time3-(10^-10), time3+(10^-10))
reaper.DeleteEnvelopePointRange( envelope, time4-(10^-10), time4+(10^-10))

-- Change Points on range
SetEvelopePointInRange(envelope,dB_change,time1,time4)

-- Insert New Points
reaper.InsertEnvelopePoint( envelope, time1, value_before1, points_shape, 0, false, true )
reaper.InsertEnvelopePoint( envelope, time2, new_value2, points_shape, 0, false, true )
if time2 ~= time3 then 
    reaper.InsertEnvelopePoint( envelope, time3, new_value3, points_shape, 0, false, true )
end
reaper.InsertEnvelopePoint( envelope, time4, value_before4, points_shape, 0, false, true )

reaper.Envelope_SortPoints( envelope )
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()

if undo_points then 
    reaper.Undo_EndBlock("Create 4 Points Inside Time Selection Using Grid Values", -1) 
else 
    reaper.defer(function() end )
end