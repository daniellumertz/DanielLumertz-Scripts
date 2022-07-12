-- @noindex
---Get tracknumber from reaper.GetLastTouchedFX() if the FX is in a Track will only return track_idx. If the FX is in a Item then return track_idx and item_idx.
---@param tracknumber any
---@return  integer track_idx the track id 0 based. -1 is master 
---@return  integer fx_idx the fx id on this chain 0 based.
---@return  integer item_idx the item id in this track 0 based. 
---@return  integer take_idx the take with this FX 0 based. 
---@return  integer is_recordFX is this FX at Record Input FX.
function GetLastFXTrackItem(tracknumber, fxnumber)
    local tracknumber_bit = ToBits(tracknumber,true)
    --get track binary number
    local track_id_byte = tracknumber_bit:sub(-16)
    local track_idx = tonumber(track_id_byte,2)-- from binary to decimal
    track_idx = track_idx  - 1 
    --get item binary number
    local item_id_byte = tracknumber_bit:sub(1,-17)
    local item_idx
    if item_id_byte and item_id_byte ~= '' then -- check if got something(if not isnt an item fx)
        item_idx = tonumber(item_id_byte,2)  -- from binary to decimal
        item_idx = item_idx - 1
    end

    --- Fx Number
    local fxnumber_bit = ToBits(fxnumber,true)
    -- take
    local take_idx
    
    if item_id_byte and item_id_byte ~= '' then  -- if is item get take
        -- get take idx
        local take_id_byte = fxnumber_bit:sub(1,-17)
        take_idx = tonumber(take_id_byte,2) or 0 -- from binary to decimal. First take dont have a big binary number so wont return nothing.
    end
    
    local is_recordFX = fxnumber_bit:len() == 25 -- 16 first bytes are for FX chain position. If is at Record Input FX then it adds an 10000000 at the start.

    -- get fx idx
    local fx_idx
    if is_recordFX then
        fx_idx = fxnumber
    else
        local fx_idx_byte = fxnumber_bit:sub(-16)
        fx_idx = tonumber(fx_idx_byte,2)-- from binary to decimal        
    end



    return track_idx, fx_idx, item_idx, take_idx, is_recordFX--- track_idx = 1 based (0 is master track); item_i = 1 based
end
