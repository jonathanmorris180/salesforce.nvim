local Debug = require("salesforce.debug")

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

function M.clear_and_notify(msg, log_level)
    vim.fn.feedkeys(":", "nx")
    vim.notify(msg, log_level)
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

local function get_apex_ls_namespace()
    local diagnostic_namespaces = vim.diagnostic.get_namespaces()
    for id, ns in pairs(diagnostic_namespaces) do
        if string.find(ns.name, "apex_ls") then
            return id
        end
    end
end

function M.set_error_diagnostics(diagnostics)
    local apex_ls_namespace = get_apex_ls_namespace()
    local bufnr = vim.api.nvim_get_current_buf()
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

return M
