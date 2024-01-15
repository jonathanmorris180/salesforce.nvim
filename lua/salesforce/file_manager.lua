local Config = require("salesforce.config")
local Job = require("plenary.job")
local Debug = require("salesforce.debug")
local Util = require("salesforce.util")

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
            vim.notify(sfdx_response.message, vim.log.levels.ERROR)
            return
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
            and #sfdx_respons.result.messages > 0
        then
            for _, message in ipairs(sfdx_response.result.messages) do
                if message.problem then
                    vim.notify(message.problem, vim.log.levels.ERROR)
                    return
                end
            end
        end
        vim.cmd("e!")
        Util.clear_and_notify("Pulled " .. file_name .. " successfully!")
    end)
end

local function push(command)
    local args = Util.split(command, " ")
    table.remove(args, 1)
    Job:new({
        command = "sf",
        args = args,
        on_exit = push_to_org_callback,
        on_stderr = function(_, data)
            vim.schedule(function()
                Debug:log("file_manager.lua", "Command stderr is: %s", data)
            end)
        end,
    }):start()
end

local function pull(command)
    local args = Util.split(command, " ")
    table.remove(args, 1)
    Job:new({
        command = "sf",
        args = args,
        on_exit = pull_from_org_callback,
        on_stderr = function(_, data)
            vim.schedule(function()
                Debug:log("file_manager.lua", "Command stderr is: %s", data)
            end)
        end,
    }):start()
end

M.push_to_org = function()
    local path = vim.fn.expand("%:p")
    local file_name = vim.fn.expand("%:t")

    Util.clear_and_notify("Pushing " .. file_name .. " to the org...")
    local command = string.format("sf project deploy start -d %s --json", path)
    Debug:log("Command: " .. command)
    push(command)
end

M.pull_from_org = function()
    local path = vim.fn.expand("%:p")
    local file_name = vim.fn.expand("%:t")

    Util.clear_and_notify("Pulling " .. file_name .. " from the org...")
    local command = string.format("sf project retrieve start -d %s --json", path)
    Debug:log("Command: " .. command)
    if Config:get_options().file_manager.ignore_conflicts then
        Debug:log("file_manager.lua", "Ignoring conflicts becuase of config option")
        command = command .. " --ignore-conflicts"
    end
    pull(command)
end

return M
