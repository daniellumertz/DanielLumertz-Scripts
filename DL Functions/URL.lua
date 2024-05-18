--@noindex
--version: 0.0

DL = DL or {}
DL.url = {}

function DL.url.OpenURL(url)
    local OS = reaper.GetOS()
    if OS == "OSX32" or OS == "OSX64" then
        os.execute('open "" "' .. url .. '"')
    else
        os.execute('start "" "' .. url .. '"')
    end
end