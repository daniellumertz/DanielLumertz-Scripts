-- @version 1.0.3
-- @author Daniel Lumertz
-- @provides
--    [main=midi_editor] .
-- @changelog
--    + imgui update 0.8



-- Imgui shims to 0.7.2 (added after the news at 0.8)
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.7.2')

Version = '1.0.3'
function print(val)
    reaper.ShowConsoleMsg("\n"..tostring(val))    
end

function toBits(num) -- returns a table of bits, least significant first.
    local t={} 
    while num>0 do
        rest=math.fmod(num,2)
        t[#t+1]=math.floor(rest)
        num=(num-rest)/2
    end
    return t
end

function IsSelectionLinkEdit() -- return bol
    link = toBits(reaper.SNM_GetIntConfigVar('midieditor', 5))[10] -- Is Selection is linked to editability On? 0 Yes 1 No.
    if link == 0 then link = true elseif link == 1 then link = false end
    return link
end

function GetEditableMIDITakes(link) --  bool link - Is Selection linked to editability? //Return a take_table with the takes editable in piano roll 
    take_table ={}
    if link == true then -- Selection is linked to editability 
        local item_count = reaper.CountSelectedMediaItems(0)
        if item_count > 0 then -- If at least one item is MIDI
            for i = 0, item_count-1 do 
                local loop_item = reaper.GetSelectedMediaItem(0, i)
                local loop_take = reaper.GetMediaItemTake(loop_item, 0)
                local bol = reaper.TakeIsMIDI(loop_take)
                if bol == true then table.insert(take_table, loop_take) end
            end
        end
        if item_count == 0 or #take_table == 0 then  -- No selected Item or None was added to a table(none is MIDI)
            local midieditor = reaper.MIDIEditor_GetActive()
            local take = reaper.MIDIEditor_GetTake(midieditor)
            table.insert(take_table, take)
        end
        --print(#take_table)
    elseif link == false then -- Selection is NOT linked to editability 
        local midieditor = reaper.MIDIEditor_GetActive()
        local take = reaper.MIDIEditor_GetTake(midieditor)
        table.insert(take_table, take)
    end
    return take_table
end

-- Script Func
function PitchClassTable(take, pitch_table) -- Add To the pitch_table what it count on the take
    local retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
    for noteidx = 0, notecnt do
        local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, noteidx)
        if selected == true then
            pitch_table[pitch%12+1] = pitch_table[pitch%12+1]+1
        end
    end
    return pitch_table
end

function PitchClassCount() -- Reset pitch_table and count again return the new count
    local pitch_table = {0,0,0,0,0,0,0,0,0,0,0,0}
    local takes_table = GetEditableMIDITakes(link)
    for k,take in pairs(takes_table) do
        pitch_table = PitchClassTable(take, pitch_table)
    end
    return pitch_table
end

function PitchClassCountOLD() -- OLD Reset pitch_table and count again return the new count
    local pitch_table = {0,0,0,0,0,0,0,0,0,0,0,0}
    if link == true then -- Selection is linked to editability 
        local item_count = reaper.CountSelectedMediaItems(0)
        local bol = false -- To check if at least one items is MIDI
        for i = 0, item_count-1 do 
            local loop_item = reaper.GetSelectedMediaItem(0, i)
            local loop_take = reaper.GetMediaItemTake(loop_item, 0)
            bol = reaper.TakeIsMIDI(loop_take)
            if bol == true then break end
        end
        if item_count > 0 and bol == true then -- If at least one item is MIDI
            for i = 0, item_count-1 do 
                local loop_item = reaper.GetSelectedMediaItem(0, i)
                local loop_take = reaper.GetMediaItemTake(loop_item, 0)
                pitch_table = PitchClassTable(loop_take)
            end
        else -- No selected Item or None is MIDI
            local midieditor = reaper.MIDIEditor_GetActive()
            local take = reaper.MIDIEditor_GetTake(midieditor)
            pitch_table = PitchClassTable(take)
        end
    elseif link == false then -- Selection is NOT linked to editability 
        local midieditor = reaper.MIDIEditor_GetActive()
        local take = reaper.MIDIEditor_GetTake(midieditor)
        pitch_table = PitchClassTable(take)
    end
    return pitch_table
end

--- GUI Func
function ChangeColor(H,S,V,A)
    reaper.ImGui_PushID(ctx, 3)
    local button = HSV( H, S, V, A)
    local hover =  HSV( H, S , (V+0.4 < 1) and V+0.4 or 1 , A)
    local active = HSV( H, S, (V+0.2 < 1) and V+0.2 or 1 , A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),  button)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), hover)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  active)
end

function HSV(h, s, v, a)
    local r, g, b = reaper.ImGui_ColorConvertHSVtoRGB(h, s, v)
    return reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a or 1.0)
end

