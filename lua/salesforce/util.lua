local Debug = require("salesforce.debug")

local Job = require("plenary.job")
local M = {}
local namespace = vim.api.nvim_create_namespace("salesforce.util")

local metadata_type_map = {
    ["lwc"] = "LightningComponentBundle",
    ["aura"] = "AuraDefinitionBundle",
    ["classes"] = "ApexClass",
    ["triggers"] = "ApexTrigger",
    ["pages"] = "ApexPage",
    ["components"] = "ApexComponent",
    ["flows"] = "Flow",
    ["objects"] = "CustomObject",
    ["layouts"] = "Layout",
    ["permissionsets"] = "PermissionSet",
    ["profiles"] = "Profile",
    ["labels"] = "CustomLabels",
    ["staticresources"] = "StaticResource",
    ["sites"] = "CustomSite",
    ["applications"] = "CustomApplication",
    ["roles"] = "UserRole",
    ["groups"] = "Group",
    ["queues"] = "Queue",
}

function M.notify_command_in_progress(category)
    Debug:log("util.lua", "User tried to execute a command while another command is in progress")
    M.clear_and_notify(
        string.format("A %s Salesforce command is already in progress", category),
        vim.log.levels.WARN
    )
end

function M.notify_default_org_not_set()
    local message = "No default org set"
    Debug:log("util.lua", message)
    vim.notify(message, vim.log.levels.ERROR)
end

function M.clear_prompt()
    vim.fn.feedkeys(":", "nx")
end

function M.clear_and_notify(msg, log_level)
    vim.fn.feedkeys(":", "nx")
    vim.notify(msg, log_level)
end

function M.flatten(args)
    local flattened = {}

    -- First, insert all array values (with integer keys)
    for _, v in ipairs(args) do
        -- key here would be 1, 2, 3, etc., so we don't need it
        -- Need to use ipairs here because it preserves order
        table.insert(flattened, v)
    end

    -- Then, insert all key-value pairs
    for k, v in pairs(args) do
        -- order isn't guaranteed here but the key-value pairs will be together
        if type(k) ~= "number" then
            table.insert(flattened, k)
            table.insert(flattened, v)
        end
    end
    return flattened
end

-- recursively search for the file
function M.find_file(path, target)
    local scanner = vim.loop.fs_scandir(path)
    -- if scanner is nil, then path is not a valid dir
    if scanner then
        local file, type = vim.loop.fs_scandir_next(scanner)
        while file do
            if type == "directory" then
                local found = M.find_file(path .. "/" .. file, target)
                if found then
                    return found
                end
            elseif file == target then
                return path .. "/" .. file
            end
            -- get the next file and type
            file, type = vim.loop.fs_scandir_next(scanner)
        end
    end
end

function M.get_metadata_type(filePath)
    for key, metadataType in pairs(metadata_type_map) do
        if filePath:find(key) then
            return metadataType
        end
    end
    return nil
end

function M.get_file_name_without_extension(fileName)
    -- (.-) makes the match non-greedy
    -- see https://www.lua.org/manual/5.3/manual.html#6.4.1
    return fileName:match("(.-)%.%w+%-meta%.xml$") or fileName:match("(.-)%.[^%.]+$")
end

function M.split(inputstr, sep)
    return vim.split(inputstr, sep, { trimempty = true })
end

function M.get_env()
    return {
        HOME = vim.env.HOME,
        PATH = vim.env.PATH,
        HTTP_PROXY = vim.env.HTTP_PROXY,
        HTTPS_PROXY = vim.env.HTTPS_PROXY,
    }
end

local file_monitor = vim.loop.new_fs_event()

local function on_change()
    vim.api.nvim_command("checktime")
    file_monitor:stop()
end

function M.stop_file_monitor()
    file_monitor:stop()
end

function M.watch_file(full_path)
    file_monitor:start(
        full_path,
        {},
        vim.schedule_wrap(function()
            on_change()
        end)
    )
end

function M.salesforce_cli_available()
    local sfdx_available = vim.fn.executable("sfdx")
    local sf_available = vim.fn.executable("sf")
    if sfdx_available == 1 or sf_available == 1 then
        return true
    end
    return false
end

M.send_cli_command = function(args, on_exit_callback, category, caller_name)
    local command = table.concat(args, " ")
    Debug:log(caller_name, "Executing command %s", command)
    local new_job = Job:new({
        command = M.get_sf_executable(),
        env = M.get_env(),
        args = args,
        on_exit = on_exit_callback,
        on_stderr = function(_, data)
            vim.schedule(function()
                Debug:log(caller_name, "Command stderr is: %s", data)
            end)
        end,
    })
    if not M[category] or not M[category].current_job:is_running() then
        M[category] = {}
        M[category].current_job = new_job
        M[category].current_bufnr = vim.api.nvim_get_current_buf()
        M[category].current_job:start()
    else
        M.notify_command_in_progress(category)
    end
end

local function get_apex_ls_namespace()
    local diagnostic_namespaces = vim.diagnostic.get_namespaces()
    for id, ns in pairs(diagnostic_namespaces) do
        if string.find(ns.name, "apex_ls") then
            return id
        end
    end
end

function M.set_error_diagnostics(diagnostics, bufnr)
    local apex_ls_namespace = get_apex_ls_namespace()
    -- filter out overlapping diagnostics from apex_ls
    local filtered_diagnostics = {}
    for _, diagnostic in ipairs(diagnostics) do
        local apex_ls_diagnostics =
            vim.diagnostic.get(bufnr, { namespace = apex_ls_namespace, lnum = diagnostic.lnum })
        local found = false
        for _, apex_ls_diagnostic in ipairs(apex_ls_diagnostics) do
            if apex_ls_diagnostic.message == diagnostic.message then
                found = true
                break
            end
        end
        if not found then
            table.insert(filtered_diagnostics, diagnostic)
        end
    end
    vim.diagnostic.set(namespace, bufnr, filtered_diagnostics, {})
end

function M.clear_error_diagnostics()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.diagnostic.reset(namespace, bufnr)
end

function M.get_sf_executable()
    return vim.fn.fnamemodify(vim.fn.exepath("sf"), ":t")
end

return M
