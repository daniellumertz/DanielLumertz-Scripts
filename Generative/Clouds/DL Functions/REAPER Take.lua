--@noindex
--version: 0.0

DL = DL or {}
DL.take = {}

---Write an ext state at an item
---@param take MediaItem_Take
---@param extname string name of the ext state section
---@param key string name of the key inside the extname section
---@param value string value to store 
---@return boolean
function DL.take.SetExtState(take, extname, key, value)
    local  retval, extstate = reaper.GetSetMediaItemTakeInfo_String( take, 'P_EXT:'..extname..': '..key, value, true )
    return retval
end

---Return the item ext state value
---@param take MediaItem_Take
---@param extname string name of the ext state section
---@param key string name of the key inside the extname section
---@return boolean retval
---@return string value
function DL.take.GetExtState(take, extname, key)
    local retval, extstate = reaper.GetSetMediaItemTakeInfo_String( take, 'P_EXT:'..extname..': '..key, '', false )
    return retval, extstate
end

---Return the index of a take in a item. 0 based
---@param item MediaItem
---@param take MediaItem_Take
---@return integer?
function DL.take.GetIndex(item, take)
    local idx = 0
    for loop_take in DL.enum.Takes(item) do
        if take == loop_take then
            return idx
        end
        idx = idx + 1
    end
end