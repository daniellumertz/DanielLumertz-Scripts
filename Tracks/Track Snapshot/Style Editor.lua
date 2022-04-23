-- @noindex
-- Needed variables 
r = reaper
local StyleEditor = true

local StyleEditor_demo = {
    open = true,
  
    menu = {
      enabled = true,
      f = 0.5,
      n = 0,
      b = true,
    },
  
    -- Window flags (accessible from the "Configuration" section)
    no_titlebar       = false,
    no_scrollbar      = false,
    no_menu           = false,
    no_move           = false,
    no_resize         = false,
    no_collapse       = false,
    no_close          = false,
    no_nav            = false,
    no_background     = false,
    -- no_bring_to_front = false,
    unsaved_document  = false,
    no_docking        = false,
  }

local StyleEditor_app     = {}
local StyleEditor_cache = {}

-- High level functions for user
function PushStyle()
    custom_style = StyleEditor_app.style_editor ~= nil

    if custom_style then
      for i, value in pairs(StyleEditor_app.style_editor.style.vars) do
        if type(value) == 'table' then
          r.ImGui_PushStyleVar(ctx, i, table.unpack(value))
        else
          r.ImGui_PushStyleVar(ctx, i, value)
        end
      end
      for i, value in pairs(StyleEditor_app.style_editor.style.colors) do
        r.ImGui_PushStyleColor(ctx, i, value)
      end
    end   
end

