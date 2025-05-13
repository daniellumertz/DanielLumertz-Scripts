--@noindex
--version: 0.0

DL = DL or {}
DL.check = {}

---------------------
----------------- Extension Checker 
---------------------

--- Check if user REAPER version. min_version and max_version are optional
---@param min_version string?
---@param max_version string?
---@return boolean
function DL.check.REAPERVersion(min_version, max_version)
    local reaper_version = reaper.GetAppVersion():match('%d+%.%d+')
    local bol, why = DL.num.CompareVersion(reaper_version, min_version, max_version)
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
---@param min_version string?
---@param max_version string?
---@return boolean
function DL.check.SWS(min_version, max_version)
    if not reaper.APIExists('CF_GetSWSVersion') then
        local text = 'This script requires the SWS Extension to run. Install it via ReaPack!'
        local ret = reaper.ShowMessageBox(text, 'Error - Missing Dependency', 0)

        return false
    else
        local sws_version = reaper.CF_GetSWSVersion()
        local bol, why = DL.num.CompareVersion(sws_version, min_version, max_version)
        if not bol then
            local text, url
            if why == 'min' then
                text = 'This script requires that SWS minimum version be : '..min_version..'.\nYour version is '..sws_version..'.\nUpdate via ReaPack and restart REAPER!'
                url = 'https://www.sws-extension.org/'
            elseif why == 'max' then
                text = 'This script requires that SWS maximum version be : '..max_version..'.\nYour version is '..sws_version..'.\nDowngrade via ReaPack and restart REAPER!'
                url = 'https://www.sws-extension.org/download/old/'
            end
            local ret = reaper.ShowMessageBox(text, 'Error - Missing Dependency', 0)
            return false
        end
    end
    return true
end

--- Check if user have Extension. Using ImGui shim will automatically compare the minimum version. But this will show a more personalized message. 
---@param min_version string?
---@param max_version string?
---@return boolean
function DL.check.ReaImGUI(min_version, max_version)
    if not reaper.APIExists('ImGui_GetVersion') then
        local text = 'This script requires the ReaImGui extension to run. You can install it through ReaPack.\nAfter installing an extension you must restart REAPER'
        local ret = reaper.ShowMessageBox(text, 'Error - Missing Dependency', 0)
        return false
    else
        local imgui_version, imgui_version_num, reaimgui_version = reaper.ImGui_GetVersion() ---@diagnostic disable-line: undefined-field
        local bol, why = DL.num.CompareVersion(reaimgui_version, min_version, max_version)
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
---@param min_version string?
---@param max_version string?
---@return boolean
function DL.check.JS(min_version, max_version)
    if not reaper.APIExists('JS_ReaScriptAPI_Version') then
        local text = 'This script requires the js_ReaScriptAPI extension to run. You can install it through ReaPack.\nAfter installing an extension you must restart REAPER'
        local ret = reaper.ShowMessageBox(text, 'Error - Missing Dependency', 0)
        return false
    else
        local js_version = tostring(reaper.JS_ReaScriptAPI_Version())
        local bol, why = DL.num.CompareVersion(js_version, min_version, max_version)
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