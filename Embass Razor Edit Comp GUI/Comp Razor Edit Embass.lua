-- @version 1.2
-- @author Embass and Daniel Lumertz
-- @changelog
--    + Beta release
-- @provides
--    [nomain] General Functions.lua

----------------------
--Script info
----------------------

script_version = "1.0"
---
info = debug.getinfo(1,'S')
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]] -- this script folder
--- Loading
dofile(script_path .. 'General Functions.lua') -- General Functions needed



function print(value) reaper.ShowConsoleMsg(tostring(value).."\n") end



function clear_area_sel()
	reaper.Main_OnCommand(42406, 0) -- Razor edit: Clear all areas
end



function get_area_sel_info(track) --> ok, start, end
	ok, str_areas = reaper.GetSetMediaTrackInfo_String(track, "P_RAZOREDITS", "", false)
	if str_areas == "" then return false end -- exit
	local count, start_time, end_time = 0, nil, nil
	for substring in str_areas:gmatch("%S+") do
		if count == 0 then start_time = substring
		else end_time = substring break end
		count = count + 1
	end
	if start_time ~= nil and end_time ~= nil then
		return true, start_time, end_time
	else
		return false
	end
end

function copy_media_items_to_track(dest_track, start_time, trim_behind)
	reaper.Main_OnCommand(40060, 0) --Item: Copy selected area of items
	local tracks_count = reaper.CountTracks(0)
	reaper.InsertTrackAtIndex(tracks_count, false)
	local track = reaper.GetTrack(0, tracks_count)
	if track == nil then return end -- exit 
	reaper.SetOnlyTrackSelected(track)
	local edit_cur_pos = reaper.GetCursorPosition()
	reaper.SetEditCurPos(start_time, false, false)
	reaper.Main_OnCommand(42398, 0) -- Item: Paste items/tracks
	reaper.SetEditCurPos(edit_cur_pos, false, false) -- restore
	reaper.CF_SetClipboard("") -- clear copy buf
	if reaper.GetMediaTrackInfo_Value(dest_track, "B_SHOWINTCP") == 0 then
		reaper.SetMediaTrackInfo_Value(dest_track, "B_SHOWINTCP", 1)
	end
	reaper.SetOnlyTrackSelected(dest_track)
	local media_items_count = reaper.CountTrackMediaItems(track)
	reaper.SelectAllMediaItems(0, false)
	for i = media_items_count - 1, 0, -1 do
		local media_item = reaper.GetTrackMediaItem(track, i)
		reaper.MoveMediaItemToTrack(media_item, dest_track)
		reaper.SetMediaItemSelected(media_item, true)
	end
	reaper.DeleteTrack(track)
	-- Item: Remove content (trim) behind items
	if trim_behind then reaper.Main_OnCommand(40930, 0) end
end



function on_right_down(p1,p2,p3,p4)
	-- print("RIGHT DOWN")
	local mouse_x, mouse_y = reaper.JS_Window_ClientToScreen(arrange_window, p3, p4)
	_track, _case = reaper.GetTrackFromPoint(mouse_x, mouse_y) 
	if _track ~= nil and _case == 0 and _track ~= reaper.GetMasterTrack(0) then
		reaper.JS_WindowMessage_PassThrough(arrange_window, "WM_RBUTTONUP", true) -- pass
		reaper.JS_WindowMessage_Post(arrange_window, "WM_RBUTTONDOWN", p1, p2, p3, p4) 
	else
		reaper.JS_WindowMessage_PassThrough(arrange_window, "WM_RBUTTONUP", false) -- block
		_track, _case = nil, nil -- clear
	end
	-- clear_area_sel()
end

function OnRightUp()
    
    --Get AS INFO
    local ok, re_start, re_end = get_area_sel_info(_track)
    reaper.Main_OnCommand(40057, 0)--Edit: Copy items/tracks/envelope points (depending on focus) ignoring time selection
    if re_start then             
        reaper.PreventUIRefresh(1)
        reaper.Undo_BeginBlock()
        --SAVE INFO
        local cursor_pos = reaper.GetCursorPosition()
        local last_track = reaper.GetLastTouchedTrack()
        local items_list = SaveSelectedItems()
        local tracks_list = SaveSelectedTracks()

        --LOOP
        for i, dest_track in pairs(dest_table) do
            --Check if need to break this. loop
                local i_break = false -- variable to break copy if need, Can't Show messages in ImGUI

                if dest_track == "Folder" then  dest_track = reaper.GetParentTrack(_track) end

                if track == dest_track then
                    clear_area_sel()
                    local text = [[Source Track = Destination Track]]
                    reaper.ShowConsoleMsg(text, "Error", 0)
                    i_break = true		
                end

                if i_break == true then break end -- Break if needed
            --Action
                reaper.SetOnlyTrackSelected(dest_track)
                reaper.Main_OnCommand(40914,0) -- Set first selected track as last touched
                reaper.SetEditCurPos( re_start, false, false )
                reaper.Main_OnCommand(42398,0) -- Paste 

        end
        --ERASE AS
        reaper.Main_OnCommand(42406, 0)--Razor edit: Clear all areas
        --RESTORE INFO
        if last_track then 
            reaper.SetOnlyTrackSelected( last_track )
            reaper.Main_OnCommand(40914,0) -- Set first selected track as last touched
        end
        reaper.SetEditCurPos( cursor_pos, false, false )
        LoadSelectedItems(items_list)
        LoadSelectedTracks(tracks_list)

        reaper.Undo_EndBlock("RE Comp", -1)
        reaper.PreventUIRefresh(-1)
        reaper.UpdateArrange()
    end

