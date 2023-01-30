--@noindex
---Alternate the takes, mute the items
---@param groups table Content the group tables
---@param trigger any 'loop' if a loop caused the trigger. 'stop' if a stop caused the trigger. true will force the group to trigger
function AlternateItems(groups, trigger)
    for group_idx, group in ipairs(groups) do
        if #group == 0 then goto continue end -- continue if the group dont have any take 
        if (trigger == 'stop' and not group.doatstop) or (trigger == 'loop' and not group.doatloop) then goto continue end -- continue if this group isnt affected by this trigger 

        -- Add chances if add == 0  then no take will play
        local add = 0
        for k, v in ipairs(group) do
            add = add + v.chance
        end

        local sel_idx -- Takes are 1 based
        -- Select a take using random,shuffle, playlist
        if add > 0 and group.mode == 0 then -- Random
            -- get random

            local random_val = math.random(add) - 1 -- make it start at 0
            -- get idx on the table
            local chance_add = 0
            for k, v in ipairs(group) do
                chance_add = chance_add + v.chance
                if random_val < chance_add then 
                    sel_idx = k
                    break
                end
            end
        elseif add > 0 and group.mode == 1 then -- Shuffle
            local _
            -- shuffle add
            local shuffle_add = 0
            for k, take_table in ipairs(group.used_idx) do
                shuffle_add = shuffle_add + take_table.chance
            end
            -- check if need to reset the takes
            if  #group.used_idx == 0 or shuffle_add == 0 then group.used_idx = TableiCopy(group) end -- used all takes, reset it
            -- make a list of possible takes to get random
            local possible_takes = {} --list contaning all takes with positive chances, have to create the table here, in case user change the chance in middle of a sequence
            for k, take_table in ipairs(group.used_idx) do
                if take_table.chance > 0 then
                    possible_takes[#possible_takes+1] = take_table
                end
            end
            -- Get random 
            local possible_idx  = math.random(#possible_takes)
            -- get the idx from the group table
            _, sel_idx = TableHaveValue(group, possible_takes[possible_idx]) 
            local _, used_idx = TableHaveValue(group.used_idx, possible_takes[possible_idx]) 
            -- remove from the list
            table.remove(group.used_idx, used_idx)
        elseif add > 0 and group.mode == 2 then -- Playlist
            sel_idx = group.selected
            for i = 1, #group do -- Loop until find next with some chance
                sel_idx = ((sel_idx + 1) % #group)
                if group[sel_idx+1].chance > 0 then -- 
                    sel_idx = sel_idx + 1
                    break
                end
            end
        elseif add == 0 then -- No chances
            sel_idx = 0
        end
        group.selected = sel_idx - 1 -- group.selected is 0 based!!   

        -- get the selected item and take that will be unmuted/not muted
        UpdateTakes(group, sel_idx)
        ::continue::
    end
    reaper.UpdateArrange()
end

--Select a take at the group table.
---@param group table
---@param idx number take idx at group table (1 based) 
function AlternateSelectTake(group,idx)
    group.selected = idx - 1 -- group.selected is 0 based
    UpdateTakes(group, idx)
end

---Chackes if a used_idx table have a certain id
function UsedIdxHaveTake(used_idx_table,take)
    for index, take_table in ipairs(used_idx_table) do
        if take_table.take == take then 
            return index
        end
    end
    return false
end

function UpdateTakes(group, sel_idx)
    -- get the selected item and take that will be unmuted/not muted
    local sel_item, sel_take
    local sel_child_items = {} -- saves child items to be NOT muted
    if sel_idx > 0 then
        sel_take = group[sel_idx].take
        sel_item = reaper.GetMediaItemTake_Item(sel_take) -- 1 based
        reaper.SetActiveTake( sel_take )
        -- update child active take
        for child_idx, child_take in ipairs(group[sel_idx].child_takes) do
            reaper.SetActiveTake( child_take )
            local child_item = reaper.GetMediaItemTake_Item(child_take)
            sel_child_items[#sel_child_items+1] = child_item
        end
    end
    -- Apply mutting
    for index, v in ipairs(group) do
        local take = v.take 
        -- mute/unmute
        local item = reaper.GetMediaItemTake_Item(take)
        local mute = (sel_item == item and 0) or 1
        reaper.SetMediaItemInfo_Value(item, 'B_MUTE', mute)
        --update child items mute
        for child_idx, child_take in ipairs(v.child_takes) do
            local child_item = reaper.GetMediaItemTake_Item(child_take)
            local child_mute = (TableHaveValue(sel_child_items,child_item) and 0) or 1
            reaper.SetMediaItemInfo_Value(child_item, 'B_MUTE', child_mute)
        end
    end
end

-------------------
-- Group Operations
-------------------

function Add_ChildTakes(take_table) -- TODO check if item from the take is already at this take_table , can only focus on one.
    for item in enumSelectedItems(FocusedProj) do
        local take = reaper.GetActiveTake(item)
        if not TableHaveValue(take_table.child_takes,take) then -- check if THIS child take table already have this take (makes no sense to have duplicates in child takes)
            --check if the new item from the sel take is already at this take_table (with another take) , can only focus on one, delete the older.
            local new_child_item = reaper.GetMediaItemTake_Item(take)
            for child_idx, child_take in ipairs_reverse(take_table.child_takes) do
                if reaper.GetMediaItemTake_Item(child_take) == new_child_item then 
                    table.remove(take_table.child_takes,child_idx)
                end
            end
            -- add take
            table.insert(take_table.child_takes, take)
        end
    end    
end

function Set_ChildTakes(take_table)
    Delete_ChildTakes(take_table)
    Add_ChildTakes(take_table)
end

function Delete_ChildTakes(take_table)
    take_table.child_takes = {}    
end

function CreateNewGroup(name)
    local default_table = {name = name,
                           selected = 0, -- saves last selected take (for playlist mode)
                           used_idx = {}, -- saves used idxes (for shuffle mode)
                           mode = 0,
                           on = true,
                           doatloop = true,
                           doatstop = true} 
    return default_table
end

function AddToGroup(group)
    for item in enumSelectedItems(FocusedProj) do
        for take in enumTakes(item) do
            group[#group+1] = {take = take, chance = 1, child_takes = {}}
        end
    end
    group.used_idx = TableiCopy(group)   
end

function SetGroup(group)
    DeleteFromGroup(group)
    AddToGroup(group)
end

function DeleteFromGroup(group)
    -- Delete current takes
    for k, v in ipairs(group) do
        group[k] = nil        
    end    
end

-------------------
-- Configs Table
-------------------

function CreateProjectConfigTable(project)
    local is_play = reaper.GetPlayStateEx(project)&1 == 1
    local t = {
        groups = {CreateNewGroup('G1')},
        oldpos = (is_play and reaper.GetPlayPositionEx( project )) or reaper.GetCursorPositionEx(project), 
        oldtime = reaper.time_precise(),
        oldisplay = is_play,
        is_loopchanged = false, -- If true then the script alternated the items in this loop
    }   
    return t
end