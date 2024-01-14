local SB = require("salesforce.util.scratch")
local D = require("salesforce.util.debug")

local M = {}

M.execute_anon = function()
    local path = vim.fn.expand("%:p")
    local file_type = vim.fn.expand("%:e")

    if file_type ~= "apex" then
        vim.notify("Not an Apex script file.", vim.log.levels.ERROR)
        return
    end

    local command = "sf apex run -f " .. path
    D:log("Running " .. command .. "...")
    local output = vim.fn.system(command)
    D:log("Adding output to scratch buffer...")
    SB:create_scratch() -- this ensures the same buffer is reused
    SB:write_to_scratch(output)
end

return M
