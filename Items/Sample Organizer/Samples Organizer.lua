-- @version 1.2
-- @author Daniel Lumertz
-- @provides
--    [nomain] General Function.lua
--    [nomain] REAPER Functions.lua
-- @changelog
--    + Update Checkers


----------------------
--Script info
----------------------



script_version = "1.2"
---
info = debug.getinfo(1,'S')
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]] -- this script folder
--- Loading

dofile(script_path .. 'General Function.lua') -- General Functions needed
dofile(script_path .. 'REAPER Functions.lua') -- preset to work with Tables


if not CheckSWS() or not CheckReaImGUI() or not CheckJS() then return end
-- Imgui shims to 0.7.2 (added after the news at 0.8)
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.7.2')

----------------------
--Fake info
----------------------
selection_only = true

--[[ source_list = {}
table.insert( source_list, reaper.GetTrack(0, 1)) -- Fake source for now
table.insert( source_list, reaper.GetTrack(0, 2)) -- Fake source for now

pos_list = {}
table.insert( pos_list, reaper.GetTrack(0, 6)) -- Fake Position for now
table.insert( pos_list, reaper.GetTrack(0, 7))  -- Fake Position for now ]]

--paste_start = reaper.GetCursorPosition()
--crono_mode = false
------

----------------------
--Script Functions
----------------------

function SetSources()
    source_list = {}
    local track_count = reaper.CountSelectedTracks(0)
    for i = 0, track_count-1 do 
        table.insert( source_list, reaper.GetSelectedTrack(0, i))
    end
end

function NumSour()
    local string = ''
    for k,strack_loop in pairs(source_list) do
        local number = math.floor(reaper.GetMediaTrackInfo_Value(strack_loop, 'IP_TRACKNUMBER'))
        if k == 1 then string = number else string = string..', '..number end
    end
    return string
end

function SetPos()
    pos_list = {}
    local track_count = reaper.CountSelectedTracks(0)
    for i = 0, track_count-1 do 
        table.insert( pos_list, reaper.GetSelectedTrack(0, i))
    end
end

function NumPos()
    local string = ''
    for k,ptrack_loop in pairs(pos_list) do
        local number = math.floor(reaper.GetMediaTrackInfo_Value(ptrack_loop, 'IP_TRACKNUMBER'))
        if k == 1 then string = number else string = string..', '..number end
    end
    return string
end

-- if #pos_list ~= 0 then !!!!!!!!!!!!!Add select pos tracks
function MakePasteList()
  local to_paste = {}
  for k, loop_pos_track in ipairs(pos_list) do 
      local item_count = reaper.CountTrackMediaItems(loop_pos_track)
      if item_count ~= 0 then 
        for i = 0,  item_count - 1 do 
            local loop_item = reaper.GetTrackMediaItem(loop_pos_track, i)
            local start_item = reaper.GetMediaItemInfo_Value(loop_item, 'D_POSITION')
            local len_item = reaper.GetMediaItemInfo_Value(loop_item, 'D_LENGTH')
            --local fim_item = start_item + len_item
            if selection_only == false or start_item >= start_sel and start_item < fim_sel then 
              to_paste[#to_paste+1] = {}
              to_paste[#to_paste].item = loop_item
              to_paste[#to_paste].start = start_item
              to_paste[#to_paste].len = len_item
              to_paste[#to_paste].track = loop_pos_track
              --Item is to be copied
            elseif start_item > fim_sel then break   -- Break if an item is outside boudries (Only will go to this elseif if selection_only is true) will break the loop on the track
            end
        end
      end
  end
  return to_paste
end

function CronoList(list)  -- Get to_paste and makes it cronological
    local keys = {}
    for key, _ in pairs(list) do
        table.insert(keys, key)
    end

    table.sort(keys, function(keyLhs, keyRhs) return list[keyLhs].start < list[keyRhs].start end)

    local crono_list ={}
    for k, v in pairs(keys) do 
        --print(k)
        crono_list[k] = {}
        crono_list[k] = to_paste[v]
    end 

    return crono_list
end
----------------------
--Script Linear
----------------------
function Paste()
    paste_start = reaper.GetCursorPosition()
    start_sel, fim_sel = reaper.GetSet_LoopTimeRange( false, false, 0, 0, false )
    if pos_list then 
        to_paste = MakePasteList()
        if #to_paste >= 1 then
            reaper.Undo_BeginBlock()
            if crono_mode == true then to_paste = CronoList(to_paste) end -- This function sort table to_paste looking at to_paste[key].start
            -- Save Info
            local cursor_pos = reaper.GetCursorPosition()
            local last_track = reaper.GetLastTouchedTrack()
            local selected_items = SaveSelectedItems()
            local selected_tracks = SaveSelectedTracks()

            -- Copy Position Tracks
            reaper.SetEditCurPos( paste_start, false, false )
            for i = 1, #to_paste do
                --  Copy
                reaper.Main_OnCommand(40289, 0)--Item: Unselect all items
                reaper.SetMediaItemSelected( to_paste[i].item, true )
                reaper.SetOnlyTrackSelected( to_paste[i].track )
                reaper.Main_OnCommand(40698, 0) -- Copy Item 
                --  Paste
                reaper.Main_OnCommand(40914,0) -- Set first selected track as last touched
                reaper.Main_OnCommand(42398,0) -- Paste 
                -- Save item info DELETE IF NOT USED
                    --new_item_loop = reaper.GetSelectedMediaItem(0, 0)
                    --new_items[i] = {}
                    --new_items[i].item = new_item_loop
            end
            --Copy Sources
            if source_list and #source_list >= 1 then
                for source_i = 1, #source_list do 
                    reaper.SetOnlyTrackSelected( source_list[source_i] )
                    reaper.Main_OnCommand(40914,0) -- Set first selected track as last touched
                    reaper.SetEditCurPos( paste_start, false, false )
                    for i = 1, #to_paste do
                        reaper.Main_OnCommand(42406, 0) --Razor edit: Clear all areas
                        SetTrackRazorEdit(source_list[source_i], to_paste[i].start, to_paste[i].start+to_paste[i].len , true)
                        reaper.Main_OnCommand(40057, 0)--Edit: Copy items/tracks/envelope points (depending on focus) ignoring time selection
                        reaper.Main_OnCommand(42398,0) -- Paste 
                    end
                end
            end
            --Reset Things back
            if last_track then 
                reaper.SetOnlyTrackSelected( last_track )
                reaper.Main_OnCommand(40914,0) -- Set first selected track as last touched
            end
            reaper.SetEditCurPos( cursor_pos, false, false )
            LoadSelectedItems(selected_items)
            LoadSelectedTracks(selected_tracks)

            reaper.UpdateArrange()
            reaper.Undo_EndBlock('Organize Samples Paste', -1)
        else
            reaper.ShowConsoleMsg('No Item on Position Tracks at Time Selection')
        end
    else
        reaper.ShowConsoleMsg('Please Define Some Position Track')
    end
end
----------------------
--Gui
----------------------
local ctx = reaper.ImGui_CreateContext('S.Organizer')

--local ctx = reaper.ImGui_CreateContext('My script')
local size = reaper.GetAppVersion():match('OSX') and 12 or 14
local font = reaper.ImGui_CreateFont('sans-serif', size) -- Create the fonts you need
reaper.ImGui_AttachFont(ctx, font)-- Attach the fonts you need

--GUI FUNCTIONS
function HelpMarker(desc) -- Function to show a ?
    reaper.ImGui_TextDisabled(ctx, '(?)')
    if reaper.ImGui_IsItemHovered(ctx) then
      reaper.ImGui_BeginTooltip(ctx)
      reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 35.0)
      reaper.ImGui_Text(ctx, desc)
      reaper.ImGui_PopTextWrapPos(ctx)
      reaper.ImGui_EndTooltip(ctx)
    end
end

function ToolTip(text)
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_BeginTooltip(ctx)
        reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) *15)
        reaper.ImGui_Text(ctx, text)
        reaper.ImGui_PopTextWrapPos(ctx)
        reaper.ImGui_EndTooltip(ctx)
    end
end

function SetColor(a)
    local buttonColor  = reaper.ImGui_ColorConvertHSVtoRGB( a, 0.6, 0.6, 1.0)
    local hoveredColor = reaper.ImGui_ColorConvertHSVtoRGB( a, 0.7, 0.7, 1.0)
    local activeColor  = reaper.ImGui_ColorConvertHSVtoRGB( a, 0.8, 0.8, 1.0)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        buttonColor)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), hoveredColor)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  activeColor)