end

function on_right_up()
	-- print("RIGHT UP")
	if _track == nil then return end -- exit
	local track, _track = _track, nil
	local ok, str_start_time, str_end_time = get_area_sel_info(track)
	if not ok then return end -- exit
	local start_time, end_time = tonumber(str_start_time), tonumber(str_end_time)
	if start_time == nil or end_time == nil then return end -- exit
	if start_time == end_time then return end -- exit
	if start_time > end_time then start_time, end_time = end_time, start_time end -- swap

	reaper.PreventUIRefresh(1)
	reaper.Undo_BeginBlock()

    for i, dest_track in pairs(dest_table) do
        local i_break = false -- variable to break copy if need 

        if dest_track == "Folder" then  dest_track = reaper.GetParentTrack(track) end

        if track == dest_track then
            clear_area_sel()
            local text = [[Source Track = Destination Track]]
            reaper.ShowConsoleMsg(text, "Error", 0)
            i_break = true		
        end

        if i_break == true then break end

		clear_area_sel() -- clear area sel on other tracks
		local str_area = string.format([[%s %s '']], str_start_time, str_end_time)
		reaper.GetSetMediaTrackInfo_String(track, "P_RAZOREDITS", str_area, true)
		copy_media_items_to_track(dest_track, start_time, _trim_behind)
    end

	reaper.Undo_EndBlock("Copy media items to dest track", -1)
	reaper.PreventUIRefresh(-1)
	reaper.UpdateArrange()
end

function initMain()

    arrange_window = reaper.JS_Window_FindChildByID(reaper.GetMainHwnd(), 1000)
    if arrange_window == nil then print("error: 1"); return end -- terminate script

    --before_mm = reaper.GetMouseModifier("MM_CTX_ARRANGE_RMOUSE", 0, 0)
    --reaper.SetMouseModifier("MM_CTX_ARRANGE_RMOUSE", 0, 24) -- area selection

    reaper.JS_WindowMessage_Intercept(arrange_window, "WM_RBUTTONDOWN", false) -- block
    reaper.JS_WindowMessage_Intercept(arrange_window, "WM_RBUTTONUP", true) -- pass

    -- init times
     _, _, _right_down_time = reaper.JS_WindowMessage_Peek(arrange_window, "WM_RBUTTONDOWN") -- right down
     _, _, _right_up_time = reaper.JS_WindowMessage_Peek(arrange_window, "WM_RBUTTONUP") -- right up
end

function main()
    if not noinit then       
        initMain()
        noinit = true
    end
    
    if is_on == 'ON' then
        local ok, pass, right_down_time, p1, p2, p3, p4 = reaper.JS_WindowMessage_Peek(arrange_window, "WM_RBUTTONDOWN")
        if _right_down_time ~= right_down_time then
            _right_down_time = right_down_time
            on_right_down(p1,p2,p3,p4)
        end

        local ok, pass, right_up_time, p1, p2, p3, p4 = reaper.JS_WindowMessage_Peek(arrange_window, "WM_RBUTTONUP")
        if _right_up_time ~= right_up_time then
            _right_up_time = right_up_time
            if _track then
                if dsl_mode == true then
                    OnRightUp()
                else
                    on_right_up()
                end
            end
        end
        reaper.defer(main)
    elseif is_on == "OFF" then
        reaper.JS_WindowMessage_ReleaseAll()
        noinit = false
    end
end



function get_dest_track(track) --> dest_track or nil
    --[[ ORIGINAL
	local _, track_guid = reaper.GetProjExtState(0, "emb_dest_track", "track_guid")
	local dest_track = reaper.BR_GetMediaTrackByGUID(0, track_guid)
	if dest_track == nil then dest_track = reaper.GetParentTrack(track) end
	return dest_track
    ]]
end

