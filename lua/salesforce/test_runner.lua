local Popup = require("salesforce.popup")
local Job = require("plenary.job")
local OrgManager = require("salesforce.org_manager")
local Debug = require("salesforce.debug")
local Treesitter = require("salesforce.treesitter")
local Util = require("salesforce.util")
local Config = require("salesforce.config")

local executable = Config:get_options().sf_executable
local run_class_command = executable .. ' apex run test -n "%s" --synchronous -r human -o %s'
local run_method_command = executable .. ' apex run test -t "%s.%s" --synchronous -r human -o %s'

local M = {}

local function get_class_info(method_required)
    local file_type = vim.fn.expand("%:e")

    if file_type ~= "cls" then
        vim.notify("Not an Apex class file", vim.log.levels.ERROR)
        return
    end

    local method_name = Treesitter:get_current_method_name()
    local class_name = Treesitter:get_current_class_name()

    if not method_name and method_required then
        vim.notify("Not in a method marked with @isTest", vim.log.levels.ERROR)
        return
    end

    if not class_name then
        vim.notify("Could not parse class name", vim.log.levels.ERROR)
        return
    end

    return { class_name = class_name, method_name = method_name }
end

local function execute_job(command)
    local args = Util.split(command, " ")
    table.remove(args, 1)
    local new_job = Job:new({
        command = executable,
        env = Util.get_env(),
        args = args,
        on_exit = function(j, code)
            vim.schedule(function()
                Debug:log("test_runner.lua", "Command exited with code: %s", code)
                Debug:log("test_runner.lua", "Result from command:")
                Debug:log("test_runner.lua", j:result())
                local trimmed_data = vim.trim(table.concat(j:result()))
                if string.len(trimmed_data) > 0 then
                    Popup:write_to_popup(j:result())
                end
            end)
        end,
        on_stderr = function(_, data)
            vim.schedule(function()
                Debug:log("test_runner.lua", "Command stderr is: %s", data)
                local trimmed_data = vim.trim(data)
                if string.len(trimmed_data) > 0 then
                    Popup:write_to_popup(data)
                end
            end)
        end,
    })

    if not M.current_job or not M.current_job:is_running() then
        M.current_job = new_job
        M.current_job:start()
    else
        Util.notify_command_in_progress("test execution")
    end
end

M.execute_current_method = function()
    local class_info = get_class_info(true)
    local default_username = OrgManager:get_default_username()

    if not default_username then
        Util.notify_default_org_not_set()
        return
    end

    if not class_info then
        vim.notify("Could not get class/method details", vim.log.levels.ERROR)
        return
    end

    local class_name = class_info.class_name
    local method_name = class_info.method_name

    local command = run_method_command:format(class_name, method_name, default_username)
    Popup:create_popup({})
    Popup:write_to_popup(string.format("Executing %s.%s...", class_name, method_name))
    Debug:log("test_runner.lua", "Running command: " .. command)
    execute_job(command)
end

M.execute_current_class = function()
    local class_info = get_class_info(false)
    local default_username = OrgManager:get_default_username()

    if not default_username then
        Util.notify_default_org_not_set()
        return
    end

    if not class_info then
        vim.notify(
            "Could not get class details - please ensure your cursor is inside the class",
            vim.log.levels.ERROR
        )
        return
    end

    local class_name = class_info.class_name
    local command = run_class_command:format(class_name, default_username)
    Popup:create_popup({})
    Popup:write_to_popup(string.format("Executing %s...", class_name))
    Debug:log("test_runner.lua", "Running command: " .. command)
    execute_job(command)
end

return M
