--@noindex
--version: 0.2
-- add CurlFormat

DL = DL or {}
DL.url = {}

-- A convinience for backward-compability
function DL.url.OpenURL(url)
    reaper.CF_ShellExecute(url)
end


local os = reaper.GetOS()
--- Formats a string to be used with the cURL command.
--- On Windows, the string is prefixed with 'curl ', while on other platforms it is prefixed with '/usr/bin/env curl '.
--- @param string string The string to be formatted for cURL.
--- @return string The formatted string.
function DL.url.CurlFormat(string)
    if os:match('^Win') then
        string = 'curl '..string
    else
        string = '/usr/bin/env curl '..string
    end
    return string
end