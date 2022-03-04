-- @noindex
function LoadClipboardTable()
    local clipboard_table = {} -- debug put as local
    local retval, table_string = reaper.GetProjExtState(0, 'Clipboard', 'table')

    if retval == 1 and table_string ~= '' then
        clipboard_table = table.load( table_string )
    end
    return clipboard_table
end

function SaveClipboardTable(clipboard_table)
    clipboard_table = CovertUserDataToGUIDRecursive(clipboard_table)

    local table_string = table.save( clipboard_table )

    reaper.SetProjExtState( 0, 'Clipboard', 'table', table_string )
end

function PasteList(list)
    -- Checks
    if #list <= 0 then return end
    
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    reaper.Main_OnCommand(40289, 0)--Item: Unselect all items
    -- Load Items
    LoadSelectedItems(list)
    -- Copy
    reaper.Main_OnCommand(40057, 0)--Edit: Copy items/tracks/envelope points (depending on focus) ignoring time selection

    -- Paste
    reaper.Main_OnCommand(42398, 0) --Item: Paste items/tracks

    -- Ends
    reaper.UpdateArrange()
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock2(0, 'Clipboard: Paste', -1)
end

function CopyList(list)
    -- Checks
    if #list <= 0 then return end

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    -- Save current Selection
    local old_item_list = SaveSelectedItems()
    reaper.Main_OnCommand(40289, 0)--Item: Unselect all items
    -- Copy
    LoadSelectedItems(list)
    reaper.Main_OnCommand(40057, 0)--Edit: Copy items/tracks/envelope points (depending on focus) ignoring time selection
    -- Load Selection
    reaper.Main_OnCommand(40289, 0)--Item: Unselect all items
    LoadSelectedItems(old_item_list)
    -- 
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock2(0, 'Clipboard: Copy Item', -1)
end


function ChangeSelection(list)
    if #list <= 0 then return end
    
    reaper.Undo_BeginBlock()
    reaper.Main_OnCommand(40289, 0)--Item: Unselect all items
    reaper.PreventUIRefresh(1)

    LoadSelectedItems(list)

    reaper.UpdateArrange()
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock2(0, 'Clipboard: Change Selection', -1)
end

function GetItemListName(list)
    local btn_name_list= {}
    for k , list_item in pairs(list) do 
        local items_names = ''
        for _, item in pairs(list_item) do
            if not reaper.ValidatePtr(item, 'MediaItem*') then goto continue end
            local cnt_takes = reaper.CountTakes(item)
            local itemloop_name = ''
            for i = 0, cnt_takes-1 do 
                local take = reaper.GetMediaItemTake(item, i)
                local retval, take_name = reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', '', false)
                itemloop_name = itemloop_name..take_name
                if i ~= cnt_takes-1 then
                    itemloop_name = itemloop_name..', '
                end
            end
            items_names = items_names..'('..itemloop_name..')  '
            ::continue::
        end
        local btn_name = '#'..#list_item..': '..items_names
        table.insert(btn_name_list, btn_name) 
    end
    return btn_name_list
end

function GetItemColorList(list)
    local btn_color_list= {}
    for k , list_item in pairs(list) do 
        local btn_color
        for _, item in pairs(list_item) do -- Goes through the list stop in the first one that it finds color
            if not reaper.ValidatePtr(item, 'MediaItem*') then goto continue end

            local take = reaper.GetMediaItemTake(item, 0)
            btn_color = GetItemColor(item,take)
            if btn_color then break end
            
            ::continue::
        end
        table.insert(btn_color_list, btn_color) 
    end
    return btn_color_list
end


function UpdatePasteClipboard()
    local ClipboardTable = ConvertGUIDToUserDataRecursive(LoadClipboardTable())
    local NamesList = GetItemListName(ClipboardTable)
    local ColorList = GetItemColorList(ClipboardTable)
    return ClipboardTable, NamesList, ColorList
end