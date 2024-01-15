local Popup = require("salesforce.popup")
local Job = require("plenary.job")
local Debug = require("salesforce.debug")
local Treesitter = require("salesforce.treesitter")
local Util = require("salesforce.util")

local run_class_command = 'sf apex run test -n "%s" --synchronous -r human'
local run_method_command = 'sf apex run test -t "%s.%s" --synchronous -r human'

local M = {}

local function get_class_info()
    local file_type = vim.fn.expand("%:e")

    if file_type ~= "cls" then
        vim.notify("Not an Apex class file", vim.log.levels.ERROR)
        return
    end

    local method_name = Treesitter:get_current_method_name()
    local class_name = Treesitter:get_current_class_name()

    if not method_name then
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
    Job:new({
        command = "sf",
        args = args,
        on_exit = function(j)
            vim.schedule(function()
                Debug:log("test_runner.lua", "Result from command:")
                Debug:log("test_runner.lua", j:result())
                Popup:write_to_popup(j:result())
            end)
        end,
        on_stderr = function(_, data)
            vim.schedule(function()
                Debug:log("test_runner.lua", "Command stderr is: %s", data)
                Popup:write_to_popup(data)
            end)
        end,
    }):start()
end

M.execute_current_method = function()
    local class_info = get_class_info()

    if not class_info then
        vim.notify("Could not get class/method details", vim.log.levels.ERROR)
        return
    end

    local class_name = class_info.class_name
    local method_name = class_info.method_name

    local command = run_method_command:format(class_name, method_name)
    Popup:create_popup({})
    Popup:write_to_popup(string.format("Executing %s.%s...", class_name, method_name))
    Debug:log("test_runner.lua", "Running command: " .. command)
    execute_job(command)
end

M.execute_current_class = function()
    local class_info = get_class_info()

    if not class_info then
        vim.notify("Could not get class/method details", vim.log.levels.ERROR)
        return
    end

    local class_name = class_info.class_name
    local command = run_class_command:format(class_name)
    Popup:create_popup({})
    Popup:write_to_popup(string.format("Executing %s...", class_name))
    Debug:log("test_runner.lua", "Running command: " .. command)
    execute_job(command)
end

return M
