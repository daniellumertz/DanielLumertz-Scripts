--@noindex
DL_Manager = DL_Manager or {}
DL_Manager.misc = {}

-- Split paths into segment
local function splitPath(path)
    local segments = {}
    for segment in path:gmatch("[^/]+") do
        table.insert(segments, segment)
    end
    return segments
end

function DL_Manager.misc.removeCommonDirectories(path1, path2)  
    local segments1 = splitPath(path1)
    local segments2 = splitPath(path2)
    
    -- Find the number of common directories at the beginning
    local commonCount = 0
    local space_count = 0
    for i = 1, math.min(#segments1, #segments2) do
        if segments1[i] == segments2[i] then
            commonCount = commonCount + 1
            space_count = space_count +  utf8.len(segments2[i]) 
        else
            break
        end
    end
    space_count = space_count + (commonCount - 1) -- add the / that will be missed
    
    -- Build the result by replacing common directories with spaces
    local result = string.rep(" ", space_count)
    
    -- Add the remaining unique parts from path2
    for i = commonCount + 1, #segments2 do
        local trailing = i == 1 and '' or '/' --Dont add / separator if it is the start of a new directory 
        result = result .. trailing .. segments2[i]
    end
    
    return result
end

