--@noindex
--version: 0.1
-- 0.1
-- Fix GetExtension

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

