local Config = require("salesforce.config")
local OrgManager = require("salesforce.org_manager")
local Job = require("plenary.job")
local Debug = require("salesforce.debug")
local Util = require("salesforce.util")

function Job:is_running()
    if self.handle and not vim.loop.is_closing(self.handle) and vim.loop.is_active(self.handle) then
        return true
    else
        return false
    end
end

local M = {}

local function push_to_org_callback(j)
    vim.schedule(function()
        local sfdx_output = j:result()
        sfdx_output = table.concat(sfdx_output)
        local file_name = vim.fn.expand("%:t")
        Debug:log("file_manager.lua", "Result from command:")
        Debug:log("file_manager.lua", sfdx_output)

        local json_ok, sfdx_response = pcall(vim.json.decode, sfdx_output)
        if not json_ok or not sfdx_response then
            vim.notify("Failed to parse the SFDX command output", vim.log.levels.ERROR)
            return
        end

        if
            sfdx_response.result
            and sfdx_response.result.deployedSource
            and #sfdx_response.result.deployedSource > 0
        then
            for _, source in ipairs(sfdx_response.result.deployedSource) do
                if source.error then
                    vim.notify(source.error, vim.log.levels.ERROR)
                    return
                end
            end
        elseif sfdx_response.status and sfdx_response.status == 1 then
            if
                sfdx_response.result
                and sfdx_response.result.details
                and sfdx_response.result.details.componentFailures
            then
                local failures = {}
                for _, failure in ipairs(sfdx_response.result.details.componentFailures) do
                    if failure.problem then
                        table.insert(failures, failure.problem)
                    end
                end
                vim.notify("Error(s) while pushing " .. file_name, vim.log.levels.ERROR)
                vim.notify(table.concat(failures, "\n"), vim.log.levels.ERROR)
                return
            elseif sfdx_response.message then
                vim.notify(sfdx_response.message, vim.log.levels.ERROR)
                return
            end
        elseif sfdx_response.status and sfdx_response.status == 0 then
            Util.clear_and_notify("Pushed " .. file_name .. " successfully!")
            return
        end
        vim.notify("Unknown error", vim.log.levels.ERROR)
    end)
end

local function pull_from_org_callback(j)
    vim.schedule(function()
        local sfdx_output = j:result()
        sfdx_output = table.concat(sfdx_output)
        local file_name = vim.fn.expand("%:t")
        Debug:log("file_manager.lua", "Result from command:")
        Debug:log("file_manager.lua", sfdx_output)

        local json_ok, sfdx_response = pcall(vim.json.decode, sfdx_output)
        if not json_ok or not sfdx_response then
            vim.notify("Failed to parse the SFDX command output", vim.log.levels.ERROR)
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
                    return
                end
            end
        elseif sfdx_response.status and sfdx_response.status == 1 and sfdx_response.message then
            vim.notify(sfdx_response.message, vim.log.levels.ERROR)
            return
        end

        if
            sfdx_response.result
            and sfdx_response.result.files
            and #sfdx_response.result.files == 0
        then
            vim.notify("No changes to pull", vim.log.levels.ERROR)
            return
        end
        vim.cmd("e!")
        Util.clear_and_notify("Pulled " .. file_name .. " successfully!")
    end)
end

local function push(command, path)
    local args = Util.split(command, " ")
    table.remove(args, 1)
    table.insert(args, "-d")
    table.insert(args, path)
    local new_job = Job:new({
        command = "sf",
        env = { HOME = vim.env.HOME, PATH = vim.env.PATH },
        args = args,
        on_exit = push_to_org_callback,
        on_stderr = function(_, data)
            vim.schedule(function()
                Debug:log("file_manager.lua", "Command stderr is: %s", data)
            end)
        end,
    })

    if not M.current_job or not M.current_job:is_running() then
        M.current_job = new_job
        M.current_job:start()
    else
        Util.notify_command_in_progress("push/pull")
    end
end

local function pull(command, path)
    local args = Util.split(command, " ")
    table.remove(args, 1)
    table.insert(args, "-d")
    table.insert(args, path)
    local new_job = Job:new({
        command = "sf",
        env = { HOME = vim.env.HOME, PATH = vim.env.PATH },
        args = args,
        on_exit = pull_from_org_callback,
        on_stderr = function(_, data)
            vim.schedule(function()
                Debug:log("file_manager.lua", "Command stderr is: %s", data)
            end)
        end,
    })

    if not M.current_job or not M.current_job:is_running() then
        M.current_job = new_job
        M.current_job:start()
    else
        Util.notify_command_in_progress("push/pull")
    end
end

M.push_to_org = function()
    local path = vim.fn.expand("%:p")
    local file_name = vim.fn.expand("%:t")
    local default_username = OrgManager:get_default_username()

    if not default_username then
        Util.notify_default_org_not_set()
        return
    end

    Util.clear_and_notify(string.format("Pushing %s to org %s...", file_name, default_username))
    local command = string.format("sf project deploy start --json -o %s", default_username)
    Debug:log("file_manager.lua", "Command: " .. command .. string.format(" -d '%s'", path))
    push(command, path)
end

M.pull_from_org = function()
    local path = vim.fn.expand("%:p")
    local file_name = vim.fn.expand("%:t")
    local default_username = OrgManager:get_default_username()

    if not default_username then
        Util.notify_default_org_not_set()
        return
    end

    Util.clear_and_notify(string.format("Pulling %s from org %s...", file_name, default_username))
    local command = string.format("sf project retrieve start --json -o %s", default_username)
    if Config:get_options().file_manager.ignore_conflicts then
        Debug:log("file_manager.lua", "Ignoring conflicts becuase of config option")
        command = command .. " --ignore-conflicts"
    end
    Debug:log("file_manager.lua", "Command: " .. command .. string.format(" -d '%s'", path))
    pull(command, path)
end

return M
