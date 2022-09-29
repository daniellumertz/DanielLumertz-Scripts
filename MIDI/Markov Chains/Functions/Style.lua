--@noindex

function PushGeneralStyle()
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(),    8, 11)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(),   7)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(),      8, 5)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemInnerSpacing(), 4, 7)


    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(),         0x272727FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(),          0x72FFD73A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(),   0x72FFD777)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(),    0x72FFD7BD)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(),          0x40947CBB)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(),    0x4DAC91F4)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgCollapsed(), 0x000000CF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_MenuBarBg(),        0x171717FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(),        0x72FFD79C)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),           0x72FFD757)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(),    0x72FFD789)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),     0x72FFD7B9)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(),           0x47F8DE4C)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(),    0x47F8DE62)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(),     0x47F8DEA2)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Separator(),        0xCCF7FF80)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(),       0x1D7D62FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(), 0x31CFA2FF)
end

function PopGeneralStyle()
    reaper.ImGui_PopStyleVar(ctx, 4)
    reaper.ImGui_PopStyleColor(ctx, 18)
end





