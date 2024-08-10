-- @noindex

local main_window = reaper.GetMainHwnd()
local arrange_window = reaper.JS_Window_FindChildByID(main_window, 0x3E8)
local intercepts = { 
  'WM_LBUTTONDOWN',
  'WM_LBUTTONDBLCLK',
  'WM_SETCURSOR' 
}

local intercept_count = 0
function intercept_mouse()
  for i = 1, #intercepts do
    reaper.JS_WindowMessage_Intercept(arrange_window, intercepts[i], false)
  end
  intercept_count = intercept_count + 1
end

function release_mouse()
  for i = 1, #intercepts do
    reaper.JS_WindowMessage_Release(arrange_window, intercepts[i])
  end
  intercept_count = intercept_count - 1
end

function set_draw_cursor()
  local cur = reaper.JS_Mouse_LoadCursor(433)
  reaper.JS_Mouse_SetCursor(cur)
end