function GetBarsCenterX(width, num_bars) -- list x_values = GetBarsCenterX(width, num_bars).  x_values = each bar center x position FROM the START of the PLOT. width = width of the plot. num_bars = number of bars in the plot
    local plot_pad = 4
    local bar_area_w = width - ((num_bars-1) + (2 * plot_pad))
    local bar_w = bar_area_w / num_bars
    local list = {} -- List of X based on start of plot
    for i = 1, num_bars do
        if i == 1 then 
            list[1] = 4 + (bar_w/2)
        else
            list[i] =  list[i-1] + bar_w + 1 
        end
    end
    return list
end

--- GUI

ctx = reaper.ImGui_CreateContext('Pitch Class Counter')

local size = reaper.GetAppVersion():match('OSX') and 12 or 14
local font = reaper.ImGui_CreateFont('sans-serif', size) -- Create the fonts you need
reaper.ImGui_AttachFont(ctx, font)-- Attach the fonts you need

function GUI()
    -- Windowss Flags
    reaper.ImGui_SetNextWindowSize(ctx, 500, 185, reaper.ImGui_Cond_Once())-- Set the size of the windows.  Use in the 4th argument reaper.ImGui_Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2

    --Begin
    local visible, open = reaper.ImGui_Begin(ctx, 'Pitch Class Counter '..Version, true,    reaper.ImGui_WindowFlags_None()
                                                                            |  reaper.ImGui_WindowFlags_MenuBar()
                                                                            |  reaper.ImGui_WindowFlags_NoScrollbar())


    if  visible then
        -- Sizes
        local pad = 4
        local widh , highth = reaper.ImGui_GetContentRegionAvail( ctx)

        -- Actions
        if  is_on == true then 
            pitch_table = PitchClassCount()
        end
        --- GUI HERE
        local n_lines = 7

        if reaper.ImGui_BeginMenuBar(ctx) then
            if reaper.ImGui_BeginMenu(ctx, 'Options') then
                if reaper.ImGui_MenuItem(ctx, 'Show as #', nil, sharps) then
                    sharps = not sharps
                end
                if reaper.ImGui_MenuItem(ctx, 'Display Count at Plot', nil, show_count) then
                    show_count = not show_count
                end
                reaper.ImGui_EndMenu(ctx)
            end
            reaper.ImGui_EndMenuBar(ctx)
        end
        --------- Get MIDI button
        if is_on == true then 
            is_on_text = "ON" 
            ChangeColor(0.4,1,0.4,1)
        else
            is_on_text = "OFF"
            ChangeColor(0,1,0.4,1)
        end
        reaper.ImGui_Button(ctx, is_on_text, widh, highth/n_lines)
        if reaper.ImGui_IsItemClicked( ctx) then
            is_on = not is_on
        end
        reaper.ImGui_PopStyleColor(ctx, 3); reaper.ImGui_PopID(ctx)
        ---- Histogram
        local pitch_n_array = reaper.new_array(pitch_table)
        local cor = HSV( 0.51, 1, 0.61, 1)
        reaper.ImGui_PushStyleColor( ctx,  reaper.ImGui_Col_PlotHistogram(),  cor)
        reaper.ImGui_PlotHistogram(ctx,"Notes" ,pitch_n_array, 0, nil, 0, nil, widh, (highth*6/n_lines)-pad)
        reaper.ImGui_PopStyleColor(ctx)
        ---- Draw Note names
        local bars_center_list = GetBarsCenterX(widh, 12)

        if sharps == false then  
            sel_list = pitch_class_b_list
        else 
            sel_list = pitch_class_s_list
        end

        local curX, curY = reaper.ImGui_GetCursorPos(ctx)
        local Ypad = 150/n_lines 


        reaper.ImGui_PushFont(ctx, font)
        --Write Note Names
        for i  = 1, 12 do
            local center_bar = bars_center_list[i] + 7
            local txt_w, txt_h = reaper.ImGui_CalcTextSize( ctx, sel_list[i], nil, nil, nil, nil)
            local text_centered_x = center_bar - (txt_w/2)
            reaper.ImGui_SetCursorPosY(ctx,curY - Ypad )
            reaper.ImGui_SetCursorPosX(ctx, text_centered_x )
            reaper.ImGui_Text( ctx, sel_list[i])

            if show_count then
                local txt_w, txt_h = reaper.ImGui_CalcTextSize( ctx, pitch_table[i], nil, nil, nil, nil)
                local text_centered_x = center_bar - (txt_w/2)
                reaper.ImGui_SetCursorPosY(ctx,curY - Ypad*2 )
                reaper.ImGui_SetCursorPosX(ctx, text_centered_x )
                reaper.ImGui_Text( ctx, pitch_table[i])
            end

        end
        reaper.ImGui_PopFont(ctx)

        reaper.ImGui_End(ctx)
    end

    ------------- Keep or Close
    if open then
        reaper.defer(GUI)
    else
        reaper.ImGui_DestroyContext(ctx)
    end
end

--Checks Configure

-- Sets Some Variables


sharps = true
is_on = false
show_count = true

link = IsSelectionLinkEdit()
pitch_table = {0,0,0,0,0,0,0,0,0,0,0,0}
pitch_class_s_list = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
pitch_class_b_list = {"C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"}

GUI()