end

--GUI LOOP
function loop()
    -- Windowss Flags
    reaper.ImGui_PushFont(ctx, font)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(),              0x000000FF)

    reaper.ImGui_SetNextWindowSize(ctx, 208, 225, reaper.ImGui_Cond_Once())-- Set the size of the windows.  Use in the 4th argument reaper.ImGui_Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2

    --Begin
    local visible, open = reaper.ImGui_Begin(ctx, 'Sample Organizer', true,    reaper.ImGui_WindowFlags_None()
                                                                            |  reaper.ImGui_WindowFlags_NoResize()
                                                                            |  reaper.ImGui_WindowFlags_NoScrollbar()
                                                                            )
    if  visible then

        -----------
        ---- GUI

        ---------------- SOURCE BUTTON
        if reaper.ImGui_Button(ctx, ' Source ') then
            SetSources()
        end
        ToolTip('Define Souce Tracks:\nSource Tracks are tracks with Your Media not splited(normally)')

        if not source_list then 
            number_sourcer = "Define Tracks" 
        else 
            number_sourcer = NumSour() 
        end 

        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_PushItemWidth( ctx,  -1) -- Set the input text size to match the window
        rv, text = reaper.ImGui_InputText(ctx, '###', number_sourcer,reaper.ImGui_InputTextFlags_ReadOnly())
        ----------------- POSITION BUTTON
        if reaper.ImGui_Button(ctx, 'Position') then
            SetPos()
        end
        ToolTip('Define Position Tracks:\nPosition tracks will define where to copy from Source Tracks')
        if not pos_list then 
            number_pos = "Define Tracks" 
        else 
            number_pos = NumPos() 
        end
        reaper.ImGui_SameLine(ctx)
        rv, text = reaper.ImGui_InputText(ctx, '###2', number_pos,reaper.ImGui_InputTextFlags_ReadOnly())
        -------------- RADIO BUTTON
        if not val then val = 1 end
        rv, val = reaper.ImGui_RadioButtonEx(ctx, 'Category', val, 0); reaper.ImGui_SameLine(ctx)
        rv, val = reaper.ImGui_RadioButtonEx(ctx, 'Cronological', val, 1); 
        if val == 0 then crono_mode = false elseif val == 1 then crono_mode = true end
        --crono_mode = false
        -------------- Do It

        --SetColor(4)

        if reaper.ImGui_Button(ctx, ' Copy/Paste ',192,115) then
            Paste()
        end
        
        reaper.ImGui_End(ctx)

    end
    
    reaper.ImGui_PopFont(ctx) -- Always pop before ending
    reaper.ImGui_PopStyleColor(ctx)


    -----------
    ---- Ending


    if open then
        reaper.defer(loop)
    else
        reaper.ImGui_DestroyContext(ctx)
    end
end

--GUI KEEPER


--SCRIPT
reaper.defer(loop)
--loop()