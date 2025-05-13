--@noindex
DL_Manager = DL_Manager or {}
DL_Manager.backup = {}

DL_Manager = DL_Manager or {}
DL_Manager.backup = {
    input = {   
        path = '',
        recursive = true,
        extension = 'rpp-bak'
    },

    files = {},

    actions = {
        keep_latests = {
            n = 1
        }
    }
}

local ref_rate = 1/10

local function getBackupFileContent(path)
    -- open file
    local file = io.open(path, "r")
    if not file then
        error("Could not open file: " .. path)
    end

    local content = file:read("*all")
    file:close()
    return content
end

--- Fast but don't return the size or line or substring of each backup
local function listBackups(content)
    local t = {}
    local pattern = '<REAPER_PROJECT ([%d%.]+) "(.-)" (%d+)'
    --- get the first line
    local chunk_version, r_version, timestamp = content:match('^'..pattern)
    if chunk_version == '0.1' then
        t[#t+1] = {chunk_version = chunk_version, r_version = r_version, timestamp = timestamp}
    end
    --- Subsequent lines
    for chunk_version, r_version, timestamp in content:gmatch('[\n\r]'..pattern) do
        if chunk_version == '0.1' then
            t[#t+1] = {chunk_version = chunk_version, r_version = r_version, timestamp = timestamp}
        end
    end
    return t
    -- body
end

function DL_Manager.backup.search(path, extension, recursive)
    local files = DL.files.FindFilesByExtension(extension, path, recursive)
    local files_org = DL_Manager.backup.OrganizeTable(files)
    return files_org
end

function DL_Manager.backup.OrganizeTable(files)
    local t = {}
    for k, path in ipairs(files) do
        local retval, size, accessedTime, modifiedTime, cTime, deviceID, deviceSpecialID, inode, mode, numLinks, ownerUserID, ownerGroupID = reaper.JS_File_Stat( path ) 
        if retval == 0 then  -- 0 = true, negative = didn't work.
            local back_t = {
                path = path,
                select = false,
                mod_time = modifiedTime,
                size = size,
                v_count = '?'
            }
            t[#t+1] = back_t
        end
    end
    return t
end

function DL_Manager.backup.AddVersionCountToTable(files)
    local start = reaper.time_precise()
    for k, v in ipairs(files) do
        if v.select then
            local path = v.path
            local content = getBackupFileContent(path)
            local v_list = listBackups(content)
            v.v_count = #v_list
        end

        if reaper.time_precise() - start >= ref_rate then
            coroutine.yield(false, k, #files)
        end 
    end
    coroutine.yield(true, 1, 1)
end

--- mod of DL.files.FindFilesByExtension to keep the folder nesting 
function DL_Manager.backup.FindFilesByExtension(extension, path, recursive, nesting)
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
            if nesting then
                --sub_files.name = 
                files[#files+1] = sub_files
            else
                for k, v in ipairs(sub_files) do
                    files[#files+1] = v
                end
            end
        end
    end

    return files
end

function DL_Manager.backup.DeleteBackups(files)
    for k, v in DL.t.ipairs_reverse(files) do
        local path = v.path
        local is_del = v.select
        if is_del and reaper.file_exists(path) then
            os.remove(path)
            table.remove(files, k)
        end
    end    
end

function DL_Manager.backup.CountSelected(files)
    local cnt, size = 0, 0
    for index, value in ipairs(files) do
        if value.select then
            cnt = cnt + 1
            size = size + value.size
        end
    end
    return cnt, size
end

function DL_Manager.backup.SelectAll(is_select, history)
    if is_select == nil then  -- Nil = toggle between on and off
            is_select = false
        -- check if any item is selected
        for k, v in ipairs(DL_Manager.backup.files) do
            if not v.select then
                is_select = true
                break
            end
        end
    end

    local undo = {}
    for k, v in ipairs(DL_Manager.backup.files) do
        if is_select ~= v.select then -- save if state change
            undo[#undo+1] = k
        end
        v.select = is_select
    end
    if #undo > 0 then
        history[#history+1] = undo
    end
end

function DL_Manager.backup.SelectNewest(is_select, new_limit, history)
    new_limit = DL.num.Clamp(new_limit, 1) -- cap to 1
    local newest = {}

    for k, v in ipairs(DL_Manager.backup.files) do
        local path = v.path
        local dir = DL.files.GetDir(path)
        local mod_time = v.mod_time
        newest[dir] = newest[dir] or {} -- {v,v,v}

        for i = 1, new_limit do
            if newest[dir][i] then
                if mod_time > newest[dir][i].v.mod_time then
                    table.insert(newest[dir], i, {v=v, row = k})
                    if #newest[dir] > new_limit then
                        table.remove(newest[dir],#newest[dir])
                    end
                    break
                end 
            else
                newest[dir][i] = {v=v, row = k}
                break
            end
        end
    end

    local undo = {}
    for dir, new_collection in pairs(newest) do  
        for k, t in ipairs(new_collection) do
            local v = t.v
            local row = t.row
            if is_select ~= v.select then -- save if state change
                undo[#undo+1] = row
            end
            v.select = is_select
        end
    end
    
    if #undo > 0 then
        history[#history+1] = undo
    end
end

function DL_Manager.backup.SortFiles(ctx)
    local function sort(a, b)
        for next_id = 0, math.huge do
            local ok, col_idx, col_user_id, sort_direction = ImGui.TableGetColumnSortSpecs(ctx, next_id)
            if not ok then break end
        
            -- Here we identify columns using the ColumnUserID value that we ourselves passed to TableSetupColumn()
            -- We could also choose to identify columns based on their index (col_idx), which is simpler!
            local key
            if col_user_id == 1 then
                key = 'path'
            elseif col_user_id == 3 then
                key = 'mod_time'
            elseif col_user_id == 4 then
                key = 'size'
            elseif col_user_id == 2 then
                key = 'v_count'
            end
            local a_val, b_val = a[key], b[key]

            if key == 'v_count' then
                a_val = type(a_val) == 'string' and -1 or tonumber(a_val)
                b_val = type(b_val) == 'string' and -1 or tonumber(b_val)
            end
        
            local is_ascending = sort_direction == ImGui.SortDirection_Ascending
            if a_val < b_val then
                return is_ascending
            elseif a_val > b_val then
                return not is_ascending
            end
        end
        
        -- table.sort is unstable so always return a way to differentiate items.
        -- Your own compare function may want to avoid fallback on implicit sort specs.
        -- e.g. a Name compare if it wasn't already part of the sort specs.
        return a.path < b.path
    end

    table.sort(DL_Manager.backup.files, sort)
end

---------------------------Versions -: 

--- Slow return all info of backups
local function calculateBackupLines(content)
    local stack = {count = 0} -- count is for keeping track of the subchunks
    local l_cnt = 0
    for line in content:gmatch("[^\r\n]+") do
        l_cnt = l_cnt + 1
        if line:match("^<") then
            if stack.count == 0 then
                local chunk_version, r_version, timestamp = line:match('^<REAPER_PROJECT ([%d%.]+) "(.-)" (%d+)')
                table.insert(stack, {start = l_cnt, size = 0, r_version = r_version, timestamp = timestamp, chunk_version = chunk_version})
            end
            stack.count = stack.count + 1 -- keeps track of  which subchunk we are
        elseif line:match("^>$") and #stack > 0 then
            if stack.count == 1 then
                stack[#stack].fim = l_cnt 
            end
            stack.count = stack.count - 1 -- keeps track of  which subchunk we are
        end
        stack[#stack].size = stack[#stack].size + #line
    end
    stack.count = nil
    return stack
end

function DL_Manager.backup.CalculateLimitBackups(files, v_limit)
    local size = 0
    local mod_files = 0
    local n_versions = 0
    for k, v in ipairs(files) do
        if v.select then
            local path = v.path
            local content = getBackupFileContent(path)
            local backups = calculateBackupLines(content)

            --- Calculate the reduced size and mark which backups should be deleted
            -- N of edited files
            if (#backups - v_limit) > 0 then
                mod_files = mod_files + 1
            end
            for i = 1, #backups - v_limit do
                local b = backups[i]
                if b.chunk_version == '0.1' then
                    -- N of versions to be deleted
                    n_versions = n_versions + 1
                    -- Size
                    size = size + b.size
                    b.is_del = true
                end
            end
        end
    end
    return mod_files, n_versions, size
end

function DL_Manager.backup.DeleteBackupVersions(files, v_limit)
    local start = reaper.time_precise()
    for k, v in ipairs(files) do
        if v.select then
            local path = v.path
            local content = getBackupFileContent(path)
            local backups = listBackups(content)
            local total_del = #backups - v_limit
            if total_del > 0 then
                local new_content = {}
                local backup = 0
                local stack = 0
                local is_del = false

                for line in content:gmatch("[^\r\n]+") do
                    if line:match("^<") then
                        if stack == 0 then
                            backup = backup + 1
                            if backup <= total_del then
                                is_del = true
                            else
                                is_del = false
                            end
                        end
                        stack = stack + 1 
                    elseif line:match('^>') then
                        stack = stack - 1
                    end

                    if not is_del then
                        new_content[#new_content+1] = line
                    end
                end

                local new_content_string = table.concat(new_content,'\n')..'\n'
                local file = io.open(path, "w")
                if file then
                    file:write(new_content_string)
                    file:close()
                    v.size = new_content_string:len()
                else
                    print("Error: Unable to open the file for writing")
                end
            end
        end
    end  
    coroutine.yield({is_done = true})
end