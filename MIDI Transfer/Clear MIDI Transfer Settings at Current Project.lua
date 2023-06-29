--@noindex
info = debug.getinfo(1,'S')
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]] -- this script folder
dofile(script_path .. 'General Functions.lua') -- General Functions needed

local is_clean = reaper.ShowMessageBox('Are you sure you want to remove MIDI Transfer settings from focused project?', 'MIDI Transfer Cleaner', 4)
if is_clean == 6 then
    reaper.SetProjExtState( 0, 'MTr', 'Map', '')
    reaper.SetProjExtState( 0, 'MTr', 'Page', '')
end