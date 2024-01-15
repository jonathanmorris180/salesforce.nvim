local Popup = require("salesforce.util.popup")
local Debug = require("salesforce.util.debug")
local Job = require("plenary.job")

local M = {}

M.execute_anon = function()
    Debug:log("execute_anon.lua", "Executing anonymous Apex script...")
    local path = vim.fn.expand("%:p")
    local file_type = vim.fn.expand("%:e")

    if file_type ~= "apex" then
        vim.notify("Not an Apex script file.", vim.log.levels.ERROR)
        return
    end

    Popup:create_popup()
    Popup:write_to_popup("Executing anonymous Apex script...")
    local command = "sf apex run -f " .. path
    Debug:log("execute_anon.lua", "Running " .. command .. "...")
    Job:new({
        command = "sf",
        args = { "apex", "run", "-f", path },
        on_exit = function(j)
            vim.schedule(function()
                Debug:log("execute_anon.lua", "Result from command:")
                Debug:log("execute_anon.lua", j:result())
                Popup:write_to_popup(j:result())
            end)
        end,
        on_stderr = function(_, data)
            vim.schedule(function()
                Debug:log("execute_anon.lua", "Command stderr is: %s", data)
                Popup:write_to_popup(data)
            end)
        end,
    }):start()
end

return M
