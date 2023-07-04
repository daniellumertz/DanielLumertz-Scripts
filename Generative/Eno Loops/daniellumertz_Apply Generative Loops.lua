-- @version 0.1
-- @description Generative Loops
-- @author Daniel Lumertz
-- @provides
--    [nomain] Functions/*.lua
--    [main] daniellumertz_Generative Items Settings GUI.lua
--    [main] daniellumertz_Delete All Generated Items.lua
--    [main] daniellumertz_Remove Generative Loops Tag From Selected Items.lua
-- @changelog
--    + beta
-- @license MIT
-- Only delete if the items are above an # 
-- TODO stop pasting if ## is inside the area it is pasting into, maybe instead of banning items stop pasting is better
--dofile("C:/Users/DSL/AppData/Roaming/REAPER/Scripts/Meus/Debug VS/DL Debug.lua")
reaper.ClearConsole()


------ USER SETTINGS
local clean_before_apply = true -- clean all items previously created and then paste new ones
------ Load Functions
-- Function to dofile all files in a path
function dofile_all(path)
    local i = 0
    while true do 
        local file = reaper.EnumerateFiles( path, i )
        i = i + 1
        if not file  then break end 
        dofile(path..'/'..file)
    end
end

-- get script path
ScriptPath = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
-- dofile all files inside functions folder
dofile_all(ScriptPath..'/'..'Functions')

------- Check Requirements
if not CheckReaImGUI('0.8.6.1') or not CheckJS() or not CheckSWS() or not CheckREAPERVersion('6.80') then return end -- Check Extensions
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8') -- Made with Imgui 0.8 add schims for future versions.


local proj = 0
-- Start 
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock2(proj)
ExtStatePatterns() -- load ext state name variable 

--- Saves information
local original_pos = reaper.GetCursorPositionEx( proj )
local original_selection = CreateSelectedItemsTable()
local original_lt = reaper.GetLastTouchedTrack() -- lt = last touched
local ortiginal_sel_tracks = CreateSelectedTracksTable(proj)
local original_loop_start, original_loop_end = reaper.GetSet_LoopTimeRange2(proj, false, false, 0, 0, false)
local original_envelope_sel = reaper.GetSelectedEnvelope( proj )
local original_context =  reaper.GetCursorContext2( true )
local original_start_time, original_end_time = reaper.GetSet_ArrangeView2( proj, false, 0, 0, 0, 0 )
reaper.SelectAllMediaItems( proj, false ) -- for safeness remove any item selection
local original_envattach = reaper.SNM_GetIntConfigVar('envattach',5)
local original_ripple = reaper.SNM_GetIntConfigVar('projripedit',5)
-- Turn off envelope move with items and ripple edit
reaper.SNM_SetIntConfigVar('envattach',0) -- turn off envattach (envelope move with items)
reaper.SNM_SetIntConfigVar('projripedit',0) -- turn off ripple eddit

-- Patterns
local loop_item_possibility = 'p'
local loop_item_weight = 'w'

-- Items Random options 
local rnd_values = SetDefaults()

if clean_before_apply then 
    --CleanAllItemsLoop(proj, Ext_Name, LoopItemExt)

    for item in enumItems(proj) do -- Delete automation items and items inside loop items range
        for take in enumTakes(item) do
            for retval, tm_name, color in enumTakeMarkers(take) do 
                if tm_name:match('^%s-'..LoopItemSign_literalize) then
                    local item_pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
                    local item_len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
                    local item_end = item_pos + item_len
                    DeleteAutomationItemsInRange(proj,item_pos,item_end,false,false)
                    -- items
                    local items_in_range = GetItemsInRange(proj,item_pos,item_end,false,false)
                    for k, item_range in ipairs(items_in_range) do
                        local retval, stringNeedBig = GetItemExtState(item_range,Ext_Name,LoopItemExt)
                        --local retval, stringNeedBig = reaper.GetSetMediaItemInfo_String( item, 'P_EXT:'..ext_pattern, '', false )
                        if stringNeedBig ~= '' then 
                            reaper.DeleteTrackMediaItem( reaper.GetMediaItem_Track(item_range), item_range )
                        end
                    end
                end
            end
        end
    end
end

local items = CreateItemsTable(proj)
local banned_items = {} -- List of regions with banned_items ex {region_name = {take_name,take_name,take_name}}

for k_item, item in ipairs(items) do
    local loop_possibilities = {}
    for take in enumTakes(item) do
        for retval, tm_name, color in enumTakeMarkers(take) do -- tm = take marker 
            if tm_name:match('^%s-'..LoopItemSign_literalize) then 
                local user_region_id = tonumber(tm_name:match('^%s-'..LoopItemSign_literalize..'%s-(%d+)')) -- to check if the id is right and not misspelled
                if user_region_id then --  ## MARKER! found in a take
                    local take_options = GetLoopOptions(nil,take)
                    local weight = take_options.TakeChance
                    local playrate_min = take_options.PlayRateRandomMin
                    local playrate_max = take_options.PlayRateRandomMax
                    local playrate_quantize = take_options.PlayRateQuantize
                    loop_possibilities[take] = {chance = chance, weight = weight, tm_name = tm_name, take = take, user_region_id = user_region_id, playrate_min = playrate_min, playrate_max = playrate_max, playrate_quantize = playrate_quantize}

                    break -- will only catch the first marker on a take
                end
            end
        end
    end
    if TableLen(loop_possibilities) == 0 then goto continue end -- no ## marker in this item

    -- Get Item options
    local item_options = GetLoopOptions(item,nil)
    local selected_mark 
    if item_options.RandomizeTakes then
        -- select one of the takes 
        local sum_chance = 0
        for key, possibility_table in pairs(loop_possibilities) do
            sum_chance = sum_chance + possibility_table.weight
        end
        local random_number = RandomNumberFloat(0,sum_chance,false)
        local addiction_weights = 0
        for take, possibility_table in pairs(loop_possibilities) do
            addiction_weights = addiction_weights + possibility_table.weight
            if addiction_weights > random_number then
                selected_mark = possibility_table
                break
            end
        end
    else
        local take = reaper.GetActiveTake(item)
        selected_mark = loop_possibilities[take]
    end


    -- Get region info
    local retval, isrgn, region_start, region_end ,region_name,region_user_id,color,region_id = GetMarkByID(proj,selected_mark.user_region_id,2)
    local region_len = region_end - region_start
    if not retval then goto continue end -- no marker with that ID

    -- Get information
    local item_mute = reaper.GetMediaItemInfo_Value(item, 'B_MUTE')
    if item_mute == 1 then goto continue end

    local item_pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    local item_len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    local item_end = item_pos + item_len
    local item_rate = reaper.GetMediaItemTakeInfo_Value(selected_mark.take, 'D_PLAYRATE')
    local rate_ratio = 1/item_rate
    local rate_table = {} -- when randomizing the rate when pasting the items need to save the sequence of random value to use whhen copying automation items! if not randomizing will just write 1,1,1,1,

    local item_pitch = reaper.GetMediaItemTakeInfo_Value(selected_mark.take, 'D_PITCH') 
    
    -- Set cursor position
    reaper.SetEditCurPos2(proj, item_pos, false, false)
    
    -- Get Items in range
    local items_in_region = GetItemsInRange(proj,region_start,region_end,false,false)
    -- Check if one of the items have the ## pattern
    for k,check_item in ipairs_reverse(items_in_region) do
        for check_take in enumTakes(check_item) do
            for retval, tm_name, color in enumTakeMarkers(check_take) do -- tm = take marker 
                if tm_name:match('^%s-'..LoopItemSign_literalize) then 
                    if not banned_items[region_user_id] then
                        banned_items[region_user_id] = {}
                    end
                    local retval, take_name = reaper.GetSetMediaItemTakeInfo_String(check_take, 'P_NAME', '', false)
                    table.insert(banned_items[region_user_id],take_name)
                    table.remove(items_in_region,k) -- remove item from the copy items list
                end
            end
        end
    end
    -- Get Automation Items in range 

    -- Copy Items
    local original_item_rate = item_rate
    while #items_in_region > 0 and true do  
        local random_rate = RandomNumberFloatQuantized(selected_mark.playrate_min, selected_mark.playrate_max, true, selected_mark.playrate_quantize)
        item_rate = original_item_rate * random_rate
        rate_ratio = 1/item_rate
        rate_table[#rate_table+1] = random_rate
        -- Check if need to break
        
        local cur_pos = reaper.GetCursorPosition()
        if RemoveDecimals(cur_pos,3) >= RemoveDecimals(item_end,3) then break end -- BREAK need to round to 3 decimal places as the time selection (for smart copy) wont go so small      

        ----- Set Time Selection To Smart Copy
        local remaning_len = (item_end - cur_pos) * item_rate-- how many in time need to be pasted

        local loop_end 
        if (region_start + remaning_len) < region_end then -- if needs to copy a smaller area than all the region 
            loop_end  = (region_start + remaning_len)
        else -- needs to copy everything
            loop_end = region_end
        end
        local paste_len = loop_end - region_start

        local _, _ = reaper.GetSet_LoopTimeRange2(proj, true, true, region_start, loop_end, false)

        ----- Set Last Touched track to first track with selected items
        local first_track = reaper.GetMediaItem_Track(items_in_region[1])  
        reaper.SetOnlyTrackSelected(first_track)
        reaper.Main_OnCommand(40914,0) -- Set first selected track as last touched

        ------ Select Items
        SelectItemList(items_in_region, false, proj) --(Needs to do everyitme as pasting change item selection and last touched track)

        ------ Smart Copy TODO REMAKE THE SCRIPT WITHOUT USING SMART COPY AND PASTE but keep to this demo
        reaper.SetCursorContext( 1, nil )
        reaper.Main_OnCommand(41383, 0) -- Edit: Copy items/tracks/envelope points (depending on focus) within time selection, if any (smart copy)
        reaper.SelectAllMediaItems( proj, false ) -- After paste only the pasted items should be selected. This makes sure of it. For some reason there is a chance that just copy and paste wont just have the copied items.
        ------ Paste
        while true do -- For some reason there is a chance of not pasting the items, check if pasted by counting items
            reaper.Main_OnCommand(42398, 0) -- Item: Paste items/tracks
            if reaper.CountSelectedMediaItems(proj) ~= 0 then
                break
                --return
            end
        end

        -- Set information in new items
        local sel_table = {}
        for new_item in enumSelectedItems(proj) do
            sel_table[#sel_table+1] = new_item
        end

        for index, new_item in ipairs(sel_table) do
            SetItemExtState(new_item,Ext_Name,LoopItemExt,'true')
            --reaper.GetSetMediaItemInfo_String( new_item, 'P_EXT:'..ext_state_key, ext_state_key, true ) -- using the key as identifier, could be anything, unless I want to add more things at the same key
            -- Get item random values
            GetOptionsItemTake(rnd_values, new_item)
            -- Randomize Take
            local active_take
            if rnd_values.RandomizeTakes then
                local random_take = {}
                for new_take in enumTakes(new_item) do
                    local chance = tonumber(select(2, GetTakeExtState(new_take, Ext_Name, Ext_TakeChance)))
                    if chance == '' then
                        chance = 1
                    end
                    random_take[#random_take+1] = {weight = chance, take = new_take}
                end
                local k,v = TableRandomWithWeight(random_take)
                active_take = (v and v.take) or reaper.GetActiveTake(new_item) -- if chances are 0 use active take
                reaper.SetActiveTake(active_take)
            else
                active_take = reaper.GetActiveTake(new_item)              
            end
            
            -- Get item info 
            local new_item_pos = reaper.GetMediaItemInfo_Value(new_item, 'D_POSITION')
            local active_take_random_rate = 1 -- need to save how much the random rate changed the active take to change the length and fades.
            for new_take in enumTakes(new_item) do
                GetOptionsItemTake(rnd_values, nil, new_take)
                local new_take_rate = reaper.GetMediaItemTakeInfo_Value(new_take, 'D_PLAYRATE') 
                local random_rate = RandomNumberFloatQuantized(rnd_values.PlayRateRandomMin,rnd_values.PlayRateRandomMax, true,rnd_values.PlayRateQuantize)
                local new_rate = (new_take_rate * item_rate) * random_rate
                if new_take == active_take then 
                    active_take_random_rate = random_rate
                end

                local new_take_pitch = reaper.GetMediaItemTakeInfo_Value(new_take, 'D_PITCH')
                local random_pitch = RandomNumberFloat(rnd_values.PitchRandomMin,rnd_values.PitchRandomMax, true)
                random_pitch = QuantizeNumber(random_pitch,rnd_values.PitchQuantize)
                local new_pitch = new_take_pitch + item_pitch + random_pitch

                reaper.SetMediaItemTakeInfo_Value(new_take, 'D_PLAYRATE', new_rate) 
                reaper.SetMediaItemTakeInfo_Value(new_take, 'D_PITCH', new_pitch + random_pitch) 
            end
            local rate_inversive = rate_ratio * (1/active_take_random_rate) 
            -- To change the rate and preserve the length (like it is stretching the item):
            local new_item_len = reaper.GetMediaItemInfo_Value( new_item, 'D_LENGTH' )
            local new_len =  new_item_len * rate_inversive
            reaper.SetMediaItemInfo_Value(new_item, 'D_LENGTH', new_len) 
            local new_item_fadein = reaper.GetMediaItemInfo_Value( new_item, 'D_FADEINLEN' )
            reaper.SetMediaItemInfo_Value(new_item, 'D_FADEINLEN', new_item_fadein * rate_inversive )
            local new_item_fadeout = reaper.GetMediaItemInfo_Value( new_item, 'D_FADEOUTLEN' )
            reaper.SetMediaItemInfo_Value(new_item, 'D_FADEOUTLEN', new_item_fadeout * rate_inversive)
            local new_pos = cur_pos + ((new_item_pos - cur_pos) * rate_ratio)
            local random_time = RandomNumberFloat(rnd_values.TimeRandomMin,rnd_values.TimeRandomMax, true)
            random_time = QuantizeNumber(random_time,rnd_values.TimeQuantize)
            reaper.SetMediaItemInfo_Value(new_item, 'D_POSITION', new_pos + random_time)


            -- Stretch the envelope (this wont work properlly as it still using copy paste. todo remove the copy paste and make a proper function to make copies with envelopes) the problem with the current version is that multiple items will scramble the envelope of the others when stretching. also very slow. It is possible to do this way but would need to do it after all items are placed and not in the iteration
            --[[ if  reaper.SNM_GetIntConfigVar('envattach',3)&1 == 1 then -- check if move envelope with items is on, if is move copied envelopes together
                local new_item_track = reaper.GetMediaItem_Track(new_item)
                for envelope in enumTrackEnvelopes(new_item_track) do

                    local env_points = {} -- need to get the information, calculate new values, for all underlying points and then delete the points and insert new ones.  
                    for retval, time, value, shape, tension, selected, idx in enumTrackEnvelopesPointsEx(envelope, -1) do -- -1 to only get points on the underlying envelope
                        --check if is underlying
                        if time >= new_item_pos and time <= new_item_pos + new_item_len then -- using old item position to get the underlying envelopes that were copied with the item
                            local new_time = cur_pos + ((time - cur_pos) * rate_ratio)
                            env_points[#env_points+1] = { time = new_time, value = value, shape = shape, tension = tension, selected = selected, idx = idx, is_insert = true}
                        elseif time > new_pos and time <= new_pos + new_len then--points in the new position that needs to be deleted.
                            env_points[#env_points+1] = {is_insert = false,idx = idx} 
                        elseif time > math.max(new_item_pos + new_item_len, new_pos + new_len) then -- after this item pasted position or new position. (gets the bigger value between the two)
                            break
                        end
                    end
                    for index, point_table in ipairs_reverse(env_points) do
                        reaper.DeleteEnvelopePointEx(envelope, -1, point_table.idx)
                    end
                    for index, point_table in ipairs(env_points) do
                        if point_table.is_insert then
                            reaper.InsertEnvelopePointEx(envelope, -1, point_table.time, point_table.value, point_table.shape, point_table.tension, point_table.selected, true)
                        end
                    end
                    reaper.Envelope_SortPointsEx( envelope, -1)
                end
            end ]]            
        end
        ------ Need to manually set the cursor to consider the ## playrate
        local new_cur_pos = cur_pos + (paste_len/item_rate)
        reaper.SetEditCurPos2(proj, new_cur_pos, false, false) 
    end
    item_rate = original_item_rate
    rate_ratio = 1/item_rate


    -- Copy Automation Items
    for track in enumTracks(proj) do
        for env in enumTrackEnvelopes(track) do
            local cnt = reaper.CountAutomationItems(env)
            local i = 0
            while cnt ~= 0 and i < cnt do
                local pos = reaper.GetSetAutomationItemInfo(env, i, 'D_POSITION', 0, false)
                if pos >= region_end then break end -- start after range. break
                local len = reaper.GetSetAutomationItemInfo(env, i, 'D_LENGTH', 0, false)
                local final_pos = len + pos

                if final_pos > region_start then -- Automation item in the range
                    local rate = reaper.GetSetAutomationItemInfo(env, i, 'D_PLAYRATE', 0, false)
                    local new_rate = rate * item_rate
                    local rate_ratio = rate/new_rate

                    local delta_pos = pos - region_start-- distance from region start (can be negative if the ai start before the region)

                    local paste_start = item_pos
                    local paste_end = paste_start + (region_len  * rate_ratio)
                    local remaning_len = item_len -- how many in time need to be pasted

                    local pasting_idx = 1
                    while true do -- paste multiple times
                        local random_rate = rate_table[pasting_idx] or RandomNumberFloatQuantized(selected_mark.playrate_min, selected_mark.playrate_max, true, selected_mark.playrate_quantize)
                        local item_rate = item_rate * random_rate
                        local rate_ratio = 1/item_rate
                        local new_rate = new_rate * random_rate
                        pasting_idx = pasting_idx + 1
                        -- Automation Items inside the range: 

                        local new_pos = paste_start + (delta_pos * rate_ratio)
                        if new_pos >= item_end then 
                            break
                        end

                        local ai_id = reaper.GetSetAutomationItemInfo(env, i, 'D_POOL_ID', 0, false)
                        local idx = reaper.InsertAutomationItem(env, ai_id, new_pos, len * rate_ratio)
                        local trim_end = math.min(paste_start + paste_end,item_end)
                        CopyAutomationItemsInfo_Value(env, env, i,idx, {'D_BASELINE', 'D_AMPLITUDE', 'D_LOOPSRC', 'D_STARTOFFS'})
                        reaper.GetSetAutomationItemInfo(env, idx, 'D_PLAYRATE', new_rate, true)
                        TrimAutomationItem(env,idx,paste_start,trim_end) -- paste_pos, len_paste

                        -- change rate, randomize etc etc
                        
                        paste_start = paste_start + (region_len/item_rate)
                        if RemoveDecimals(paste_start,3) >= RemoveDecimals(item_end,3) then 
                            break
                        end
                    end
                    item_rate = original_item_rate
                    rate_ratio = 1/item_rate
                end
                    
                i = i + 1
            end
        end
    end

    ::continue::
end

-- Alert the user if some ## item is in a region 
if #banned_items > 0 then
    print('---------******---------')
    print('---------******---------')
    print('THERE ARE ## ITEMS INSIDE A REGION:')
    print('!!!!!!!THESE ITEMS WONT BE COPIED!!!!')
    for region_name,takes_table in pairs(banned_items) do
        print('REMOVE AT REGION: ',region_name)
        print('THE FOLLOWING TAKES:')
        for k,take_name in ipairs(takes_table) do
            print(take_name)
        end
    end
    print('---------******---------')
    print('---------******---------')
end

--- Restore original info
reaper.SetOnlyTrackSelected(original_lt or reaper.GetTrack(proj, 0)) -- Last TOuched Track
reaper.Main_OnCommand(40914,0) -- Set first selected track as last touched
reaper.SetEditCurPos2(proj, original_pos, false, false) -- Edit Cursor
SelectItemList(original_selection, true, proj) -- Selected Items
SelectTrackList(ortiginal_sel_tracks, true, proj) -- Selected Tracks
reaper.GetSet_LoopTimeRange2(proj, true, true, original_loop_start, original_loop_end, false) -- Time selection
reaper.SetCursorContext( original_context, original_envelope_sel ) -- Context and Envelope Selected
reaper.GetSet_ArrangeView2( proj, true, 0, 0, original_start_time, original_end_time )
reaper.SNM_SetIntConfigVar('envattach',original_envattach) 
reaper.SNM_SetIntConfigVar('projripedit',original_ripple)

-- Update arrange
reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock2(proj, 'Apply Eno Loops', -1)