function SetDest()
    dest_table = {} -- Reset Table of destinations
    local track_count = reaper.CountSelectedTracks(0) 
    if track_count > 0 then  -- Set Table as tracks
        for i = 0, track_count-1 do 
            local track = reaper.GetSelectedTrack(0, i)
            dest_table[i+1] = track
        end
        dest_folder = false -- for the GUI
    else -- Set Table Parent
        dest_table[1] = "Folder"
        dest_folder = true -- for the GUI
    end 
end
--------------------------------
--------------------------------GUI FUNC:
--------------------------------
function NumDest() 
    local string = ''
    for k, track_loop in pairs(dest_table) do 
        local number = math.floor(reaper.GetMediaTrackInfo_Value( track_loop, 'IP_TRACKNUMBER' ))
        if k == 1 then string = number else string = string..', '..number end
    end
    return string
end

function ToolTip(text)
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_BeginTooltip(ctx)
        reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 35.0)
        reaper.ImGui_Text(ctx, text)
        reaper.ImGui_PopTextWrapPos(ctx)
        reaper.ImGui_EndTooltip(ctx)
    end
end

function GuiLoop()
    if reaper.ImGui_IsCloseRequested(ctx) then
        is_on = "OFF"
        reaper.JS_WindowMessage_ReleaseAll()
        reaper.ImGui_DestroyContext(ctx)
        return
    end
    
    local window_flags = reaper.ImGui_WindowFlags_MenuBar() |
                     reaper.ImGui_WindowFlags_NoDecoration()
    reaper.ImGui_SetNextWindowPos(ctx, 0, 0)
    reaper.ImGui_SetNextWindowSize(ctx, reaper.ImGui_GetDisplaySize(ctx))
    reaper.ImGui_Begin(ctx, 'Window', nil, window_flags)


    --- GUI HERE

    if reaper.ImGui_BeginMenuBar(ctx) then
        if reaper.ImGui_BeginMenu(ctx, 'Mode') then
          if reaper.ImGui_MenuItem(ctx, 'DSL', nil, dsl_mode) then
            dsl_mode = true
          end
          ToolTip("DSL mode: Will Comp using\n RE Options.\n Will Comp Silence")
          if reaper.ImGui_MenuItem(ctx, 'embass',nil, not dsl_mode) then
            dsl_mode = false
          end
          ToolTip("embass mode: Will\n Comp Items only,\n not silence, not envelopes")
          reaper.ImGui_EndMenu(ctx)
        end
        

        if reaper.ImGui_BeginMenu(ctx, 'Embass Mode Options') then
            if reaper.ImGui_MenuItem(ctx, 'Trim Behind', nil, _trim_behind) then
                _trim_behind = not _trim_behind
            end
          reaper.ImGui_EndMenu(ctx)
        end
        reaper.ImGui_EndMenuBar(ctx)
    end

    ---------------- SOURCE BUTTON
    if reaper.ImGui_Button(ctx, ' Dest ') then
        SetDest()
    end
    ToolTip('Define Destination Tracks')

    if dest_folder then 
        dest_number = "Folder Track" 
    else -- User set some track
        dest_number = NumDest() 
    end 

    reaper.ImGui_SameLine(ctx)
    _, _ = reaper.ImGui_InputText(ctx, '', dest_number,reaper.ImGui_InputTextFlags_ReadOnly())
    ToolTip('Show Dest Tracks')
   
    -------------- Do It

    --SetColor(4)

    if reaper.ImGui_Button(ctx, is_on ,196,40) then
        if is_on == 'OFF' then
            -- Turn ON
            is_on = 'ON' 
            reaper.Main_OnCommand(42406, 0) -- Razor edit: Clear all areas
            main()
        else 
            -- Turn OFF
            is_on = 'OFF'
        end 
    end

    reaper.ImGui_End(ctx)
    reaper.defer(GuiLoop)
end



function init()
    if not reaper.APIExists("BR_EnvFind") then print("Required: sws_ReaScriptAPI"); return end
    if not reaper.APIExists("JS_Int") then print("Required: js_ReaScriptAPI."); return end
    if not reaper.APIExists("ImGui_End") then print("Required: ReaImGUI."); return end

    clear_area_sel()

    _trim_behind = true
    dsl_mode = true

    --SetDest()
    dest_table = {"Folder"}
    dest_folder = true
    is_on = 'OFF'

    ctx = reaper.ImGui_CreateContext('RE Comp '..script_version, 210, 98)
end


init()
GuiLoop()

--[[ reaper.atexit(function()

	reaper.JS_WindowMessage_ReleaseAll()
	--reaper.SetMouseModifier("MM_CTX_ARRANGE_RMOUSE", 0, before_mm)
end
) ]]
