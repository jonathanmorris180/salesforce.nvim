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

local executable = Config:get_options().sf_executable
local active_file_path = nil

local function push_to_org_callback(j)
    vim.schedule(function()
        local sfdx_output = j:result()
        sfdx_output = table.concat(sfdx_output)
        local file_name = vim.fn.fnamemodify(active_file_path, ":t")
        Debug:log("file_manager.lua", "Result from command:")
        Debug:log("file_manager.lua", sfdx_output)

        local json_ok, sfdx_response = pcall(vim.json.decode, sfdx_output)
        if not json_ok or not sfdx_response then
            vim.notify(
                "Failed to parse the 'push to org' SFDX command output",
                vim.log.levels.ERROR
            )
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
                local diagnostics = {}
                local problems = {}
                for _, failure in ipairs(sfdx_response.result.details.componentFailures) do
                    if failure.problem and failure.lineNumber and failure.columnNumber then
                        table.insert(diagnostics, {
                            lnum = failure.lineNumber - 1,
                            col = failure.columnNumber - 1,
                            message = failure.problem,
                            severity = vim.diagnostic.severity.ERROR,
                        })
                    elseif
                        failure.problem
                        and not failure.lineNumber
                        and not failure.columnNumber
                    then
                        table.insert(problems, failure.problem)
                    end
                end
                if #diagnostics > 0 then
                    Util.set_error_diagnostics(diagnostics)
                    vim.notify(
                        string.format(
                            "Error(s) while pushing %s. Check diagnostics. Overlapping messages from apex_ls have been omitted.",
                            file_name
                        ),
                        vim.log.levels.ERROR
                    )
                elseif #problems > 0 and #diagnostics == 0 then
                    vim.notify(
                        string.format(
                            "Error(s) while pushing %s: %s",
                            file_name,
                            table.concat(problems, ", ")
                        ),
                        vim.log.levels.ERROR
                    )
                end
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

local function notify_error_and_stop_monitoring(error)
    vim.notify(error, vim.log.levels.ERROR)
    Util.stop_file_monitor()
end

local function pull_from_org_callback(j)
    vim.schedule(function()
        local sfdx_output = j:result()
        sfdx_output = table.concat(sfdx_output)
        local file_name = vim.fn.fnamemodify(active_file_path, ":t")
        Debug:log("file_manager.lua", "Result from command:")
        Debug:log("file_manager.lua", sfdx_output)

        local json_ok, sfdx_response = pcall(vim.json.decode, sfdx_output)
        if not json_ok or not sfdx_response then
            notify_error_and_stop_monitoring(
                "Failed to parse the 'pull from org' SFDX command output"
            )
            return
        end

        if
            sfdx_response.result
            and sfdx_response.result.files
            and #sfdx_response.result.files > 0
        then
            for _, file in ipairs(sfdx_response.result.files) do
                if file.error then
                    notify_error_and_stop_monitoring(file.error)
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
                    notify_error_and_stop_monitoring(message.problem)
                    return
                end
            end
        elseif sfdx_response.status and sfdx_response.status == 1 and sfdx_response.message then
            notify_error_and_stop_monitoring(sfdx_response.message)
            return
        end

        if
            sfdx_response.result
            and sfdx_response.result.files
            and #sfdx_response.result.files == 0
        then
            notify_error_and_stop_monitoring("No changes to pull")
            return
        end
        Util.clear_and_notify("Pulled " .. file_name .. " successfully!")
    end)
end

local function push(command)
    local args = Util.split(command, " ")
    table.remove(args, 1)
    table.insert(args, "-d")
    table.insert(args, active_file_path)
    local new_job = Job:new({
        command = executable,
        env = Util.get_env(),
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

local function pull(command)
    local args = Util.split(command, " ")
    table.remove(args, 1)
    table.insert(args, "-d")
    table.insert(args, active_file_path)
    Util.watch_file(active_file_path)
    local new_job = Job:new({
        command = executable,
        env = Util.get_env(),
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
    Util.clear_error_diagnostics()
    active_file_path = vim.fn.expand("%:p")
    local file_name = vim.fn.fnamemodify(active_file_path, ":t")
    local default_username = OrgManager:get_default_username()

    if not default_username then
        Util.notify_default_org_not_set()
        return
    end

    Util.clear_and_notify(string.format("Pushing %s to org %s...", file_name, default_username))
    local command =
        string.format("%s project deploy start --json -o %s", executable, default_username)
    if Config:get_options().file_manager.ignore_conflicts then
        Debug:log("file_manager.lua", "Ignoring conflicts becuase of config option")
        command = command .. " --ignore-conflicts"
    end
    Debug:log(
        "file_manager.lua",
        "Command: " .. command .. string.format(" -d '%s'", active_file_path)
    )
    push(command)
end

M.pull_from_org = function()
    Util.clear_error_diagnostics()
    active_file_path = vim.fn.expand("%:p")
    local file_name = vim.fn.fnamemodify(active_file_path, ":t")
    local default_username = OrgManager:get_default_username()

    if not default_username then
        Util.notify_default_org_not_set()
        return
    end

    Util.clear_and_notify(string.format("Pulling %s from org %s...", file_name, default_username))
    local command =
        string.format("%s project retrieve start --json -o %s", executable, default_username)
    if Config:get_options().file_manager.ignore_conflicts then
        Debug:log("file_manager.lua", "Ignoring conflicts becuase of config option")
        command = command .. " --ignore-conflicts"
    end
    Debug:log(
        "file_manager.lua",
        "Command: " .. command .. string.format(" -d '%s'", active_file_path)
    )
    pull(command)
end

return M
