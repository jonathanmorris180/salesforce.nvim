local Popup = require("salesforce.util.popup")
local Debug = require("salesforce.util.debug")

local run_class_command = 'sf apex run test -n "%s" --synchronous -r human'
local run_method_command = 'sf apex run test -t "%s.%s" --synchronous -r human'

local M = {}

M.execute_current_method = function()
    local path = vim.fn.expand("%:p")
    local file_type = vim.fn.expand("%:e")

    if file_type ~= "apex" then
        vim.notify("Not an Apex script file.", vim.log.levels.ERROR)
        return
    end

    local command = "sf apex run -f " .. path
    Debug:log("execute_anon.lua", "Running " .. command .. "...")
    local output = vim.fn.system(command)
    Debug:log("execute_anon.lua", "Command output is: %s", output)
    Debug:log("execute_anon.lua", "Adding output to popup buffer...")
    Popup:create_popup() -- this ensures the same buffer is reused
    Popup:write_to_popup(output)
end

return M
