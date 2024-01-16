local Popup = require("salesforce.popup")
local Debug = require("salesforce.debug")
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

    Popup:create_popup({})
    Popup:write_to_popup("Executing anonymous Apex script...")
    local command = "sf apex run -f " .. path
    Debug:log("execute_anon.lua", "Running " .. command .. "...")
    Job:new({
        command = "sf",
        args = { "apex", "run", "-f", path },
        on_exit = function(j, code)
            vim.schedule(function()
                if code == 0 then
                    Debug:log("execute_anon.lua", "Result from command:")
                    Debug:log("execute_anon.lua", j:result())
                    local trimmed_data = vim.trim(table.concat(j:result()))
                    if string.len(trimmed_data) > 0 then
                        Popup:write_to_popup(j:result())
                    end
                end
            end)
        end,
        on_stderr = function(_, data)
            vim.schedule(function()
                Debug:log("execute_anon.lua", "Command stderr is: %s", data)
                local trimmed_data = vim.trim(data)
                if string.len(trimmed_data) > 0 then
                    Popup:write_to_popup(data)
                end
            end)
        end,
    }):start()
end

return M
