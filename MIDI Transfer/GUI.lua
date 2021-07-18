-- @noindex
------------------
------------------
-----LOAD BASIC
------------------
------------------

    loadfile(script_path .. "Core.lua")()

    GUI.req("Classes/Class - Label.lua")()
    GUI.req("Classes/Class - Menubox.lua")()
    GUI.req("Classes/Class - Button.lua")()
    GUI.req("Classes/Class - Textbox.lua")()
    GUI.req("Classes/Class - TextEditor.lua")()
    GUI.req("Classes/Class - Options.lua")()
    GUI.req("Classes/Class - Menubar.lua")()
    -- If any of the requested libraries weren't found, abort the script.
    if missing_lib then return 0 end

    GUI.name = "MIDI Transfer v."..script_version
    GUI.x, GUI.y, GUI.w, GUI.h = 0, 0, 300, 750
    GUI.anchor, GUI.corner = "mouse", "C"


------------------
------------------
-----LOAD OBJECTS
------------------
------------------
------------------Fonts and Colors 
    gap = 13
    unit = 33
    GUI.fonts['font1'] = {"Calibri", 16}
    GUI.fonts['font2'] = {"Calibri", 22}
    GUI.colors['ye'] = {255,223,91,255}
    GUI.colors['claro'] = {255, 255, 255, 255}
    GUI.colors['cianinho'] = {0, 209, 232, 255}

    fonttxt = 'font1'
    cor1 = 'ye'
    cor2 = 'elm_fill'
    cornum = 'elm_fill'
    cortxto = 'txt'

    corbtn = 'elm_frame'
    corbtntxt = 'txt'
    fontebtn = 'font2' 
-----------------
-----------------Menubox Font(Source)

    GUI.New("Font_box", "Menubox", {
        z = 2,
        x = gap,
        y = 25+gap+2,
        w = 94,
        h = unit,
        opts = {'1', 'Remove Source' , 'Add Source Item'},
        caption	= '',
        noarrow = false
    })

    if #map > 1 then 
        for i = 2, #map do
            table.insert(GUI.elms.Font_box.opts, i , i)
        end
    end

    if page then GUI.Val('Font_box', tonumber(page)) end

    function GUI.elms.Font_box:onmousedown()
        GUI.Menubox.onmousedown(self)
        lastval = GUI.Val('Font_box')
    end

    function GUI.elms.Font_box:onmouseup()
        GUI.Menubox.onmouseup(self)
        local val = GUI.Val('Font_box')
        local max = #GUI.elms.Font_box.opts
        local val_num = GUI.elms.Font_box.opts[val]
        if val_num == 'Add Source Item' then -- ADD FONT PAGE
            if defer ~= true then --just let add if it is not running
                table.insert(GUI.elms.Font_box.opts, max-1 , max-1)
                GUI.Val('Font_box', max-1)
                ----Creates the font : 
                map[max-1] = CreateMap()
                UpdatesAllConfigs(max-1)
            else 
                GUI.Val('Font_box', lastval)
                reaper.ShowMessageBox('Stop the Transfer before adding a new Source Page', 'MIDI Transfer', 0)
            end

        elseif val_num == 'Remove Source' then -- REMOVE FONT ITEM
            if max > 3  then
                if defer ~= true then --just let remove if it is not running
                    for idx = GUI.elms.Font_box.opts[lastval], max-2 do-- For renaming the Values on the table Renames also the one that will be deleted but nobody gives a shit about him
                        GUI.elms.Font_box.opts[idx] = GUI.elms.Font_box.opts[idx] - 1 
                    end
                    table.remove(GUI.elms.Font_box.opts, lastval)
                    RemoveMap(lastval)
                    if lastval ~= 1 then 
                        GUI.Val('Font_box', lastval-1)
                        UpdatesAllConfigs(lastval-1)
                    else
                        GUI.Val('Font_box', 1)
                        UpdatesAllConfigs(1)
                    end
                else 
                    GUI.Val('Font_box', lastval)
                    reaper.ShowMessageBox('Stop the Transfer before removing a Source Page', 'MIDI Transfer', 0)
                end
            else
                reaper.ShowMessageBox('You Can\'t delete all sources.' , 'MIDI Transfer' , 0)
                GUI.Val('Font_box', 1)
            end
        else ---CHANGE THE FONT PAGE
            UpdatesAllConfigs(val)
        end        
    end
