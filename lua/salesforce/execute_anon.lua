local Popup = require("salesforce.popup")
local Debug = require("salesforce.debug")
local OrgManager = require("salesforce.org_manager")
local Job = require("plenary.job")
local Util = require("salesforce.util")
local Config = require("salesforce.config")

function Job:is_running()
    if self.handle and not vim.loop.is_closing(self.handle) and vim.loop.is_active(self.handle) then
        return true
    else
        return false
    end
end

local M = {}

M.execute_anon = function()
    Debug:log("execute_anon.lua", "Executing anonymous Apex script...")
    local disallowed_extensions = { "cls", "trigger" }
    local path = vim.fn.expand("%:p")
    local extension = vim.fn.expand("%:e")
    local file_type = vim.bo.filetype
    local default_username = OrgManager:get_default_username()
    local file_contents = ""
    local is_unsaved_buffer = false

    if file_type == "apex" and not vim.tbl_contains(disallowed_extensions, extension) then
        if vim.fn.empty(path) == 1 then
            Debug:log("execute_anon.lua", "File path is empty, retrieving buffer contents...")
            is_unsaved_buffer = true
            local bufnr = vim.api.nvim_get_current_buf()
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            file_contents = vim.fn.join(lines, "\n")
        end
    else
        local message = "Not a valid Apex script"
        Debug:log("execute_anon.lua", message)
        vim.notify(message, vim.log.levels.ERROR)
        return
    end

    if not default_username then
        Util.notify_default_org_not_set()
        return
    end

    Popup:create_popup({})
    Popup:write_to_popup("Executing anonymous Apex script...")
    local executable = Config:get_options().sf_executable
    local args = {}
    local writer = nil
    if not is_unsaved_buffer then
        args = { "apex", "run", "-f", path, "-o", default_username }
        local command =
            string.format("%s apex run -f '%s' -o %s", executable, path, default_username)
        Debug:log("execute_anon.lua", "Running " .. command .. "...")
    else
        writer = file_contents
        args = { "apex", "run", "-o", default_username }
        local command = string.format("%s apex run -o %s", executable, default_username)
        Debug:log("execute_anon.lua", "Piping unsaved buffer contents into " .. command .. "...")
    end
    local new_job = Job:new({
        command = executable,
        env = Util.get_env(),
        args = args,
        writer = writer,
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
                if data then
                    local trimmed_data = vim.trim(data)
                    if string.len(trimmed_data) > 0 then
                        Popup:write_to_popup(data)
                    end
                end
            end)
        end,
    })

    if not M.current_job or not M.current_job:is_running() then
        M.current_job = new_job
        M.current_job:start()
    else
        Util.notify_command_in_progress("script execution")
    end
end

return M
