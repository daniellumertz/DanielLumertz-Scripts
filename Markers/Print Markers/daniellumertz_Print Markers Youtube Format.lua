-- @version 0.0.1
-- @author Daniel Lumertz
-- @provides
--    [nomain] DL Functions/*.lua
-- @changelog
--    + Initial Release
-- @license MIT
--------------------- Options
local ret, values = reaper.GetUserInputs(
    "Format Options", 3,
    "Show hours (y/n),Show milliseconds (y/n),Consider project playrate (y/n)",
    "y,f,y"
)

local is_hour, is_ms, is_playrate
if ret then
    local v1, v2, v3 = values:match("([^,]+),([^,]+),([^,]+)")
    is_hour     = v1 == "y"
    is_ms       = v2 == "y"
    is_playrate = v3 == "y"
else 
    return
end


----------------------
package.path = package.path..';'..debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
require("DL Functions.General Debug")
require("DL Functions.REAPER Enumerate")
require("DL Functions.General Number")

reaper.ClearConsole()
local proj = 0
for retval, isrgn, mark_pos, rgnend, name, markrgnindexnumber, i in DL.enum.ProjectMarkers2(proj, 1) do
    local time = mark_pos
    if is_playrate then
        time = time / reaper.Master_GetPlayRate( proj )
    end
    print(DL.num.FormatSecondsAsTime(time, is_hour, is_ms)..' '..name)
end