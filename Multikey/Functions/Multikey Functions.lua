-- @noindex
function init()
	-- Determine the view of the most recently focused window
	-- TODO: Update this. Can it be done better, or does it just 
	-- need a more exhaustice list?
	local lf_str = reaper.JS_Window_GetTitle(LastFocused)

	if lf_str == 'trackview' then
		CmdList = Bindings.main
	elseif lf_str:find('midi') then
		CmdList = Bindings.midi
	else
		CmdList = Bindings.main
	end

	-- get current intercept level, nullify it, then -1
	-- Without this major breakages can occur due to sub -1 lvls
	local intercept_level = reaper.JS_VKeys_Intercept(-1, 0)
	reaper.JS_VKeys_Intercept(-1, -intercept_level)
	reaper.JS_VKeys_Intercept(-1, 1)

	-- Read files
	--load_settings() Robert Settings, make my own
	load_keybindings()

	-- Remove modifiers from Cmd
	local mods = {'shift%-', 'ctrl%-', 'alt%-', 'meta%-'}
	for i, mod in ipairs(mods) do
		Cmd = Cmd:gsub(mod, '')
	end
end

-- XXX: This will generate a default settings File once that functionality
-- exists. 
function restore_default_settings()
	File = io.open(ScriptPath .. '../settings.conf', 'w')
	for k, b in pairs(Settings) do
		File:write(k .. '=' .. tostring(b) .. '\n')
	end
	File:close()
end

-- Creates an empty config File for the key in case there isn't one
function create_empty_keybindings_file(bind_path)
	local new_file_text = 
	[[--Syntax
--context: keys order with space = commands list
--Syntax exemple
--main: A B C F1 = 4004 4005
--You can execute multiple actions
--If your action have mod keys put them in this order SHIFT CTRL ALT. Exemples : 
--main: SHIFT A B = 4005
--main: SHIFT CTRL ALT A C = _SWSSNAPSHOT_OPEN 4005
--To check all possible keys and key_codes check Functions/General Functions at the KeyCodeList function. Try to put keys names as in the function. All in Uppper case.  

--Script: Edit Multikey Shortcut.lua
main: A A A  = _RS806f0627d49b5fce8d63d0299e9910fc4f24ce48
--Add a track
main: a b c  = 40001]]
	File = io.open(bind_path, 'w')
	File:write(new_file_text)
	File:close()
end


-- Load settings
function load_settings()
	local File = io.open(ScriptPath .. '../settings.conf', 'r')
	if File == nil then
		restore_default_settings()
		File = io.open(ScriptPath .. '../settings.conf', 'r')
	end
	for line in File:lines() do
		key_start, key_end = line:find('=')
		key = line:sub(1, key_start-1)
		val = line:sub(key_end+1)

		Settings[key] = convert_var(val)
		Settings.default_timeout = Settings.timeout
	end
end

-- This function loads the conf File of whatever key triggered the script
function load_keybindings()
	--local File = io.open(ScriptPath .. '../bindings/' .. Cmd .. '-Multikey-Bindings.conf', 'r') -- OG
	local bind_path = ScriptPath..'multikey_bind.txt'
	File = io.open(bind_path, 'r')
	if File == nil then
		create_empty_keybindings_file(bind_path)
		File = io.open(bind_path, 'r')
	end

	for line in File:lines() do
		-- Stop the loop upon EOF
		if line == nil then break end 
		-- Ignore lines with spaces
		if line:match('%s+')==line then goto pass end
		-- Ignore comments (--)
		if line:sub(1, 2) == '--' or line:sub(1, 1) == '' then goto pass end
		-- Get the target for the command (main, midi, media, etc)
		local target = line:sub(1, line:find(' ') - 1)
		line = line:gsub(target .. '%s+', '') -- remove target from line
		-- Get the key for the action and load them into 'cmds'
		local char_separetor = '=' -- char that divide key and actions
		local key = line:gsub('%s+'..char_separetor,char_separetor) -- the correct is like in 'A T= 40001' but this will make 'A T    = 40001' also correct
		key = key:gsub('%s+',' ') -- This makes all multiple space just one space
		key = key:sub(1, key:find(char_separetor) - 1) -- just key part
		key = key:upper() -- Make it upper case


		local cmds = line:match(char_separetor..'%s+'..'(.+)')
		local temp_cmds = {}
		-- Parse the commands and put them into a temp table to be inserted
		-- into the target's list
		for c in cmds:gmatch('[^%s]+') do 
			table.insert(temp_cmds, c)
		end

		if target == 'all:' then
			table.insert(Bindings.main, {key, {temp_cmds}})
			table.insert(Bindings.midi, {key, {temp_cmds}})
		elseif target == 'main:' then
			table.insert(Bindings.main, {key, {temp_cmds}})
		elseif target == 'midi:' then
			table.insert(Bindings.midi, {key, {temp_cmds}})
		end
		-- Used for comments
		::pass::
	end
	File:close()
