local Util = require("salesforce.util")
local Job = require("plenary.job")
local Debug = require("salesforce.debug")
local OrgManager = require("salesforce.org_manager")
local Config = require("salesforce.config")

function Job:is_running()
    if self.handle and not vim.loop.is_closing(self.handle) and vim.loop.is_active(self.handle) then
        return true
    else
        return false
    end
end

local M = {}

local temp_dir

local function diff_callback(j)
    vim.schedule(function()
        local sfdx_output = j:result()
        local file_name = vim.fn.expand("%:t")
        sfdx_output = table.concat(sfdx_output)
        Debug:log("diff.lua", "Result from command:")
        Debug:log("diff.lua", sfdx_output)

        local json_ok, sfdx_response = pcall(vim.json.decode, sfdx_output)
        if not json_ok or not sfdx_response then
            vim.notify("Failed to parse the SFDX command output", vim.log.levels.ERROR)
            vim.fn.delete(temp_dir, "rf")
            return
        end

        if
            sfdx_response.result
            and sfdx_response.result.files
            and #sfdx_response.result.files > 0
        then
            for _, file in ipairs(sfdx_response.result.files) do
                if file.error then
                    vim.notify(file.error, vim.log.levels.ERROR)
                    vim.fn.delete(temp_dir, "rf")
                    return
                end
            end
        elseif
            sfdx_response.result
            and sfdx_response.result.messages
            and #sfdx_response.result.messages > 0
        then
            for _, message in ipairs(sfdx_response.result.messages) do
                if message.problem then
                    vim.notify(message.problem, vim.log.levels.ERROR)
                    vim.fn.delete(temp_dir, "rf")
                    return
                end
            end
        end

        local retrieved_file_path = Util.find_file(temp_dir, file_name)
        Debug:log("diff.lua", "Temp file path: " .. (retrieved_file_path or "Not found"))

        if not retrieved_file_path or not vim.fn.filereadable(retrieved_file_path) then
            vim.notify("Failed to retrieve the file from the org", vim.log.levels.ERROR)
            vim.fn.delete(temp_dir, "rf")
            return
        end

        Util.clear_and_notify("Diffing " .. file_name)
        vim.cmd("vert diffsplit " .. retrieved_file_path)
        vim.fn.delete(temp_dir, "rf")
    end)
end

local function execute_job(command)
    local args = Util.split(command, " ")
    table.remove(args, 1)
    local new_job = Job:new({
        command = Config:get_options().sf_executable,
        args = args,
        on_exit = diff_callback,
        env = { HOME = vim.env.HOME, PATH = vim.env.PATH },
        on_stderr = function(_, data)
            vim.schedule(function()
                Debug:log("diff.lua", "Command stderr is: %s", data)
            end)
        end,
    })
    if not M.current_job or not M.current_job:is_running() then
        M.current_job = new_job
        M.current_job:start()
    end
end

M.diff_with_org = function()
    if M.current_job and M.current_job:is_running() then
        -- needs to be here or temp dir will be overwritten
        Util.notify_command_in_progress("diff with org")
        return
    end
    local path = vim.fn.expand("%:p")
    local file_name = vim.fn.expand("%:t")
    local file_name_no_ext = Util.get_file_name_without_extension(file_name)
    local metadataType = Util.get_metadata_type(path)
    local default_username = OrgManager:get_default_username()

    if metadataType == nil then
        vim.notify("Not a supported metadata type.", vim.log.levels.ERROR)
        return
    end

    if default_username == nil then
        Util.notify_default_org_not_set()
        return
    end

    Util.clear_and_notify(string.format("Diffing %s with org %s...", file_name, default_username))
    temp_dir = vim.fn.tempname()
    local temp_dir_with_suffix = temp_dir .. "/main/default"
    vim.fn.mkdir(temp_dir_with_suffix, "p")
    Debug:log("diff.lua", "Created temp dir: " .. temp_dir)

    local sf = Config:get_options().sf_executable
        .. " project retrieve start -m %s:%s -r %s -o %s --json"

    local command = string.format(sf, metadataType, file_name_no_ext, temp_dir, default_username)
    Debug:log("diff.lua", "Command: " .. command)
    execute_job(command)
end

return M
