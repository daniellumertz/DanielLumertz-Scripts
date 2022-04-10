-- @noindex
local info = debug.getinfo(1,'S')
ScriptPath = info.source:match[[^@?(.*[\/])[^\/]-$]]
os.execute('start "" '..ScriptPath..'multikey_bind.txt')