-----------------
-----------------MENU at the top
    --Functions
        mnu_file = {}
        mnu_file.new = function ()Msg('Place Holder') end
        mnu_file.delout = function ()  --  Options > Auto Delete > Delete Outside Track
            if GUI.elms.Bar.menus[1].options[2][1] == '!'..gui_opts_menu[1] then 
                GUI.elms.Bar.menus[1].options[2][1] = gui_opts_menu[1] 
                map[GUI.Val('Font_box')].delete_outside_track = 0 
            else
                GUI.elms.Bar.menus[1].options[2][1] = '!'..gui_opts_menu[1] 
                map[GUI.Val('Font_box')].delete_outside_track = 1
            end
        end

        mnu_file.odd_tr = function ()  --  Options > Auto Delete > Delete Outside Track > Auto Delete Odds on Choosen Tracks
            if GUI.elms.Bar.menus[1].options[4][1] == '!'..gui_opts_menu[2] then 
                GUI.elms.Bar.menus[1].options[4][1] = gui_opts_menu[2] 
                map[GUI.Val('Font_box')].auto_delete_odd = 0 
            else
                GUI.elms.Bar.menus[1].options[4][1] = '!'..gui_opts_menu[2] 
                map[GUI.Val('Font_box')].auto_delete_odd = 1

                if map[GUI.Val('Font_box')].auto_delete_odds_project == 1 then  -- Turn Off project Odds
                    GUI.elms.Bar.menus[1].options[5][1] = gui_opts_menu[3] 
                    map[GUI.Val('Font_box')].auto_delete_odds_project = 0 
                end
            end
        end

        mnu_file.odd_proj = function ()  --  Options > Auto Delete > Delete Outside Track > Auto Delete Odds on Choosen Tracks
            if GUI.elms.Bar.menus[1].options[5][1] == '!'..gui_opts_menu[3] then 
                GUI.elms.Bar.menus[1].options[5][1] = gui_opts_menu[3] 
                map[GUI.Val('Font_box')].auto_delete_odds_project = 0 
            else
                GUI.elms.Bar.menus[1].options[5][1] = '!'..gui_opts_menu[3] 
                map[GUI.Val('Font_box')].auto_delete_odds_project = 1

                if map[GUI.Val('Font_box')].auto_delete_odd == 1 then -- Turn Off tracks Odds
                    GUI.elms.Bar.menus[1].options[4][1] = gui_opts_menu[2] 
                    map[GUI.Val('Font_box')].auto_delete_odd = 0 
                end
            end
        end

        mnu_file.cc = function ()  --  Options > Auto Delete > Delete Outside Track > Auto Delete Odds on Choosen Tracks
            if GUI.elms.Bar.menus[1].options[6][1] == '!'..gui_opts_menu[4]  then 
                GUI.elms.Bar.menus[1].options[6][1] = gui_opts_menu[4] 
                map[GUI.Val('Font_box')].impCC = 0 
            else
                GUI.elms.Bar.menus[1].options[6][1] = '!'..gui_opts_menu[4] 
                map[GUI.Val('Font_box')].impCC = 1
            end
        end

        mnu_file.reset = function()
            if defer ~= true then 
                map = {} 
                map[1] = CreateMap() 
                GUI.Val('Font_box', 1 )
                
                while #GUI.elms.Font_box.opts ~= 3 
                do
                    table.remove(GUI.elms.Font_box.opts, #GUI.elms.Font_box.opts-2)
                end
                
                UpdatesAllConfigs(GUI.Val('Font_box'))
            else
                reaper.ShowMessageBox('Stop the Transfer Before Reseting !!!', 'MIDI Transfer', 0)
            end
        end

        mnu_file.manual = function()
            open_url('https://docs.google.com/document/d/1b0z6HQJBL4x7614b0SngNarXH__VO_ExzrAoxpOOoAI/edit?usp=sharing')
        end

        mnu_file.forum = function()
            open_url('https://forum.cockos.com/showthread.php?p=2395944&fbclid=IwAR0SmqwDCE6g5RjEFBsFbuhCOR8dUPep06KUpX99V2io24ybKA2DUEXrjoc#post2395944')
        end

        mnu_file.video = function()
            open_url('https://youtu.be/oaZSoyqpcoA')
        end

        mnu_file.donate = function()
            open_url('https://www.paypal.com/donate/?hosted_button_id=RWA58GZTYMZ3N')
        end
    --
    gui_opts_menu = {'Delete Outside Track' , 'Auto Delete Odds on Choosen Tracks', '<Auto Delete Odds on Project', 'Transfer CC'}
    -- You can add more Options In the Options tab just add at the end not at  the start please! 
    GUI.New('Bar','Menubar',{
        z = 1,
        x = 0,
        y = 0,
        w = GUI.w, 
        h = 25,
        menus = {           
            {title = 'Options', options = {
                {'>Auto Delete'},
                    {gui_opts_menu[1], mnu_file.delout},
                    {''},
                    {gui_opts_menu[2],mnu_file.odd_tr},
                    {gui_opts_menu[3], mnu_file.odd_proj},
                    --{'<', mnu_file.keep_running  }, -- In case you find some bug remove < on gui_opts_menu and add that line.
                {gui_opts_menu[4],  mnu_file.cc },
                {"Reset",mnu_file.reset}

                }},
            {title = "Help", options = {
                {"Forum",mnu_file.forum},
                {"Video",mnu_file.video},
                {"Manual",mnu_file.manual},
                {"Donate!",mnu_file.donate},
            }}
        }
    })
    
   
-----------------
-----------------Font Name Display
    GUI.New("font_display", "Textbox", {
        z = 2,
        x = GUI.elms.Font_box.x + GUI.elms.Font_box.w + gap,
        y = GUI.elms.Font_box.y,
        w = 166,
        h = unit,
        caption	= ''
    })

    function GUI.elms.font_display:onmousedown()
        GUI.elms.font_display.focus = false
        local Ctrl = GUI.mouse.cap&4==4
        local Shift = GUI.mouse.cap&8==8
        local Alt = GUI.mouse.cap&16==16
        if Ctrl == true and Shift == false then -- Selects font CTRL
            if Alt == false then
                SelectFontItem(GUI.Val('Font_box')) 
            else
                SelectAllFontItems(false) -- All fonts
            end
        end
        if Ctrl == false and Shift == true then -- Selects Items Shift
            if Alt == false then 
                SelectTRItems(GUI.Val('Font_box'), false) -- false to do the selection 
            else
                SelectAllTRItems(false) -- Select all items
            end
        end
        if Ctrl == true and Shift == true then  -- Selects everything 
            if Alt == false then 
                SelectFontandTR(GUI.Val('Font_box'))
            else
                SelectAll() -- Across maps
            end
        end
    end

    
-----------------
-----------------TextEditor
    GUI.New("map_editor", "TextEditor", {
        z = 2,
        x = gap,
        y = (GUI.elms.Font_box.y+GUI.elms.Font_box.h) + gap,
        w = GUI.w-(2*gap),
        h = 350,
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

    t_tracks = {{nil}}
    auto_update = true

    --Amagalma Mods:
    function GUI.TextEditor:drawtext()
        GUI.font(self.font_b)
        local digits = #tostring(#self.retval)
        self.digits = digits > 2 and digits or 2
        self.textpad = gfx.measurestr(string.rep("0", digits))
        self.pad = 6 + self.textpad
        local tmp = {}
        local numbers = {}
        local n = 0
        for i = self.wnd_pos.y, math.min(self:wnd_bottom() - 1, #self.retval) do
        n = n + 1
        local str = tostring(self.retval[i]) or ""
        tmp[n] = string.sub(str, self.wnd_pos.x + 1, self:wnd_right() - 1 - digits)
        numbers[n] = string.format("%" .. digits .. "i", i-1) -- I put -1 To start at
        end
        GUI.color(cornum)
        gfx.x, gfx.y = self.x + self.pad - self.textpad, self.y + self.pad
        gfx.drawstr(table.concat(numbers, "\n"))
        GUI.color(self.color)
        gfx.x, gfx.y = self.x + self.pad, self.y + self.pad
        gfx.drawstr( table.concat(tmp, "\n") )
    end
    function GUI.TextEditor:getcaret(x, y)
        local tmp = {}
        tmp.x = math.floor(((x - self.textpad - self.x) / self.w ) * self.wnd_w) + self.wnd_pos.x
        tmp.y = math.floor((y - (self.y + self.pad)) /  self.char_h) + self.wnd_pos.y
        tmp.y = GUI.clamp(1, tmp.y, #self.retval)
        tmp.x = GUI.clamp(0, tmp.x, #(self.retval[tmp.y] or ""))
        return tmp
    end 
    --Actions
    function update_tracks_n(object)
        t_write_trnum = {} 
        for line, line_tab in pairs(t_tracks) do
            for k, track in pairs(line_tab) do -- loop table lines
                if track ~= '' then
                    if reaper.ValidatePtr(track, 'MediaTrack*') == true then-- Checks if track exist
                        num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER' ) 
                        num = math.floor(num)
                        if not t_write_trnum[line] then 
                            t_write_trnum[line] = ' '..tostring(num)
                        else
                            t_write_trnum[line] = t_write_trnum[line]..' , '..tostring(num)
                        end
                    else
                    -- If track is deleted
                        if not t_write_trnum[line] then 
                            t_write_trnum[line] = ' ? '
                        else
                            t_write_trnum[line] = t_write_trnum[line]..' , '..' ? '
                        end
                    end
                else
                    t_write_trnum[line] = ''
                end
            end 
        end
        GUI.Val(object, t_write_trnum)
    end

    function GUI.elms.map_editor:lostfocus()
        GUI.TextEditor.lostfocus(self)
        t_tracks = {}
        for line, values_inline in pairs(GUI.elms.map_editor.retval) do
            t_tracks[line] = {}
            if values_inline ~= '' and string.find(values_inline, "^%s+$") == nil and  string.find(values_inline, "[^%d,%s?]") == nil and string.find(values_inline, "[%d]") ~= nil then
                i = 1
                for track_idx in string.gmatch(values_inline, "%d+") do -- Filter for numbers and loop them
                    track_idx = tonumber(track_idx)
                    local count = reaper.CountTracks(0)
                    if track_idx > reaper.CountTracks(0) then track_idx = count end
                    if track_idx == 0 then track_idx = 1 end
                    local tr = reaper.GetTrack(0, track_idx-1)
                    t_tracks[line][i] = tr
                    i = i + 1
                end 
            else
                t_tracks[line][1] = '' -- Lines not commented, or only with spaces, or with characters that are not commas or numbers
            end
        end
        SetMapTracks(GUI.Val('Font_box'), t_tracks)
    end

    function GUI.elms.map_editor:onmousedown()
        GUI.TextEditor.onmousedown(self)
        if reaper.CountTracks(0) > 0 then 
            local Ctrl = GUI.mouse.cap&4==4
            if Ctrl then 
                local track_count = reaper.CountSelectedTracks(0)
                if track_count > 0 then 
                    GUI.elms.map_editor.focus = false
                    t_tracks = {}
                    t_tracks[1] = {''}
                    for i = 1, track_count do 
                        local track = reaper.GetSelectedTrack(0, i-1)
                        t_tracks[i+1] = {track}
                    end
                    SetMapTracks(GUI.Val('Font_box'), t_tracks)
                end
            end
        else
            GUI.elms.map_editor.focus = false
            reaper.ShowMessageBox('Add Some Track to the Project First!', 'MIDI Transfer', 0)
        end
    end
   


-----------------
-----------------Options
    --Keep Cuts
        GUI.New("keep_cuts", "Checklist", {
            z = 2,
            x = gap,
            y = (GUI.elms.map_editor.y+GUI.elms.map_editor.h) + gap, 
            w = 34,
            h = 34,
            opt_size = 34,
            caption = "",
            opts  = {'Keep\nCuts'},
            col_txt = cortxto,
            font_b = fonttxt,
            frame  = false,
            col_fill = cor1
        })

        function GUI.elms.keep_cuts:onmouseup()
            GUI.Checklist.onmouseup(self)
            SetMapInfo(GUI.Val('Font_box'), 'pref_keep_cuts', 'keep_cuts')
        end
        
    --
    --Color
        GUI.New("color", "Checklist", {
            z = 2,
            x = gap,
            y = (GUI.elms.keep_cuts.y+GUI.elms.keep_cuts.h) + gap, 
            w = 34,
            h = 34,
            opt_size = 34,
            caption = "",
            opts  = {'Color\nItems'},
            col_txt = cortxto,
            font_b = fonttxt,
            frame  = false,
            col_fill = cor1
        })

        function GUI.elms.color:onmouseup()
            local Ctrl = GUI.mouse.cap&4==4
            if Ctrl == false then -- Normal option
                GUI.Checklist.onmouseup(self)
                SetMapInfo(GUI.Val('Font_box'), 'color_item', 'color')
            else -- Select color 
                retval, color = reaper.GR_SelectColor( 'hwnd' )
                if retval ~= 0 then
                    local r, g, b = reaper.ColorFromNative( color )
                    map[GUI.Val('Font_box')].color = reaper.ColorToNative(r, g, b)|0x1000000
                end
            end
        end

        function GUI.elms.color:onmouser_up() -- Random color 
            GUI.Checklist.onmouser_up(self)
            local r = math.random( 0, 255 )
            local g = math.random( 0, 255 )
            local b = math.random( 0, 255 )
            map[GUI.Val('Font_box')].color = reaper.ColorToNative(r, g, b)|0x1000000
        end

    --
    --Update on Start
        GUI.New("update_on_start", "Checklist", {
            z = 2,
            x = gap,
            y = (GUI.elms.color.y+GUI.elms.color.h) + gap, 
            w = 34,
            h = 34,
            opt_size = 34,
            caption = "",
            opts  = {'Update\non Start'},
            col_txt = cortxto,
            font_b = fonttxt,
            frame  = false,
            col_fill = cor1
        })

        function GUI.elms.update_on_start:onmouseup()
            GUI.Checklist.onmouseup(self)
            SetMapInfo(GUI.Val('Font_box'), 'update_on_start', 'update_on_start')
        end

    --
    --Items Offline
        GUI.New("items_offline", "Checklist", {
            z = 2,
            x = gap,
            y = (GUI.elms.update_on_start.y+GUI.elms.update_on_start.h) + gap, 
            w = 34,
            h = 34,
            opt_size = 34,
            caption = "",
            opts  = {'Items\nOffline'},
            col_txt = cortxto,
            font_b = fonttxt,
            frame  = false,
            col_fill = cor2
        })
        local is_off = reaper.SNM_GetIntConfigVar('offlineinact', 5)
        local is_off = num_to_bool(is_off)
        GUI.Val("items_offline", is_off)
        --
        function GUI.elms.items_offline:onmouseup()
            GUI.Checklist.onmouseup(self)
            local valor = GUI.Val("items_offline")
            local valor = bool_to_number(valor)
            reaper.SNM_SetIntConfigVar('offlineinact', valor)
        end
    ---
    --Midi Souce
        GUI.New("midi_source", "Checklist", {
            z = 2,
            x = gap,
            y = (GUI.elms.items_offline.y+GUI.elms.items_offline.h) + gap, 
            w = 34,
            h = 34,
            opt_size = 34,
            caption = "",
            opts  = {'MIDI\nSource'},
            col_txt = cortxto,
            font_b = fonttxt,
            frame  = false,
            col_fill = cor2
        })
        local is_ref = reaper.SNM_GetIntConfigVar('opencopyprompt', 5)
        is_ref = toBits(is_ref)
        is_ref = num_to_bool(is_ref[4])
        GUI.Val("midi_source", is_ref)

        function GUI.elms.midi_source:onmouseup()
            GUI.Checklist.onmouseup(self)
            local valor = GUI.Val("midi_source")
            local valor = bool_to_number(valor)
            local is_ref = reaper.SNM_GetIntConfigVar('opencopyprompt', 5)
            is_ref = toBits(is_ref)
            is_ref[4] = valor
            local new_val = BitTabtoStr2(is_ref, 10)
            reaper.SNM_SetIntConfigVar('opencopyprompt', tonumber(new_val, 2))
        end 
    ---
    --Ch/Tracks MODE
        GUI.New("mode", "Radio", {
            z = 2,
            x = (GUI.elms.keep_cuts.x + GUI.elms.keep_cuts.w) +55+ gap,
            y = (GUI.elms.map_editor.y+GUI.elms.map_editor.h) + gap, 
            w = 135,
            h = 50,
            opt_size = 40,
            caption = "",
            opts  = {'','_',''},
            col_txt = cortxto,
            font_b = fonttxt,
            frame  = false,
            dir = 'h',
            col_fill = cor1
        })

        function GUI.elms.mode:onmouseup()
            GUI.Radio.onmouseup(self)
            SetMapInfo(GUI.Val('Font_box'), 'track_order', 'mode')
        end

        GUI.New("midi_ch", "Label", {
            z = 2,
            x = GUI.elms.mode.x+GUI.elms.mode.opt_size+10,
            y = GUI.elms.mode.y+10, 
            caption = 'MIDI\nCH' ,
            font = fonttxt , 
            color = cortxto  ,
            shadow = true           
        })

        GUI.New("midi_track", "Label", {
            z = 2,
            x = GUI.elms.mode.x+GUI.elms.mode.opt_size*3+20,
            y = GUI.elms.mode.y+10, 
            caption = 'MIDI\nTrack' ,
            font = fonttxt , 
            color = cortxto ,
            shadow = true        
        })

    --
-----------------
-----------------Buttons
    --Font
        function btn_funca()
            if reaper.CountSelectedMediaItems(0) > 0 then
                local val = GUI.Val('Font_box')
                map[val] = SetFonts(map[val])
                UpdateDisplay(GUI.Val('Font_box'))
            else
                reaper.ShowMessageBox('Select an MIDI Item', 'MIDI Transfer', 0)
            end
        end

        GUI.New("Font", "Button", {
            z = 2,
            x = GUI.elms.mode.x+gap-5,
            y = GUI.elms.color.y+10,
            w = 160,
            h = (unit*2)+10,
            caption = "Source",
            col_fill = corbtn,
            col_txt  = corbtntxt,
            font     = fontebtn ,   
            func = btn_funca
        })
    --
    --Delete
        function del_act()
            local Ctrl = GUI.mouse.cap&4==4
            local Shift = GUI.mouse.cap&8==8
            local Alt = GUI.mouse.cap&16==16

            if Ctrl == false and Shift == false then --Not 
                if Alt == false then 
                    DelItems(GUI.Val('Font_box'),true) 
                else
                    DelAllItems() 
                end
            end

            if Ctrl == true and Shift == false  then -- Ctrl
                DelAnyItems(i)
            end

            if Ctrl == false and Shift == true then -- Shift
                if Alt == false then 
                    DeleteOddAllTracksManual(GUI.Val('Font_box'))
                else
                    DeleteOddAllTracksAllManual()
                end
            end
        end

        GUI.New('Delete', "Button", {
            z = 2,
            x = GUI.elms.Font.x,
            y = GUI.elms.items_offline.y+4,
            w = GUI.elms.Font.w,
            h = (unit*2)+11,
            caption = "Delete",
            col_fill = "elm_frame",
            col_fill = corbtn,
            col_txt  = corbtntxt,
            font     = fontebtn,   
            func = del_act
        })
    --
    --OnOff
        GUI.New('onoff', "Button", {
            z = 2,
            x = gap,
            y = (GUI.elms.midi_source.y + GUI.elms.midi_source.w) + gap +5 ,
            w = GUI.w-(2*gap),
            h = unit+10,
            caption = "Start",
            col_fill = "elm_frame",
            col_fill = corbtn,
            col_txt  = corbtntxt,
            font     = {"Calibri", 26} ,  
        })
        

        function GUI.elms.onoff:onmouseup()
            GUI.Button.onmouseup(self)
            local Ctrl = GUI.mouse.cap&4==4
            if Ctrl == false then 
                if GUI.elms.onoff.caption == "Start" then -- Start Transfer
                    if ValidateStart() == true then
                        GUI.elms.onoff.caption = "Stop"
                        defer = true
                        main_tr()
                    end
                else 
                    defer = false
                    GUI.elms.onoff.caption = "Start"-- Stop Transfer
                end
            else -- Executes just one time
                if ValidateStart() == true then
                    if GUI.elms.onoff.caption == "Start" then 
                        defer = false
                        manual_up = true
                        main_tr()
                    else -- If execute on running
                        manual_up = true
                    end
                end
            end
        end
    --


------------------
------------------
-----GUI ACTIONS
------------------
------------------

    function ChangeFont(i)
        GUI.Val('Font_box', i)
        UpdatesAllConfigs(max-1)
    end

    function RemoveFont()
        --Func to delete font n and font with n higher get an -1
    end

    function onup()
        if auto_update == true then
            if GUI.elms.map_editor.focus == false then
                update_tracks_n('map_editor')
            end
        end
    end

    function UpdatesAllConfigs(i)
        UpdateDisplay(i)
        UpdateMenuConfig(i)
        UpdateTxtEditor(i)
        UpdateConfig(i,'pref_keep_cuts','keep_cuts')
        UpdateConfig(i,'color_item','color')
        UpdateConfig(i,'update_on_start','update_on_start')
        UpdateConfig(i,'track_order','mode')
    end

----INIT

---Updates to MAP1 
UpdatesAllConfigs(GUI.Val('Font_box'))

----

GUI.func = onup
GUI.freq = 0.1
GUI.Init()
GUI.Main()