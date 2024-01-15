local SB = require("salesforce.util.scratch")
local D = require("salesforce.util.debug")

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
    D:log("execute_anon.lua", "Running " .. command .. "...")
    local output = vim.fn.system(command)
    D:log("execute_anon.lua", "Command output is: %s", output)
    D:log("execute_anon.lua", "Adding output to scratch buffer...")
    SB:create_scratch() -- this ensures the same buffer is reused
    SB:write_to_scratch(output)
end

return M
