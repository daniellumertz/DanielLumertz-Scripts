--@noindex
--version 0.3
--added an optional argument for GetItemsInRange to include items that ends at start_range and starts at fim_range
--version: 0.2
--add get/set mix behavior

DL = DL or {}
DL.item = {}

---Select A list of items or one item. Validate them first
---@param itemlist MediaItem[]|MediaItem List of items to select. {item1, item2, item3} as userdata. Or just the item
---@param unselect boolean optional, unselect before selecting? 
---@param proj ReaProject|nil|0
function DL.item.SelectItems(itemlist, unselect, proj)
    if unselect == nil then unselect = true end -- make it optional
    proj = proj or 0
    if unselect then  -- Deselect all selected items
        reaper.SelectAllMediaItems( proj, false )
    end
    if type(itemlist) == 'userdata' then itemlist = {itemlist} end
    for i, item in ipairs(itemlist) do
        if reaper.ValidatePtr2(proj, item, 'MediaItem*') then
            reaper.SetMediaItemSelected(item, true)
        end
    end
end

---Copy `item` to `track` at `position`
---@param item MediaItem item to be copied
---@param track MediaTrack track to copy to
---@param position number position in seconds to copy to
---@param selected boolean? optional boolean if is selected or not, if nil copy with current state (selecter or not)
---@param pooled_copy boolean? optional if true will make a pooled copy if nil or false will make a independent copy
---@return MediaItem
function DL.item.CopyToTrack(item, track, position, selected, pooled_copy)
    local _, chunk = reaper.GetItemStateChunk( item, "", false )
    chunk = DL.chunk.ResetIndentifiers(chunk, 'GUID', '')
    chunk = DL.chunk.ResetIndentifiers(chunk, 'IGUID', '')
    if not pooled_copy then
        chunk = DL.chunk.ResetIndentifiers(chunk, 'POOLEDEVTS', '')
    end
    chunk = DL.chunk.ResetIndentifiers(chunk, 'FXID', '')
    local new_item = reaper.AddMediaItemToTrack( track )
    reaper.SetItemStateChunk( new_item, chunk, false )
    reaper.SetMediaItemInfo_Value( new_item, "D_POSITION" , position )
    if selected ~= nil then
        reaper.SetMediaItemInfo_Value( new_item, "B_UISEL" , selected and 1 or 0 )
    end
    return new_item
end

---Create Media Item using file path. Length adjusted to the length of the file. If Build_peaks == false call  reaper.Main_OnCommand(40047, 0) -- Peaks: Build any missing peaks after creating multiple items (It will create the peaks multitasking)
---@param path string
---@param track MediaTrack
---@param pos number
---@return MediaItem new_item  
---@return MediaItem_Take active_take
---@return PCM_source file_source
---@return number length
function DL.item.CreateWithFile(path, track, pos, build_peaks)
    local item = reaper.AddMediaItemToTrack( track )
    reaper.SetMediaItemInfo_Value(item, 'D_POSITION', pos)
    local take = reaper.AddTakeToMediaItem( item )
    local source = reaper.PCM_Source_CreateFromFile( path )
    reaper.SetMediaItemTake_Source( take, source )
    local len, is_qn = reaper.GetMediaSourceLength( source )
    if len then
        reaper.SetMediaItemInfo_Value(item, 'D_LENGTH', len )
    end

    if build_peaks and reaper.PCM_Source_BuildPeaks( source, 0 ) ~= 0 then
        while reaper.PCM_Source_BuildPeaks( source, 1 ) ~= 0 do end
        reaper.PCM_Source_BuildPeaks( source, 2 )        
    end
    reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', DL.files.GetName(path,true), true)
    return item, take, source, len
end

