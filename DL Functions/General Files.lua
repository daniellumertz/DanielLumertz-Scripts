--@noindex
--version: 0.1
-- 0.1
-- Fix GetExtension
-- add DirectoryExists

DL = DL or {}
DL.files = {}
---------------------
----------------- Files
---------------------

---Copy a file
---@param source_path string
---@param destination_path string
---@return boolean successfully return true if it opened and copied the file
---@return string|nil error return a string with the error message
function DL.files.Copy(source_path,destination_path)
    local infile = io.open(source_path, "rb")
    if not infile then return false, 'Could not find/open the source file.' end
    local instr = infile:read("*a")
    infile:close()

    local outfile = io.open(destination_path, "wb")
    if not outfile then return false, 'Could not create file.' end
    outfile:write(instr)
    outfile:close()
    return true
end

---Returns file directory, without file name
---@param file_path string
---@return string
function DL.files.GetDir(file_path)
    return file_path:match('(.+)[\\/]')
end

---Return File name without extension
---@param file_path string
---@param is_ext boolean? false by default, if true return the name with the extension
---@return string
function DL.files.GetName(file_path, is_ext)
    local pattern = is_ext and '.*[\\/](.+)$' or '.*[\\/](.+)%..+$' 
    return file_path:match(pattern)    
end

---Gets File path and return the extension, like "wav" or "avi". Without the dot!
---@param file_path string
---@return string
function DL.files.GetExtension(file_path)
    return file_path:match('%.([^%.]+)$')
end

---Returns if the file name have a valid extension
---@param file_name string string containing the name ending with the extension "Example.wav"
---@param valid_extensions table table containing all possible extensions names, without dots {'wav', 'mp3', 'mom', 'birdbird'}
---@return boolean
function DL.files.IsValidExtension(file_name, valid_extensions) 
    for k, ext in ipairs(valid_extensions) do
        if DL.files.GetExtension(file_name):lower() == ext:lower() then
            return true
        end
    end
    return false 
end

function DL.files.FindFilesByExtension(extension, path, recursive)
    local files = {}
    
    for file in DL.enum.Files(path) do
        local file_path = path..'/'..file
        local file_extension = DL.files.GetExtension(file_path)
        if file_extension == extension then
            files[#files+1] = file_path
        end 
    end

    if recursive then
        for sub_directory in DL.enum.SubDirectories(path) do
            local sub_path = path .. '/' .. sub_directory 
            local sub_files = DL.files.FindFilesByExtension(extension, sub_path, recursive)
            for k, v in ipairs(sub_files) do
                files[#files+1] = v
            end
        end
    end

    return files
end

function DL.files.DirectoryExists(path)
    local ok, err, code = os.rename(path, path)
    if not ok then
       if code == 13 then
          -- Permission denied, but it exists
          return true
       end
    end
    return ok, err
end

---Opens the specified directory path in the default file explorer of the current operating system.
---@param dirPath string The directory path to open
---@return boolean success True if the directory was successfully opened, false otherwise
function DL.files.GoToPath(dirPath)
    -- Get the OS type
    local osType = reaper.GetOS()
    
    -- Build the command based on OS
    local command
    if osType:match("^Win") then
        -- Windows: Use explorer.exe
        command = 'explorer.exe "' .. dirPath:gsub('/', '\\') .. '"'
    elseif osType:match("^OSX") then
        -- macOS: Use open command
        command = 'open "' .. dirPath .. '"'
    elseif osType:match("^Other") then
        -- Linux: Try xdg-open (most common)
        command = 'xdg-open "' .. dirPath .. '"'
    else
        reaper.ShowMessageBox("Unsupported operating system", "Error", 0)
        return false
    end
    
    -- Execute the command
    local result = reaper.ExecProcess(command, -1) 
end

---Converts a file size in bytes to a human-readable string with appropriate units.
---@param bytes number The file size in bytes
---@return string Formatted file size with two decimal places and appropriate unit (B, KB, MB, GB, TB)
function DL.files.formatFileSize(bytes)
    local units = {"B", "KB", "MB", "GB", "TB"}
    local unitIndex = 1
    local size = bytes
    
    while size >= 1024 and unitIndex < #units do
        size = size / 1024
        unitIndex = unitIndex + 1
    end
    
    -- Round to 2 decimal places
    return string.format("%.2f %s", size, units[unitIndex])
end

