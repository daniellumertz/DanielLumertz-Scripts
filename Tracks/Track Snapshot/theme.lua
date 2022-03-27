-- @noindex
function PushTheme()
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(),          0x333333FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PopupBg(),           0x141414FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(),           0x1F1F1FFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(),    0x1F1F1FFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(),     0x1F1F1FFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(),     0x303030FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(),         0xE0E0E0FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),            0x42FAD266)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(),     0x42FAD28D)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),      0x42FAD2BC)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(),            0xFFFFFF31)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(),     0xFFFFFF5F)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(),      0xFFFFFF8E)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGrip(),        0xFFFFFF45)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGripHovered(), 0xFFFFFF6A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGripActive(),  0xFFFFFFAB)
end


function PopTheme()
    reaper.ImGui_PopStyleColor(ctx, 16)
end



