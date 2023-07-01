--@noindex
--version: 0.2.1
-- correct project path

---------------------
----------------- Project Functions 
---------------------


function GetFullProjectPath(proj) -- with projct Name. with .rpp at the end
    return reaper.GetProjectPath(proj , '' ):gsub("(.*)\\.*$","%1")  .. reaper.GetProjectName(proj)
end

---------------------
----------------- Extension Checker 
---------------------

--- Check if user REAPER version. min_version and max_version are optional
function CheckREAPERVersion(min_version, max_version)
    local reaper_version = reaper.GetAppVersion():match('%d+%.%d+')
    local bol, why = CompareVersion(reaper_version, min_version, max_version)
    if not bol then
        local text
        if why == 'min' then
            text = 'This script requires that REAPER minimum version be : '..min_version..'.\nYour version is '..reaper_version
        elseif why == 'max' then
            text = 'This script requires that REAPER maximum version be : '..max_version..'.\nYour version is '..reaper_version
        end
        reaper.ShowMessageBox(text, 'Error - REAPER at Incompatible Version', 0)
        return false
    end
    return true
end
--- Check if user have Extension. min_version and max_version are optional
function CheckSWS(min_version, max_version)
    if not reaper.APIExists('CF_GetSWSVersion') then
        local text = 'This script requires the SWS Extension to run. \nWould you like to be redirected to the SWS Extension website to install it?'
        local ret = reaper.ShowMessageBox(text, 'Error - Missing Dependency', 4)
        if ret == 6 then
            open_url('https://www.sws-extension.org/')
        end
        return false
    else
        local sws_version = reaper.CF_GetSWSVersion()
        local bol, why = CompareVersion(sws_version, min_version, max_version)
        if not bol then
            local text, url
            if why == 'min' then
                text = 'This script requires that SWS minimum version be : '..min_version..'.\nYour version is '..sws_version..'.\nWould you like to be redirected to the SWS Extension website to update it?'
                url = 'https://www.sws-extension.org/'
            elseif why == 'max' then
                text = 'This script requires that SWS maximum version be : '..max_version..'.\nYour version is '..sws_version..'.\nWould you like to be redirected to the website of old version SWS Extension to downgrade it?'
                url = 'https://www.sws-extension.org/download/old/'
            end
            local ret = reaper.ShowMessageBox(text, 'Error - Missing Dependency', 4)
            if ret == 6 then
                open_url(url)
            end
            return false
        end
    end
    return true
end

--- Check if user have Extension. min_version and max_version are optional
function CheckReaImGUI(min_version, max_version)
    if not reaper.APIExists('ImGui_GetVersion') then
        local text = 'This script requires the ReaImGui extension to run. You can install it through ReaPack.\nAfter installing an extension you must restart REAPER'
        local ret = reaper.ShowMessageBox(text, 'Error - Missing Dependency', 0)
        return false
    else
        local imgui_version, imgui_version_num, reaimgui_version = reaper.ImGui_GetVersion()
        local bol, why = CompareVersion(reaimgui_version, min_version, max_version)
        if not bol then
            local text
            if why == 'min' then
                text = 'This script requires that ReaImgui minimum version be : '..min_version..'.\nYour version is '..reaimgui_version..'\nYou can update it through ReaPack.\nAfter installing an extension you must restart REAPER'
            elseif why == 'max' then
                text = 'This script requires that ReaImgui maximum version be : '..max_version..'.\nYour version is '..reaimgui_version..'\nYou can update it through ReaPack.\nAfter installing an extension you must restart REAPER'
            end
            reaper.ShowMessageBox(text, 'Error - Dependency at Incompatible Version', 0)
            return false
        end
    end    
    return true
end

--- Check if user have Extension. min_version and max_version are optional
function CheckJS(min_version, max_version)
    if not reaper.APIExists('JS_ReaScriptAPI_Version') then
        local text = 'This script requires the js_ReaScriptAPI extension to run. You can install it through ReaPack.\nAfter installing an extension you must restart REAPER'
        local ret = reaper.ShowMessageBox(text, 'Error - Missing Dependency', 0)
        return false
    else
        local js_version = tostring(reaper.JS_ReaScriptAPI_Version())
        local bol, why = CompareVersion(js_version, min_version, max_version)
        if not bol then
            local text
            if why == 'min' then
                text = 'This script requires that js_ReaScriptAPI minimum version be : '..min_version..'.\nYour version is '..js_version..'\nYou can update it through ReaPack.\nAfter installing an extension you must restart REAPER'
            elseif why == 'max' then
                text = 'This script requires that js_ReaScriptAPI maximum version be : '..max_version..'.\nYour version is '..js_version..'\nYou can update it through ReaPack.\nAfter installing an extension you must restart REAPER'
            end
            reaper.ShowMessageBox(text, 'Error - Dependency at Incompatible Version', 0)
            return false
        end
    end
    return true
end