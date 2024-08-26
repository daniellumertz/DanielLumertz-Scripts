--@noindex
--version: 0.1

DL = DL or {}
DL.url = {}

-- A convinience for backward-compability
function DL.url.OpenURL(url)
    reaper.CF_ShellExecute(url)
end