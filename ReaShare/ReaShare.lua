-- @version 0.1.4
-- @author Daniel Lumertz
-- @provides
--    [nomain] Modules/*.lua
--    [nomain] Classes/*.lua
--    [nomain] utils/*.lua
--    [nomain] Arrange Functions.lua
--    [nomain] Chunk Functions.lua
--    [nomain] Core.lua
--    [nomain] General Lua Functions.lua
--    [nomain] JSON Functions.lua
--    [nomain] ReaShare Functions.lua
--    [main] ReaShare Change Temporary Path.lua
--    [main] ReaShare Copy Items.lua
--    [main] ReaShare Copy Project.lua
--    [main] ReaShare Copy Tracks.lua
--    [main] ReaShare Paste From Clipboard.lua
-- @changelog
--    + Check for valid path when setting a path
--    + Change Reashere Functions to ReaShare (Case sensitive)

--dofile("C:/Users/DSL/AppData/Roaming/REAPER/Scripts/Meus/Debug VS/DL Debug.lua")


local info = debug.getinfo(1,'S')
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]] -- this script folder

dofile(script_path..'General Lua Functions.lua')
dofile(script_path..'Arrange Functions.lua')
dofile(script_path..'Chunk Functions.lua')
dofile(script_path..'ReaShare Functions.lua')
dofile(script_path .. 'Core.lua') --Lokasenna GUI s2
dofile(script_path .. 'JSON Functions.lua') 


--GUI.req("Classes/Class - Label.lua")()
--GUI.req("Classes/Class - Menubox.lua")()
GUI.req("Classes/Class - Button.lua")()
--GUI.req("Classes/Class - Textbox.lua")()
GUI.req("Classes/Class - TextEditor.lua")()
--GUI.req("Classes/Class - Options.lua")()
--GUI.req("Classes/Class - Menubar.lua")()
-- If any of the requested libraries weren't found, abort the script.
if missing_lib then return 0 end

local script_name = 'ReaShare'
local script_v = '0.1.4'
--- GUI WINDOW BASIC
GUI.name = script_name..' '..script_v
GUI.x, GUI.y, GUI.w, GUI.h = 0, 0, 200, 400
GUI.anchor, GUI.corner = "mouse", "C"


--- UI BASIC
local x_lines = 8
local linex_h = GUI.h / x_lines
local gap = 13
local y_lines = 3
local y_lines_w = (GUI.w / y_lines)

--- Elements

--- Chunk TEXT
GUI.New("chunk_txt", "TextEditor", {
    z = 1,
    x = gap,
    y = (linex_h*1)+gap/2,
    w = GUI.w-(gap*2),
    h = (linex_h*5)-gap,
    caption = "",
    font_a = 'font1',
    font_b = 'font1',
    color = "txt",
    col_fill = "elm_fill",
    cap_bg = "wnd_bg",
    bg = "elm_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20,
})


-- Get Proj Chunk btn
function BtnGetProj()
    local chunk = GetProjectChunk(0,script_path..'temp file get project chunk.txt')
    if chunk then
        GUI.Val("chunk_txt", chunk)
    end
end


GUI.New("get_project", "Button", {
    z = 1,
    x = gap,
    y = gap,
    w = y_lines_w-gap,
    h = (linex_h*1)-gap,
    caption = "Project",
    col_fill = corbtn,
    col_txt  = corbtntxt,
    font     = fontebtn ,   
    func = BtnGetProj
})


-- Get Track Chunk btn
function BtnGetTracks()
    local chunk = GetSelectedTracksChunks()
    if chunk then
        GUI.Val("chunk_txt", chunk)
    end
end


GUI.New("get_tracks", "Button", {
    z = 1,
    x = y_lines_w + gap/2,
    y = gap,
    w = y_lines_w-gap,
    h = (linex_h*1)-gap,
    caption = "Tracks",
    col_fill = corbtn,
    col_txt  = corbtntxt,
    font     = fontebtn ,   
    func = BtnGetTracks
})


-- Get Item Chunk btn

function BtnGetItems()
    local chunk = GetSelectedItemsChunk()
    if chunk then
        GUI.Val("chunk_txt", chunk)
    end
end


GUI.New("get_items", "Button", {
    z = 1,
    x = (y_lines_w*2),
    y = gap,
    w = y_lines_w-gap,
    h = (linex_h*1)-gap,
    caption = "Items",
    col_fill = corbtn,
    col_txt  = corbtntxt,
    font     = fontebtn ,   
    func = BtnGetItems
})


-- Copy to clipboard btn
function BtnCopy()
    if not CheckRequirements() then return end -- Check if there is sws
    local chunk = GUI.Val("chunk_txt")
    if chunk then
        reaper.CF_SetClipboard(chunk)
    end
end

GUI.New("clipboard", "Button", {
    z = 1,
    x = gap,
    y = (linex_h*6),
    w = GUI.w-(gap*2),
    h = (linex_h*1)-gap,
    caption = "Copy To Clipboard",
    col_fill = corbtn,
    col_txt  = corbtntxt,
    font     = fontebtn ,   
    func = BtnCopy
})

-- Paste btn
function BtnPaste()
    local pasted_chunk = GUI.Val("chunk_txt")
    ReaSharePaste(pasted_chunk, script_path)
end

GUI.New("paste", "Button", {
    z = 1,
    x = gap,
    y = (linex_h*7)-gap/2,
    w = GUI.w-(gap*2),
    h = (linex_h*1)-gap,
    caption = "Paste!!!",
    col_fill = corbtn,
    col_txt  = corbtntxt,
    font     = fontebtn ,   
    func = BtnPaste
})

-- Do it
GUI.Init()
GUI.Main()