function PopStyle()
    if custom_style then
        r.ImGui_PopStyleColor(ctx, #StyleEditor_cache['Col'])
        r.ImGui_PopStyleVar(ctx, #StyleEditor_cache['StyleVar'])
    end
end

function StyleLoop()
    if StyleEditor then
        rv, StyleEditor = r.ImGui_Begin(ctx, 'Dear ImGui Style Editor', true)
        if rv then
            ShowStyleEditorBody()
            r.ImGui_End(ctx)
        end
    end
end

--- Style Editor Functions Copied
function StyleEditor_demo.GetStyleData()
    local data = { vars={}, colors={} }
    local vec2 = {
      'ButtonTextAlign', 'SelectableTextAlign', 'CellPadding', 'ItemSpacing',
      'ItemInnerSpacing', 'FramePadding', 'WindowPadding', 'WindowMinSize',
      'WindowTitleAlign',
    }
  
    for i, name in StyleEditor_demo.EachEnum('StyleVar') do
      local rv = {r.ImGui_GetStyleVar(ctx, i)}
      local is_vec2 = false
      for _, vec2_name in ipairs(vec2) do
        if vec2_name == name then
          is_vec2 = true
          break
        end
      end
      data.vars[i] = is_vec2 and rv or rv[1]
    end
    for i in StyleEditor_demo.EachEnum('Col') do
      data.colors[i] = r.ImGui_GetStyleColor(ctx, i)
    end
    return data
end

function StyleEditor_demo.CopyStyleData(source, target)
    for i, value in pairs(source.vars) do
      if type(value) == 'table' then
        target.vars[i] = {table.unpack(value)}
      else
        target.vars[i] = value
      end
    end
    for i, value in pairs(source.colors) do
      target.colors[i] = value
    end
end


function ShowStyleEditorBody()
    local rv
    if not StyleEditor_app.style_editor then
      StyleEditor_app.style_editor = {
        style  = StyleEditor_demo.GetStyleData(),
        ref    = StyleEditor_demo.GetStyleData(),
        output_dest = 0,
        output_only_modified = true,
      }
    end
  
    r.ImGui_PushItemWidth(ctx, r.ImGui_GetWindowWidth(ctx) * 0.50)
  
  --     if (r.ImGui_ShowStyleSelector("Colors##Selector"))
  --         ref_saved_style = style;
  --     r.ImGui_ShowFontSelector("Fonts##Selector");
  
    -- Simplified Settings (expose floating-pointer border sizes as boolean representing 0.0 or 1.0)
    local FrameRounding, GrabRounding = r.ImGui_StyleVar_FrameRounding(),
                                        r.ImGui_StyleVar_GrabRounding()
    rv,StyleEditor_app.style_editor.style.vars[FrameRounding] = r.ImGui_SliderDouble(ctx, 'FrameRounding', StyleEditor_app.style_editor.style.vars[FrameRounding], 0.0, 12.0, '%.0f')
    if rv then
      StyleEditor_app.style_editor.style.vars[GrabRounding] = StyleEditor_app.style_editor.style.vars[FrameRounding] -- Make GrabRounding always the same value as FrameRounding
    end
  
    local borders = { 'WindowBorder', 'FrameBorder', 'PopupBorder' }
    for i, name in ipairs(borders) do
      local var = r[('ImGui_StyleVar_%sSize'):format(name)]()
      local enable = StyleEditor_app.style_editor.style.vars[var] > 0
      if i > 1 then r.ImGui_SameLine(ctx) end
      rv, enable = r.ImGui_Checkbox(ctx, name, enable)
      if rv then StyleEditor_app.style_editor.style.vars[var] = enable and 1 or 0 end
    end
  
    -- Save/Revert button
    if r.ImGui_Button(ctx, 'Save Ref') then
      StyleEditor_demo.CopyStyleData(StyleEditor_app.style_editor.style, StyleEditor_app.style_editor.ref)
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, 'Revert Ref') then
      StyleEditor_demo.CopyStyleData(StyleEditor_app.style_editor.ref, StyleEditor_app.style_editor.style)
    end
    r.ImGui_SameLine(ctx)
    StyleEditor_demo.HelpMarker(
      'Save/Revert in local non-persistent storage. Default Colors definition are not affected. \z
       Use "Export" below to save them somewhere.')
  
    local export = function(enumName, funcSuffix, curTable, refTable, isEqual, formatValue)
      local lines, name_maxlen = {}, 0
      for i, name in StyleEditor_demo.EachEnum(enumName) do
        if not StyleEditor_app.style_editor.output_only_modified or not isEqual(curTable[i], refTable[i]) then
          table.insert(lines, { name, curTable[i] })
          name_maxlen = math.max(name_maxlen, name:len())
        end
      end
  
      if StyleEditor_app.style_editor.output_dest == 0 then
        r.ImGui_LogToClipboard(ctx)
      else
        r.ImGui_LogToTTY(ctx)
      end
      for _, line in ipairs(lines) do
        local pad = string.rep('\x20', name_maxlen - line[1]:len())
        r.ImGui_LogText(ctx, ('reaper.ImGui_Push%s(ctx, reaper.ImGui_%s_%s(),%s %s)\n')
          :format(funcSuffix, enumName, line[1], pad, formatValue(line[2])))
      end
      if #lines == 1 then
        r.ImGui_LogText(ctx, ('\nreaper.ImGui_Pop%s(ctx)\n'):format(funcSuffix))
      elseif #lines > 1 then
        r.ImGui_LogText(ctx, ('\nreaper.ImGui_Pop%s(ctx, %d)\n'):format(funcSuffix, #lines))
      end
      r.ImGui_LogFinish(ctx)
    end
  
    if r.ImGui_Button(ctx, 'Export Vars') then
      export('StyleVar', 'StyleVar', StyleEditor_app.style_editor.style.vars, StyleEditor_app.style_editor.ref.vars,
        function(a, b) if type(a) == 'table' then return a[1] == b[1] and a[2] == b[2] else return a == b end end,
        function(val) if type(val) == 'table' then return ('%g, %g'):format(table.unpack(val)) else return ('%g'):format(val) end end)
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, 'Export Colors') then
      export('Col', 'StyleColor', StyleEditor_app.style_editor.style.colors, StyleEditor_app.style_editor.ref.colors,
        function(a, b) return a == b end, function(val) return ('0x%08X'):format(val & 0xffffffff) end)
    end
    r.ImGui_SameLine(ctx); r.ImGui_SetNextItemWidth(ctx, 120); rv,StyleEditor_app.style_editor.output_dest = r.ImGui_Combo(ctx, '##output_type', StyleEditor_app.style_editor.output_dest, 'To Clipboard\0To TTY\0')
    r.ImGui_SameLine(ctx); rv,StyleEditor_app.style_editor.output_only_modified = r.ImGui_Checkbox(ctx, 'Only Modified', StyleEditor_app.style_editor.output_only_modified)
  
    r.ImGui_Separator(ctx)
  
    if r.ImGui_BeginTabBar(ctx, '##tabs', r.ImGui_TabBarFlags_None()) then
      if r.ImGui_BeginTabItem(ctx, 'Sizes') then
        local slider = function(varname, min, max, format)
          local func = r['ImGui_StyleVar_' .. varname]
          assert(func, ('%s is not exposed as a StyleVar'):format(varname))
          local var = func()
          if type(StyleEditor_app.style_editor.style.vars[var]) == 'table' then
            local rv,val1,val2 = r.ImGui_SliderDouble2(ctx, varname, StyleEditor_app.style_editor.style.vars[var][1], StyleEditor_app.style_editor.style.vars[var][2], min, max, format)
            if rv then StyleEditor_app.style_editor.style.vars[var] = { val1, val2 } end
          else
            local rv,val = r.ImGui_SliderDouble(ctx, varname, StyleEditor_app.style_editor.style.vars[var], min, max, format)
            if rv then StyleEditor_app.style_editor.style.vars[var] = val end
          end
        end
  
        r.ImGui_Text(ctx, 'Main')
        slider('WindowPadding',     0.0, 20.0, '%.0f')
        slider('FramePadding',      0.0, 20.0, '%.0f')
        slider('CellPadding',       0.0, 20.0, '%.0f')
        slider('ItemSpacing',       0.0, 20.0, '%.0f')
        slider('ItemInnerSpacing',  0.0, 20.0, '%.0f')
        -- slider('TouchExtraPadding', 0.0, 10.0, '%.0f')
        slider('IndentSpacing',     0.0, 30.0, '%.0f')
        slider('ScrollbarSize',     1.0, 20.0, '%.0f')
        slider('GrabMinSize',       1.0, 20.0, '%.0f')
        r.ImGui_Text(ctx, 'Borders')
        slider('WindowBorderSize', 0.0, 1.0, '%.0f')
        slider('ChildBorderSize',  0.0, 1.0, '%.0f')
        slider('PopupBorderSize',  0.0, 1.0, '%.0f')
        slider('FrameBorderSize',  0.0, 1.0, '%.0f')
        -- slider('TabBorderSize',    0.0, 1.0, '%.0f')
        r.ImGui_Text(ctx, 'Rounding')
        slider('WindowRounding',    0.0, 12.0, '%.0f')
        slider('ChildRounding',     0.0, 12.0, '%.0f')
        slider('FrameRounding',     0.0, 12.0, '%.0f')
        slider('PopupRounding',     0.0, 12.0, '%.0f')
        slider('ScrollbarRounding', 0.0, 12.0, '%.0f')
        slider('GrabRounding',      0.0, 12.0, '%.0f')
        -- slider('LogSliderDeadzone', 0.0, 12.0, '%.0f')
        slider('TabRounding',       0.0, 12.0, '%.0f')
        r.ImGui_Text(ctx, 'Alignment')
        slider('WindowTitleAlign', 0.0, 1.0, '%.2f')
        -- int window_menu_button_position = StyleEditor_app.style_editor.style.WindowMenuButtonPosition + 1
        -- if (ctx, r.ImGui_Combo(ctx, 'WindowMenuButtonPosition', (ctx, int*)&window_menu_button_position, "None\0Left\0Right\0"))
        --     StyleEditor_app.style_editor.style.WindowMenuButtonPosition = window_menu_button_position - 1
        -- r.ImGui_Combo(ctx, 'ColorButtonPosition', (ctx, int*)&StyleEditor_app.style_editor.style.ColorButtonPosition, "Left\0Right\0")
        slider('ButtonTextAlign', 0.0, 1.0, '%.2f')
        r.ImGui_SameLine(ctx); StyleEditor_demo.HelpMarker('Alignment applies when a button is larger than its text content.')
        slider('SelectableTextAlign', 0.0, 1.0, '%.2f')
        r.ImGui_SameLine(ctx); StyleEditor_demo.HelpMarker('Alignment applies when a selectable is larger than its text content.')
        -- r.ImGui_Text(ctx, 'Safe Area Padding')
        -- r.ImGui_SameLine(ctx); StyleEditor_demo.HelpMarker('Adjust if you cannot see the edges of your screen (ctx, e.g. on a TV where scaling has not been configured).')
        -- slider('DisplaySafeAreaPadding', 0.0, 30.0, '%.0f')
        r.ImGui_EndTabItem(ctx)
      end
  
      if r.ImGui_BeginTabItem(ctx, 'Colors') then
        if not StyleEditor_app.style_editor.colors then
          StyleEditor_app.style_editor.colors = {
            filter = { inst=nil, text = '' },
            alpha_flags = r.ImGui_ColorEditFlags_None(),
          }
        end
        -- the filter object is destroyed once unused for one or more frames
        if not r.ImGui_ValidatePtr(StyleEditor_app.style_editor.colors.filter.inst, 'ImGui_TextFilter*') then
          StyleEditor_app.style_editor.colors.filter.inst = r.ImGui_CreateTextFilter(StyleEditor_app.style_editor.colors.filter.text)
        end
  
        if r.ImGui_TextFilter_Draw(StyleEditor_app.style_editor.colors.filter.inst, ctx, 'Filter colors', r.ImGui_GetFontSize(ctx) * 16) then
          StyleEditor_app.style_editor.colors.filter.text = r.ImGui_TextFilter_Get(StyleEditor_app.style_editor.colors.filter.inst)
        end
  
        if r.ImGui_RadioButton(ctx, 'Opaque', StyleEditor_app.style_editor.colors.alpha_flags == r.ImGui_ColorEditFlags_None()) then
          StyleEditor_app.style_editor.colors.alpha_flags = r.ImGui_ColorEditFlags_None()
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_RadioButton(ctx, 'Alpha',  StyleEditor_app.style_editor.colors.alpha_flags == r.ImGui_ColorEditFlags_AlphaPreview()) then
          StyleEditor_app.style_editor.colors.alpha_flags = r.ImGui_ColorEditFlags_AlphaPreview()
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_RadioButton(ctx, 'Both',   StyleEditor_app.style_editor.colors.alpha_flags == r.ImGui_ColorEditFlags_AlphaPreviewHalf()) then
          StyleEditor_app.style_editor.colors.alpha_flags = r.ImGui_ColorEditFlags_AlphaPreviewHalf()
        end
        r.ImGui_SameLine(ctx)
        StyleEditor_demo.HelpMarker(
          'In the color list:\n\z
           Left-click on color square to open color picker,\n\z
           Right-click to open edit options menu.')
  
        if r.ImGui_BeginChild(ctx, '##colors', 0, 0, true,
                              r.ImGui_WindowFlags_AlwaysVerticalScrollbar()   |
                              r.ImGui_WindowFlags_AlwaysHorizontalScrollbar() |
                           -- r.ImGui_WindowFlags_NavFlattened()) TODO: BETA/INTERNAL, not exposed yet
                              0) then
          r.ImGui_PushItemWidth(ctx, -160)
          local inner_spacing = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemInnerSpacing())
          for i, name in StyleEditor_demo.EachEnum('Col') do
            if r.ImGui_TextFilter_PassFilter(StyleEditor_app.style_editor.colors.filter.inst, name) then
              r.ImGui_PushID(ctx, i)
              rv, StyleEditor_app.style_editor.style.colors[i] = r.ImGui_ColorEdit4(ctx, '##color', StyleEditor_app.style_editor.style.colors[i], r.ImGui_ColorEditFlags_AlphaBar() | StyleEditor_app.style_editor.colors.alpha_flags)
              if StyleEditor_app.style_editor.style.colors[i] ~= StyleEditor_app.style_editor.ref.colors[i] then
                -- Tips: in a real user application, you may want to merge and use an icon font into the main font,
                -- so instead of "Save"/"Revert" you'd use icons!
                -- Read the FAQ and docs/FONTS.md about using icon fonts. It's really easy and super convenient!
                r.ImGui_SameLine(ctx, 0.0, inner_spacing)
                if r.ImGui_Button(ctx, 'Save') then
                  StyleEditor_app.style_editor.ref.colors[i] = StyleEditor_app.style_editor.style.colors[i]
                end
                r.ImGui_SameLine(ctx, 0.0, inner_spacing)
                if r.ImGui_Button(ctx, 'Revert') then
                  StyleEditor_app.style_editor.style.colors[i] = StyleEditor_app.style_editor.ref.colors[i]
                end
              end
              r.ImGui_SameLine(ctx, 0.0, inner_spacing)
              r.ImGui_Text(ctx, name)
              r.ImGui_PopID(ctx)
            end
          end
          r.ImGui_PopItemWidth(ctx)
          r.ImGui_EndChild(ctx)
        end
  
        r.ImGui_EndTabItem(ctx)
      end
  
  --         if (r.ImGui_BeginTabItem("Fonts"))
  --         {
  --             ImGuiIO& io = r.ImGui_GetIO();
  --             ImFontAtlas* atlas = io.Fonts;
  --             HelpMarker("Read FAQ and docs/FONTS.md for details on font loading.");
  --             r.ImGui_ShowFontAtlas(atlas);
  --
  --             // Post-baking font scaling. Note that this is NOT the nice way of scaling fonts, read below.
  --             // (we enforce hard clamping manually as by default DragFloat/SliderFloat allows CTRL+Click text to get out of bounds).
  --             const float MIN_SCALE = 0.3f;
  --             const float MAX_SCALE = 2.0f;
  --             HelpMarker(
  --                 "Those are old settings provided for convenience.\n"
  --                 "However, the _correct_ way of scaling your UI is currently to reload your font at the designed size, "
  --                 "rebuild the font atlas, and call StyleEditor_app.style_editor.style.ScaleAllSizes() on a reference ImGuiStyle structure.\n"
  --                 "Using those settings here will give you poor quality results.");
  --             static float window_scale = 1.0f;
  --             r.ImGui_PushItemWidth(r.ImGui_GetFontSize() * 8);
  --             if (r.ImGui_DragFloat("window scale", &window_scale, 0.005f, MIN_SCALE, MAX_SCALE, "%.2f", ImGuiSliderFlags_AlwaysClamp)) // Scale only this window
  --                 r.ImGui_SetWindowFontScale(window_scale);
  --             r.ImGui_DragFloat("global scale", &io.FontGlobalScale, 0.005f, MIN_SCALE, MAX_SCALE, "%.2f", ImGuiSliderFlags_AlwaysClamp); // Scale everything
  --             r.ImGui_PopItemWidth();
  --
  --             r.ImGui_EndTabItem();
  --         }
  --
      if r.ImGui_BeginTabItem(ctx, 'Rendering') then
  --             r.ImGui_Checkbox("Anti-aliased lines", &style.AntiAliasedLines);
  --             r.ImGui_SameLine();
  --             HelpMarker("When disabling anti-aliasing lines, you'll probably want to disable borders in your style as well.");
  --
  --             r.ImGui_Checkbox("Anti-aliased lines use texture", &style.AntiAliasedLinesUseTex);
  --             r.ImGui_SameLine();
  --             HelpMarker("Faster lines using texture data. Require backend to render with bilinear filtering (not point/nearest filtering).");
  --
  --             r.ImGui_Checkbox("Anti-aliased fill", &style.AntiAliasedFill);
        r.ImGui_PushItemWidth(ctx, r.ImGui_GetFontSize(ctx) * 8)
  --             r.ImGui_DragFloat("Curve Tessellation Tolerance", &style.CurveTessellationTol, 0.02f, 0.10f, 10.0f, "%.2f");
  --             if (style.CurveTessellationTol < 0.10f) style.CurveTessellationTol = 0.10f;
  --
  --             // When editing the "Circle Segment Max Error" value, draw a preview of its effect on auto-tessellated circles.
  --             r.ImGui_DragFloat("Circle Tessellation Max Error", &style.CircleTessellationMaxError , 0.005f, 0.10f, 5.0f, "%.2f", ImGuiSliderFlags_AlwaysClamp);
  --             if (r.ImGui_IsItemActive())
  --             {
  --                 r.ImGui_SetNextWindowPos(r.ImGui_GetCursorScreenPos());
  --                 r.ImGui_BeginTooltip();
  --                 r.ImGui_TextUnformatted("(R = radius, N = number of segments)");
  --                 r.ImGui_Spacing();
  --                 ImDrawList* draw_list = r.ImGui_GetWindowDrawList();
  --                 const float min_widget_width = r.ImGui_CalcTextSize("N: MMM\nR: MMM").x;
  --                 for (int n = 0; n < 8; n++)
  --                 {
  --                     const float RAD_MIN = 5.0f;
  --                     const float RAD_MAX = 70.0f;
  --                     const float rad = RAD_MIN + (RAD_MAX - RAD_MIN) * (float)n / (8.0f - 1.0f);
  --
  --                     r.ImGui_BeginGroup();
  --
  --                     r.ImGui_Text("R: %.f\nN: %d", rad, draw_list->_CalcCircleAutoSegmentCount(rad));
  --
  --                     const float canvas_width = IM_MAX(min_widget_width, rad * 2.0f);
  --                     const float offset_x     = floorf(canvas_width * 0.5f);
  --                     const float offset_y     = floorf(RAD_MAX);
  --
  --                     const ImVec2 p1 = r.ImGui_GetCursorScreenPos();
  --                     draw_list->AddCircle(ImVec2(p1.x + offset_x, p1.y + offset_y), rad, r.ImGui_GetColorU32(ImGuiCol_Text));
  --                     r.ImGui_Dummy(ImVec2(canvas_width, RAD_MAX * 2));
  --
  --                     /*
  --                     const ImVec2 p2 = r.ImGui_GetCursorScreenPos();
  --                     draw_list->AddCircleFilled(ImVec2(p2.x + offset_x, p2.y + offset_y), rad, r.ImGui_GetColorU32(ImGuiCol_Text));
  --                     r.ImGui_Dummy(ImVec2(canvas_width, RAD_MAX * 2));
  --                     */
  --
  --                     r.ImGui_EndGroup();
  --                     r.ImGui_SameLine();
  --                 }
  --                 r.ImGui_EndTooltip();
  --             }
  --             r.ImGui_SameLine();
  --             HelpMarker("When drawing circle primitives with \"num_segments == 0\" tesselation will be calculated automatically.");
  
        local Alpha, DisabledAlpha = r.ImGui_StyleVar_Alpha(), r.ImGui_StyleVar_DisabledAlpha()
        rv,StyleEditor_app.style_editor.style.vars[Alpha] = r.ImGui_DragDouble(ctx, 'Global Alpha', StyleEditor_app.style_editor.style.vars[Alpha], 0.005, 0.20, 1.0, '%.2f') -- Not exposing zero here so user doesn't "lose" the UI (zero alpha clips all widgets). But application code could have a toggle to switch between zero and non-zero.
        rv,StyleEditor_app.style_editor.style.vars[DisabledAlpha] = r.ImGui_DragDouble(ctx, 'Disabled Alpha', StyleEditor_app.style_editor.style.vars[DisabledAlpha], 0.005, 0.0, 1.0, '%.2f'); r.ImGui_SameLine(ctx); StyleEditor_demo.HelpMarker('Additional alpha multiplier for disabled items (multiply over current value of Alpha).')
        r.ImGui_PopItemWidth(ctx)
  
        r.ImGui_EndTabItem(ctx)
      end
  
      r.ImGui_EndTabBar(ctx)
    end
  
    r.ImGui_PopItemWidth(ctx)
  end

  function StyleEditor_demo.EachEnum(enum)
    local enum_cache = StyleEditor_cache[enum]
    if not enum_cache then
      enum_cache = {}
      StyleEditor_cache[enum] = enum_cache
  
      for func_name, func in pairs(reaper) do
        local enum_name = func_name:match(('^ImGui_%s_(.+)$'):format(enum))
        if enum_name then
          table.insert(enum_cache, { func(), enum_name })
        end
      end
      table.sort(enum_cache, function(a, b) return a[1] < b[1] end)
    end
  
    local i = 0
    return function()
      i = i + 1
      if not enum_cache[i] then return end
      return table.unpack(enum_cache[i])
    end
  end

  function StyleEditor_demo.HelpMarker(desc)
    r.ImGui_TextDisabled(ctx, '(?)')
    if r.ImGui_IsItemHovered(ctx) then
      r.ImGui_BeginTooltip(ctx)
      r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
      r.ImGui_Text(ctx, desc)
      r.ImGui_PopTextWrapPos(ctx)
      r.ImGui_EndTooltip(ctx)
    end
  end