end

function execute_commands(cmds)
	reaper.PreventUIRefresh(1)
	for i, c in ipairs(cmds[2]) do
		local midi = false

		for i, Cmd in ipairs(c) do
			-- Determine the target (for now just ME or main)
			if Cmd:sub(1, 1) == 'm' then
				midi = true
				Cmd = Cmd:sub(2)
			end

			-- Determine if it's an SWS/Custom Action
			-- If so, perform lookup
			if Cmd:sub(1, 1) == '_' then
				Cmd = reaper.NamedCommandLookup(Cmd)
			end

			if midi then
				reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), Cmd)
			else
				reaper.Main_OnCommand(Cmd, 0)
			end
		end
	end
	reaper.PreventUIRefresh(-1)
end


-- Remove commands that are no longer possible
-- return true if there cannot be more keystrokes
function check_cmds(Cmd)

	for i, v in ipairs(CmdList) do
		if not is_in_start_str(Cmd, v[1]) then remove(i, CmdList) end
	end
	-- Set the base Stamina to the longest seq of keys
	Stamina = find_longest_seq(CmdList)
	local cmd_len = 1
	for command in Cmd:gmatch('%s') do -- Count Spaces in Cmd (that equals the number of key pressed)
		cmd_len = cmd_len + 1
	end

	if cmd_len == Stamina or Stamina == 0 then
		return true
	else
		return false
	end
end 

-- Looks for the longest string of chars possible to determine
function find_longest_seq(CmdList)
	local longest = 0
	for i, Comand_table in pairs(CmdList) do
		local command_string = Comand_table[1]
		local cnt = 1
		for key in string.gmatch(command_string, '%s+') do
			cnt = cnt +1 
		end

		if cnt > longest then 
			longest = cnt 
		end
	end
	return longest
end



function debug()
	-- Remaining possibilities
	local remaining = ''
	for i, c in ipairs(CmdList) do
		remaining = remaining .. '\n\t\t' .. c[1] 
	end

	-- --+--+--+--+--+--+--+--+--+--+--
	-- Debugging
	-- --+--+--+--+--+--+--+--+--+--+--
	msg = 'Last Focus=\t' .. reaper.JS_Window_GetTitle(LastFocused)
	msg = msg .. '\nTimeout=\t' .. Settings.timeout
	msg = msg .. '\nStamina=\t' .. Stamina
	msg = msg .. '\nExhausted=\t' .. tostring(exhausted)
	msg = msg .. '\nReset on key=\t' .. tostring(Settings.extend_time_onkey)
	msg = msg .. '\nExecuted Cmd=\t' .. Cmd
	msg = msg .. '\nTime Lapse=\t' .. current_time - StartTime
	msg = msg .. '\nRemaining=' .. remaining
	msg = msg .. '\n'
	log(msg)
end

-- Restore intercept lvl and last focused window
function onexit() 
	reaper.JS_VKeys_Intercept(-1, -1) 
	reaper.JS_Window_SetFocus(LastFocused)
	if Settings.debug then 
		debug()
	end

end


