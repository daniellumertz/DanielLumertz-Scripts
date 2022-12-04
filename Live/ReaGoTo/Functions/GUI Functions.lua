-- @noindex
function GuiInit(ScriptName)
    ctx = reaper.ImGui_CreateContext(ScriptName, reaper.ImGui_ConfigFlags_DockingEnable()) -- Add VERSION TODO
    --- Text Font
    FontText = reaper.ImGui_CreateFont('sans-serif', 14) -- Create the fonts you need
    reaper.ImGui_Attach(ctx, FontText)-- Attach the fonts you need
    --- Smaller Font for smaller widgets
    FontTiny = reaper.ImGui_CreateFont('sans-serif', 10) 
    reaper.ImGui_Attach(ctx, FontTiny)
end
