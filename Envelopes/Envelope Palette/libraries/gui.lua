-- @noindex

function push_theme()
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(),     8, 5)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowTitleAlign(),  0.5, 0.5)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(),       3, 4)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarRounding(), 0)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(),          0x2A2A2AF0)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PopupBg(),           0x2A2A2AF0)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(),            0xFFFFFF80)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(),           0x4242428A)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(),           0x181818FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(),     0x181818FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),            0x1C1C1CFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(),     0x2C2C2CFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),      0x3D3D3DFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(),     0x12BD994B)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(),      0x12BD999E)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Separator(),         0xFFFFFF81)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGrip(),        0x12BD9933)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGripHovered(), 0x12BD99AB)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGripActive(),  0x12BD99F2)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextSelectedBg(),    0x70C4C659)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(),         0x12BD99FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarBg(),          0x0D0D0D87)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrab(),        0xFFFFFF1C)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrabHovered(), 0xFFFFFF2E)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrabActive(),  0xFFFFFF32)    
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(),               0x12BD9959)
end

function pop_theme()
  reaper.ImGui_PopStyleVar(ctx, 4)
  reaper.ImGui_PopStyleColor(ctx, 18)
  reaper.ImGui_PopStyleColor(ctx, 4)
end

function tooltip_at_mouse(text)
  local mx, my = reaper.GetMousePosition()
  mx, my = reaper.ImGui_PointConvertNative(ctx, mx, my)
  reaper.ImGui_SetNextWindowPos(ctx, mx + 13, my + 10, reaper.ImGui_Cond_Always())
  reaper.ImGui_BeginTooltip(ctx)
  reaper.ImGui_Text(ctx, text)
  reaper.ImGui_EndTooltip(ctx)
end

function get_ctrl()
  return reaper.JS_Mouse_GetState(4) > 0 
end