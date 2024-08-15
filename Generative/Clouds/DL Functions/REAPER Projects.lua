--@noindex
--version: 0.0

DL = DL or {}
DL.proj = {}


-- Makes all media offline, will change focused project! So prevent ui refresh and call back the focused project  local focus_proj = reaper.EnumProjects( -1 ); reaper.SelectProjectInstance( focus_proj )
function DL.proj.MakeMediasOffline()
    for proj in DL.enum.enumProjects() do
        reaper.SelectProjectInstance( proj )
        reaper.Main_OnCommand(40100, 0) --Item: Set all media offline
    end
end

-- Makes all media online, will change focused project! So prevent ui refresh and call back the focused project
function DL.proj.MakeMediasOnline()
    for proj in DL.enum.enumProjects() do
        reaper.SelectProjectInstance( proj )
        reaper.Main_OnCommand(40101, 0) --Item: Set all media online
    end
end

---Closes current project tab without prompting the user to save. Will change the focused project, put it back with.
---@param proj ReaProject project (cannot be a number)
function DL.proj.CloseProject(proj)
    if not reaper.ValidatePtr(proj, 'ReaProject*') then return false end
    reaper.SelectProjectInstance( proj )
    reaper.Main_openProject( 'noprompt:template:' )
    reaper.Main_OnCommand(40860, 0)-- Close current project tab
end

---Get the full path of a project with name and .rpp
---@param proj ReaProject|0|nil project
---@return string path
function DL.proj.GetFullPath(proj) -- with projct Name. with .rpp at the end
    return reaper.GetProjectPathEx(proj):gsub("(.*)\\.*$","%1")  .. reaper.GetProjectName(proj)
end