---Create a table with the selected items
---@return MediaItem[] selected_items
function DL.item.CreateSelectedItemsTable(proj)
    local t = {}
    for item in DL.enum.SelectedMediaItem(proj) do
        t[#t+1] = item
    end
    return t
end

---Crop Item position keeping elements on the same place
---@param item MediaItem
---@param new_start_pos number optional new start position in seconds
---@param new_end_pos number optional new end position in seconds
---@param start number optional original start position in seconds, if not provided function will get it, provide if you already have and save resources 
---@param length number optional original length position in seconds, if not provided function will get it, provide if you already have and save resources 
function DL.item.Crop(item, new_start_pos, new_end_pos, start, length)
    start = start or reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    length = length or reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    local fim = start + length
    if new_end_pos then
        local dif = fim - new_end_pos
        reaper.SetMediaItemLength( item, length - dif, false )
        length = length - dif
    end
    if new_start_pos then
        local dif = new_start_pos - start
        reaper.SetMediaItemPosition(item, new_start_pos, false)
        reaper.SetMediaItemLength( item, length - dif, false )

        for take in DL.enum.Takes(item) do
            local offset = reaper.GetMediaItemTakeInfo_Value(take, 'D_STARTOFFS')            
            local rate = reaper.GetMediaItemTakeInfo_Value(take, 'D_PLAYRATE')            
            reaper.SetMediaItemTakeInfo_Value( take, 'D_STARTOFFS' , offset + (dif*rate) )
        end
    end    
end

---Return a list with all items in a project
---@param proj ReaProject|nil|0
function DL.item.CreateItemsTable(proj)
    local t = {}
    for item in DL.enum.Items(proj) do
        t[#t+1] = item
    end
    return t
end


---Select an item, or list of items. Option to moveview to the first item at the center of the screen using current zoom 
---@param proj ReaProject|nil|0
---@param item MediaItem|MediaItem[]
---@param moveview boolean move view to the first item?
function DL.item.SetSelected(proj, item, moveview)
    DL.item.SelectItems(item, true, proj)
    if not moveview then
        return
    end
    if type(item) == 'table' then item = item[1] end -- just the first item
    local start_time, end_time = reaper.GetSet_ArrangeView2( proj, false, 0, 0, 0, 0 )
    local pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    if pos < start_time or pos > end_time then -- Item out of view, center the view at the item start
        local dif = end_time - start_time
        start_time, end_time = reaper.GetSet_ArrangeView2( proj, true, 0, 0, pos-(dif*1/3), pos+(dif*2/3))
    end
end

---Write an ext state at an item
---@param item MediaItem
---@param extname string name of the ext state section
---@param key string name of the key inside the extname section
---@param value string value to store 
---@return boolean
function DL.item.SetExtState(item, extname, key, value)
    local  retval, extstate = reaper.GetSetMediaItemInfo_String( item, 'P_EXT:'..extname..': '..key, value, true )
    return retval
end

---Return the item ext state value
---@param item MediaItem
---@param extname string name of the ext state section
---@param key string name of the key inside the extname section
---@return boolean retval
---@return string value
function DL.item.GetExtState(item, extname, key)
    local retval, extstate = reaper.GetSetMediaItemInfo_String( item, 'P_EXT:'..extname..': '..key, '', false )
    return retval, extstate
end

---Return a list with all items in a time range
---@param proj ReaProject|nil|0
---@param start_range number beginning of the range (start point are includded in the range)
---@param fim_range number end of the range (end points are not includded in the range)
---@param only_start_in_range boolean only get items that start inside the range (if start at start_range it is includded)
---@param only_end_in_range boolean only get items that end inside the range (if end at the fim_range it is includded)
---@param inclusive boolean? optional, if true, include items that ends at start_range and starts at fim_range
---@return MediaItem[]
function DL.item.GetItemsInRange(proj,start_range,fim_range,only_start_in_range,only_end_in_range, inclusive)
    inclusive = inclusive or false
    local item_list = {}
    for track in DL.enum.Tracks(proj) do
        for item in DL.enum.TrackMediaItem(track) do 
            local pos = reaper.GetMediaItemInfo_Value( item, 'D_POSITION')

            if only_start_in_range and pos < start_range then goto continue end -- filter if only_start_in_range 
            if inclusive then -- start after range. break
                if pos > fim_range then break end 
            else
                if pos >= fim_range then break end 
            end

            local len = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH')
            local final_pos = len + pos
            if only_end_in_range and final_pos > fim_range then goto continue end -- filter if only_end_in_range

            local end_check
            if inclusive then
                end_check = final_pos >= start_range
            else
                end_check = final_pos > start_range
            end

            if end_check then
                item_list[#item_list+1] = item
            end

            ::continue::
        end
    end
    return item_list
end

---Returns the path of active take in `item`. If Item dont have associated file with it, return false. 
---@param item MediaItem
---@return string|boolean
function DL.item.GetPath(item)
    local take = reaper.GetActiveTake(item)
    if take then
        local source = reaper.GetMediaItemTake_Source(take) -- Get the source of the take
        local filePath = reaper.GetMediaSourceFileName(source) -- Get the file path
        return filePath
    else
        return false
    end
end

---Gets one item, glue it and change the path of the glued file. File MUST be online, else reaper glue deletes the item! This will change item selection! So make a list of selected items first. 
---@param proj 0|ReaProject|nil project
---@param item MediaItem
---@param new_path string? string to save the file. If nil it will overwrite (to overwrite, can also pass the current path of the source)
---@param check_glue_type boolean? False by default. check if glue is set to automatic (if running multiple times copy the code and set to false)
---@param build_peaks boolean? False by default. build missing peaks after creating the file (if running multiple times copy the code and set to false)
---@return MediaItem|boolean item
---@return boolean sucess_copy successfully copied the glued file to the new_path. Else return `error 
---@return string|nil error if copy wasn't successfully, return the error message here
---@return string? glue_path the path of the original just glued file. If copy was a sucess, the file was deleted. If it failed the file is leaved there (do something with it!)
function DL.item.Glue(proj, item, new_path, check_glue_type, build_peaks)
    local old_glue_type
    if check_glue_type then
        local glue_type = reaper.SNM_GetIntConfigVar('projrecforopencopy', -1)
        if glue_type ~= 0 then
            old_glue_type = glue_type
            reaper.SNM_SetIntConfigVar('projrecforopencopy', 0)
        end
    end

    if not new_path then -- Overwrite mode!
        local take = reaper.GetActiveTake(item) 
        local source = reaper.GetMediaItemTake_Source(take) -- Get the source of the take
        new_path = reaper.GetMediaSourceFileName(source) -- Get the file path
    end

    reaper.SelectAllMediaItems( proj, false )
    reaper.SetMediaItemSelected(item, true)
    reaper.Main_OnCommand(40362, 0) -- Item: Glue items, ignoring time selection

    -- Copy
    local item = reaper.GetSelectedMediaItem(proj, 0)
    local take = reaper.GetActiveTake(item)
    if not take then return false, false, 'Item have no take!' end

    local glue_source = reaper.GetMediaItemTake_Source(take)
    local glue_path  = reaper.GetMediaSourceFileName(glue_source)
    local bol, err
    if glue_path ~= new_path then
        bol, err = DL.files.Copy(glue_path,new_path)
        if bol then -- Could create the file at new_path, substitute the original source on item
            local new_source = reaper.PCM_Source_CreateFromFile( new_path )
            reaper.SetMediaItemTake_Source( take, new_source )

            reaper.PCM_Source_Destroy(glue_source)
            os.remove(glue_path)
            
            if build_peaks then
                reaper.Main_OnCommand(40047, 0) --Peaks: Build any missing peaks
            end
        end 
    else 
        bol = true
    end

    if old_glue_type then -- put it back
        reaper.SNM_SetIntConfigVar('projrecforopencopy', old_glue_type)
    end
    return item, bol, err, glue_path
end

---Set an Image to an Item
---@param item MediaItem
---@param image_path string
---@param mode number
---@return boolean 
---@return string chunk
function DL.item.SetImage(item, image_path, mode)
    mode = mode or 3
    local retval, chunk = reaper.GetItemStateChunk(item, '', false)
    if not retval then return false, chunk end
    local chunk_image = string.format("RESOURCEFN \"%s\"\nIMGRESOURCEFLAGS %s\n", image_path, mode)
    if string.match(chunk, '\nRESOURCEFN') then
        chunk = string.gsub(chunk, '\nRESOURCEFN.-\nIMGRESOURCEFLAGS.-\n', '\n'..chunk_image)
    else -- does not have an image
        chunk = string.gsub(chunk,'^<ITEM\n','<ITEM\n'..chunk_image)
    end
    local bool = reaper.SetItemStateChunk(item, chunk)
    return bool, chunk
end

---Get item mix behavior
---@param item MediaItem
---@return boolean|number|number? -- false if couldn't find chunk. -1 = Project default item mix behavior, 0 = Enclosed items mix before enclosing items, 1 = Items always mix, 2 = Lower always replace earlier items
function DL.item.GetMixBehavior(item)
    local bol, chunk = reaper.GetItemStateChunk(item, '')
    if not chunk then
        return false
    end
    local mix = chunk:match('\nMIXFLAG (%d+)')
    if not mix then 
        return -1
    end
    return tonumber(mix)
end

---Set item mix behavior
---@param item MediaItem
---@param behavior number -1 = Project default item mix behavior, 0 = Enclosed items mix before enclosing items, 1 = Items always mix, 2 = Lower always replace earlier items
---@return boolean 
function DL.item.SetMixBehavior(item, behavior)
    local bol, chunk = reaper.GetItemStateChunk(item, '')
    if not chunk then
        return false
    end

    local new_value = '\nMIXFLAG '..tostring(behavior)
    local new_chunk
    if chunk:match('\nMIXFLAG') then
        new_chunk = chunk:gsub('\nMIXFLAG (%d+)', new_value)
    else
        new_chunk = string.gsub(chunk,'^<ITEM\n','<ITEM\n'..new_value)
    end

    return reaper.SetItemStateChunk(item, new_chunk)
end