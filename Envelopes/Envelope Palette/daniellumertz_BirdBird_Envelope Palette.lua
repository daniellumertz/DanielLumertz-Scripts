-- @description Envelope Palette
-- @version 0.9.0
-- @author BirdBird
-- @provides
--    [nomain]libraries/functions.lua
--    [nomain]libraries/drawing.lua
--    [nomain]libraries/envelopes.lua
--    [nomain]libraries/gui_main.lua
--    [nomain]libraries/gui.lua
--    [nomain]libraries/mouse.lua
--@changelog
--  + Add support for take envelopes.

function p(msg) reaper.ShowConsoleMsg(tostring(msg) .. '\n') end
function reaper_do_file(file) local info = debug.getinfo(1,'S'); path = info.source:match[[^@?(.*[\/])[^\/]-$]]; dofile(path .. file); end
reaper_do_file('libraries/functions.lua')
if not reaper.APIExists('CF_GetSWSVersion') then
  local text = 'Envelope Palette requires the SWS Extension to run, however it is unable to find it. \nWould you like to be redirected to the SWS Extension website to install it?'
  local ret = reaper.ShowMessageBox(text, 'Error - Missing Dependency', 4)
  if ret == 6 then
    open_url('https://www.sws-extension.org/')
  end
  return
end
if not reaper.APIExists('ImGui_GetVersion') then
  local text = 'Envelope Palette requires the ReaImGui extension to run. You can install it through ReaPack.'
  local ret = reaper.ShowMessageBox(text, 'Error - Missing Dependency', 0)
  return
end
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.6')
if not reaper.APIExists('JS_ReaScriptAPI_Version') then
  local text = 'Envelope Palette requires the js_ReaScriptAPI extension to run. You can install it through ReaPack.'
  local ret = reaper.ShowMessageBox(text, 'Error - Missing Dependency', 0)
  return
end
reaper_do_file('libraries/envelopes.lua')
reaper_do_file('libraries/mouse.lua')
reaper_do_file('libraries/drawing.lua')
reaper_do_file('libraries/gui.lua')
reaper_do_file('libraries/gui_main.lua')

ctx = reaper.ImGui_CreateContext('Envelope Palette')
flt_min, flt_max = reaper.ImGui_NumericLimits_Float()
local font = reaper.ImGui_CreateFont('sans-serif', 12)
reaper.ImGui_AttachFont(ctx, font)
function handle_errors(err)
  reaper.ShowConsoleMsg(err .. '\n' .. debug.traceback())
  release_mouse()
end

local show_style_editor = false
if show_style_editor then 
  demo = dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/ReaImGui_Demo.lua')
end

function loop()
  reaper.ImGui_PushFont(ctx, font)
  push_theme()
  if show_style_editor then         
    demo.PushStyle(ctx)
    demo.ShowDemoWindow(ctx)
  end
  reaper.ImGui_SetNextWindowSize(ctx, 175, 217, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, 'Envelope Palette - DL mod', true)
  if visible then
    frame()
    reaper.ImGui_End(ctx)
  end
  if show_style_editor then
    demo.PopStyle(ctx)
  end
  pop_theme()
  reaper.ImGui_PopFont(ctx)
  
  if open then
    reaper.defer(function() xpcall(loop, handle_errors) end)
  else
    reaper.ImGui_DestroyContext(ctx)
  end
end

reaper.atexit(release_mouse)
xpcall(loop, handle_errors)