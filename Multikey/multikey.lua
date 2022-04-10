-- @version 1.1
-- @author Lemerchand, Daniel Lumertz
-- @provides
--    [main] Edit Multikey Shortcut.lua
--    [nomain] Functions/*.lua
--    [nomain] multikey_bind.txt
-- @changelog
--    + One bind file
--    + One script
--    + New Keys to be used 
--    + New Syntax
--    + New functions and code organization



local info = debug.getinfo(1,'S')
ScriptPath = info.source:match[[^@?(.*[\/])[^\/]-$]]

dofile(ScriptPath..'/Functions/General Functions.lua')
dofile(ScriptPath..'/Functions/Multikey Functions.lua')


Settings = {
	debug = false,
	default_timeout = .850, --??
	timeout = .850,
	extend_time_onkey = true
}

-- Collect dbg info from around the script for dbg function
local dbg_msg = {}

-- Retrieve the time in which the script was invoked
-- This will allow the timeout variable to terminate
-- the script.
StartTime = reaper.time_precise()

-- Stamina refers to how many potential keystrokes are left
-- eg., if you have pressed 3 keys and the longest binding is 3 char
-- long, there is no point in waiting any longer
Stamina = 0

-- Figure out the window it was called from
-- Useful for re-enabling it's focus at script termination
LastFocused = reaper.JS_Window_GetFocus()

-- This is the key the user pressed to invoke the script
local keys_table = get_char_group()
Cmd = ''
for k, key_code in pairs(keys_table) do
	if k > 1 then
		Cmd = Cmd..' '..GetKeyName(key_code)
	else
		Cmd = GetKeyName(key_code)
	end
end
LastCharGroup = keys_table
LastChar = Cmd

-- The bindings list will hold all of the bindings for various
-- targets, eg, allowing the user to trigger main commands in the ME
Bindings = {main = {}, midi = {}}

-- This will hold remaining potential bindings, ruling out those
-- that are no longer possible
CmdList = {}




-- -- -- -- -- -- -- -- -- -- --
-- MAIN PROGRAM
-- -- -- -- -- -- -- -- -- -- --


init()

function main()
	-- mod
	local keys_table = get_char_group()

	-- Don't allow repeating of chars due to keys being held
	if #keys_table < 1 then
		LastCharGroup = {}
	elseif not TablesHaveElementInCommon(keys_table,LastCharGroup)  then -- Change to check if the tables have at least one element in common
		for k, key_code in pairs(keys_table) do
			local key_name = GetKeyName(key_code)
			if not key_name then  -- Invalid Keys not defined
				print('key invalid please report!\nKey Code is = '..key_code) 
				reaper.atexit(onexit) 
				return 
			end
			Cmd = Cmd..' '..key_name
		end
		
		LastCharGroup = keys_table
		if Settings.extend_time_onkey then
			StartTime = reaper.time_precise()
		end
	end

	-- Check which cmds can be removed
	-- Also see if there can be anymore presses
	local exhausted = check_cmds(Cmd)

	-- Get the time again, check if it's met the timeout threshold
	current_time = reaper.time_precise()
	if (current_time - Settings.timeout >= StartTime) or exhausted then
		-- At timeout or exhaustion, run the commands for the select keystroke
		for i, c in ipairs(CmdList) do
			if c[1] == Cmd then
				execute_commands(c)
			end
		end

		reaper.atexit(onexit)
		return
	else
		reaper.defer(main)
	end
end

main()
