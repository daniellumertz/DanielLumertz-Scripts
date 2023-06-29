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


---Compare versions. Check and min versions must have the same amount of versions numbers. Like 0.7.2 and 0.7.0
---@param check_version string version to check 
---@param min_version string min version
---@param separator string separator
---@return boolean retval did it passed the filters? 
---@return string why reason it didnt pass the filter. return 'min' or 'max'. if passed it will return nil
function CompareVersion(check_version, min_version, max_version, separator)
    separator = separator or '.'
    local check_table = {}
    for version in check_version:gmatch('(%d+)'..separator..'?') do
        check_table[#check_table+1] = tonumber(version)
    end

    local min_table
    if min_version then
        min_table = {}
        for version in min_version:gmatch('(%d+)'..separator..'?') do
            min_table[#min_table+1] = tonumber(version)
        end
    end

    local max_table
    if max_version then
        max_table = {}
        for version in max_version:gmatch('(%d+)'..separator..'?') do
            max_table[#max_table+1] = tonumber(version)
        end
    end

    for index, check_v in ipairs(check_table) do
        -- check if is less than the min_version
        if min_table and check_v < (min_table[index] or 0) then
            return false, 'min'
        elseif min_table and check_v > (min_table[index] or 0) then -- bigger than the min version stop checking min_version
            min_table = nil
        end
        
        -- check if is more than the max_version
        if max_table and check_v > (max_table[index] or 0) then
            return false, 'max'
        elseif max_table and check_v < (max_table[index] or 0) then -- less than the max version stop checking max_version
            max_table = nil
        end    
    end

    return true, nil
end