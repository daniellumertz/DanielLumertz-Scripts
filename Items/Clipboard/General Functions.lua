-- @noindex
function print( ...) 
    local t = {}
    for i, v in ipairs( { ... } ) do
      t[i] = tostring( v )
    end
    reaper.ShowConsoleMsg( table.concat( t, "\n" ) .. "\n" )
end

function SaveSelectedItems()
    local list = {}
    local num = reaper.CountSelectedMediaItems(0)
    if num ~= 0 then
        for i= 0, num-1 do
            list[i+1] =  reaper.GetSelectedMediaItem( 0, i )
        end
    end
    return list
end

function LoadSelectedItems(list)
    for i = 1, #list do 
        if reaper.ValidatePtr(list[i], 'MediaItem*') then
            reaper.SetMediaItemSelected( list[i], true )
        end
    end

end


--- GUI
function ResetStyleCount()
    reaper.ImGui_PopStyleColor(ctx,CounterStyle) -- Reset The Styles (NEED FOR IMGUI TO WORK)
    CounterStyle = 0
end

function ChangeColor(H,S,V,A)
    reaper.ImGui_PushID(ctx, 3)
    local button = reaper.ImGui_ColorConvertHSVtoRGB( H, S, V, A)
    local hover =  reaper.ImGui_ColorConvertHSVtoRGB( H, S , (V+0.4 < 1) and V+0.4 or 1 , A)
    local active = reaper.ImGui_ColorConvertHSVtoRGB( H, S, (V+0.2 < 1) and V+0.2 or 1 , A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),  button)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), hover)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  active)
end

function GetItemColor(item,take)
    local item_color = reaper.GetDisplayedMediaItemColor( item, take )
    local r, g, b = reaper.ColorFromNative( item_color )
    local retval, h, s, v = reaper.ImGui_ColorConvertRGBtoHSV( r,  g,  b)
    local col_num = rgba2num(r, g, b, 255)
    return col_num
end

function rgba2num(red, green, blue, alpha)

	local blue = blue * 256
	local green = green * 256 * 256
	local red = red * 256 * 256 * 256
	
	return red + green + blue + alpha
end

  
