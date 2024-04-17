-- @noindex
function ReaShareErrorChunk()
    reaper.ShowMessageBox('This Is Not A Valid Chunk!', 'ReaShare', 0)    
end

---Create a new file with the content written in it.
---@param path string complete file path should contain file name and extension 
---@param content string what is inside this file
function CreateNewProjectFile(path,content)
	content = content:gsub('\r\n','\n')
	local f = io.open(path, "w")
	if not f then
		print('Invalid Temporary Path for Projects')
		print('Set a new one with the following action: Script: ReaShare Change Temporary Path.lua')
	end
	f:write(content)
	f:close()
end 


function GetSelectedItemsChunk()
	local chunk = ''
	for item in enumSelectedItems() do 
		local retval, item_chunk = reaper.GetItemStateChunk(item, '', false)
		chunk = chunk..item_chunk
	end

	if chunk == '' then
		local msg = {"You did not selected Items","You did not selected Items","Select some item please!","You did not selected Items","Heyo select some Items pls!","OHHHHHH\nYou forgeted to select the items!!!11!!!","How is your day?\nMine would be better if you selected some items"}
		reaper.ShowMessageBox(msg[math.random(#msg)], 'ReaShare' , 0)
		return false
	end

	return chunk	
end

function GetSelectedTracksChunks()
	local chunk = ''
	for track in enumSelectedTracks() do 
		local retval, track_chunk = reaper.GetTrackStateChunk(track, '', true)
		chunk = chunk..track_chunk
	end

	if chunk == '' then
		local msg = {"You did not selected Tracks","You did not selected Tracks","Select some Tracks please!","You did not selected Tracks","Heyo select some Tracks pls!","OHHHHHH\nYou forgeted to select the Tracks!!!11!!!","How is your day?\nMine would be better if you selected some Tracks","DUDE WHERE IS MY TRACK?\nPlease Select some tracks!"}
		reaper.ShowMessageBox(msg[math.random(#msg)], 'ReaShare' , 0)
		return false
	end

	return chunk	
end

---Create Items using a Chunk Sequence
---@param pasted_chunk string Items Chunks
---@param item_pattern string Pattern That start Item Chunks
function PasteItems(pasted_chunk,item_pattern)

	pasted_chunk = '\n'..pasted_chunk..'\n'..item_pattern -- To put first and last chunk in a pattern.
    local last_touched_track = reaper.GetLastTouchedTrack()
    local insert_idx
    if last_touched_track then
        insert_idx = reaper.GetMediaTrackInfo_Value(last_touched_track, 'IP_TRACKNUMBER') -1
    else
        insert_idx = reaper.CountTracks(0) 
		reaper.InsertTrackAtIndex(insert_idx, true)
    end
    -- Get the earliest Item Chunk using <Position
    local smallest_pos = math.huge
    for item_chunk in SubString(pasted_chunk,'\n(<ITEM.-)\n<ITEM') do
        local pos = GetChunkVal(item_chunk,'POSITION')
        smallest_pos = math.min(tonumber(pos),smallest_pos)
    end

    local paste_time  =  reaper.GetCursorPosition() 
    local insert_track = reaper.GetTrack(0, insert_idx)
	if not insert_track then

	end

    for item_chunk in SubString(pasted_chunk,'\n(<ITEM.-)\n<ITEM') do
        CreateMediaItemWithChunk(item_chunk, insert_track, paste_time, smallest_pos )
    end

end

---Create Tracks using a Chunk Sequence
---@param pasted_chunk string Tracks Chunks
---@param track_pattern string Pattern That start Tracks Chunks
function  PasteTracks(pasted_chunk,track_pattern)
	pasted_chunk = '\n'..pasted_chunk..'\n'..track_pattern -- To put first and last chunk in a pattern.
    local last_touched_track = reaper.GetLastTouchedTrack()
    local insert_idx
    if last_touched_track then
        insert_idx = reaper.GetMediaTrackInfo_Value(last_touched_track, 'IP_TRACKNUMBER') 
    else
        insert_idx = reaper.CountTracks(0) 
    end

    for track_chunk in SubString(pasted_chunk,'\n(<TRACK.-)\n<TRACK') do
        CreateTrackWithChunk(track_chunk,insert_idx,true)
        insert_idx = insert_idx + 1 
    end
end

---Create Project using a Chunk
---@param pasted_chunk string Project Chunk
---@param script_path string path where will create a temp .rpp file
function  CreateProject(pasted_chunk,script_path)
	--If there is no path to save the temp file!
	local save_path
	if not file_exists(script_path.. "/" .. 'settings' .. ".json") then 
		local retval
		local try = true
		while try do
			retval, save_path = reaper.GetUserInputs('ReaShare', 1, 'Path to save temp File', '')
			if not retval then return end -- User pressed cancel.
			save_path = save_path..'/' -- need to end with this

			-- check if valid path
			local test_file = save_path..'ReaShare_TestPath.txt'
			local f = io.open(test_file, "w")
			if f then
				try = false
				f:close()
				os.remove(test_file)
			else 
				print('Invalid Path!')
				print('Try Again')
			end
		end
		save_json(script_path,'settings',{save_path = save_path})
	else
		local settings_table = load_json(script_path, 'settings')
		save_path = settings_table.save_path
	end
	local temp_file = save_path..'temp project to load.rpp'
    CreateNewProjectFile(temp_file,pasted_chunk)
    reaper.Main_openProject( temp_file ) -- opens a project. will prompt the user to save unless name is prefixed with 'noprompt:'.
    os.remove(temp_file)
end

-- @noindex
function ReaSharePaste(pasted_chunk, script_path)
	local item_pattern = '<ITEM'
	local track_pattern = '<TRACK'
	local proj_pattern = '<REAPER_PROJECT'

	local valid = false -- boolean if it haves a valid chunk
	if pasted_chunk:match('^'..track_pattern) or  pasted_chunk:match('^'..item_pattern) or pasted_chunk:match('^'..proj_pattern)  then -- See if t
		reaper.Undo_BeginBlock()
		reaper.PreventUIRefresh(1)
		valid = true
	else
		ReaShareErrorChunk()
	end

	if pasted_chunk:match('^'..track_pattern) then -- it is a valid ReaShare Chunk
		PasteTracks(pasted_chunk,track_pattern)
	elseif pasted_chunk:match('^'..item_pattern) then
		PasteItems(pasted_chunk,item_pattern)
	elseif pasted_chunk:match('^'..proj_pattern) then
		CreateProject(pasted_chunk,script_path)
	end

	if valid then
		reaper.PreventUIRefresh(-1)
		reaper.UpdateArrange()
		reaper.Undo_EndBlock2(0, 'ReaShare Paste', -1)
	end
end

function CheckRequirements()
    local wind_name = 'ReaShare'

    if  not reaper.APIExists('CF_GetSWSVersion') then
        reaper.ShowMessageBox('Please Install SWS at www.sws-extension.org', wind_name, 0)
        return false
    end

    return true 
end