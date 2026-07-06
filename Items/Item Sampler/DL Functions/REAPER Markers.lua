--@noindex
--version: 0.0

DL = DL or {}
DL.mark = {}


---Get the first mark that matches the name and is region
---@param proj ReaProject 
---@param name string string to check
---@param only_marker 0|1|2? 0 = both, 1 = only marker, 2 = only region. 1 is the default
---@return boolean? retval, boolean? isrgn, number? mark_pos, number? rgnend, string? mark_name, number? markrgnindexnumber, number? color, number? idx idx is the mark/region index that are passed to actions like reaper.EnumProjectMarkers3( proj, idx ). markrgnindexnumber is the index the user sets to a marker 
function DL.mark.GetByName(proj,name,only_marker)
    for retval, isrgn, mark_pos, rgnend, mark_name, markrgnindexnumber, color, idx in DL.enum.ProjectMarkers3(proj, only_marker) do 
        if name == mark_name then 
            return retval, isrgn, mark_pos, rgnend, mark_name, markrgnindexnumber, color, idx
        end
    end
end

---Get the first mark that matches the user ID.
---@param proj ReaProject 
---@param id number marker USER id. it is the ID the user see and set at Edit Marker/region.
---@param only_marker 0|1|2? 0 = both, 1 = only marker, 2 = only region. 1 is the default
---@return boolean? retval, boolean? isrgn, number? mark_pos, number? rgnend, string? mark_name, number? markrgnindexnumber, number? color, number? idx idx is the mark/region index that are passed to actions like reaper.EnumProjectMarkers3( proj, idx ). markrgnindexnumber is the index the user sets to a marker 
function DL.mark.GetByID(proj,id,only_marker)
    for retval, isrgn, mark_pos, rgnend, mark_name, markrgnindexnumber, color, idx in DL.enum.ProjectMarkers3(proj, only_marker) do 
        if id == markrgnindexnumber then 
            return retval, isrgn, mark_pos, rgnend, mark_name, markrgnindexnumber, color, idx
        end
    end
end

---comment
---@param proj ReaProject
---@param pos number
---@param only_marker 0|1|2?  0 = both, 1 = only marker, 2 = only region. 1 is the default
function DL.mark.GetClosest(proj, pos, only_marker)
    local previous = false
    local previous_table = false ---@type boolean|table
    for retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber, color, i in DL.enum.ProjectMarkers3(proj, only_marker) do
        if mark_pos > pos then 
            if previous then -- compare marker before with next return closest.
                if (pos-previous) <= (mark_pos-pos) then
                    retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber, color, i = table.unpack(previous_table)
                end
            end
            return retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber, color, i
        elseif mark_pos == pos then
            return retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber, color, i
        elseif mark_pos < pos  then
            previous = mark_pos
            previous_table = {retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber, color, i}
        end
    end

    if previous_table then -- in case there wasnt any markers after the marker before position
        return table.unpack(previous_table)
    else 
        return false
    end
end
