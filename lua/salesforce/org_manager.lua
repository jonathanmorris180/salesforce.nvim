local Job = require("plenary.job")
local Util = require("salesforce.util")
local Debug = require("salesforce.debug")
local Popup = require("salesforce.popup")
local Config = require("salesforce.config")

function Job:is_running()
    -- avoids textlock (see :h textlock)
    if self.handle and not vim.loop.is_closing(self.handle) and vim.loop.is_active(self.handle) then
        return true
    else
        return false
    end
end

local OrgManager = {}
local executable = Config:get_options().sf_executable

function OrgManager:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function OrgManager:parse_orgs(json)
    local results = {}
    local visited_usernames = {}

    for _, orgType in pairs(json.result) do
        for _, org in ipairs(orgType) do
            if not visited_usernames[org.username] then
                visited_usernames[org.username] = true
                table.insert(results, {
                    alias = org.alias,
                    username = org.username,
                    connectedStatus = org.connectedStatus,
                    isDefaultDevHubUsername = org.isDefaultDevHubUsername,
                    isDefaultUsername = org.isDefaultUsername,
                })
            end
        end
    end
    self.orgs = results
end

function OrgManager:get_default_alias()
    if not self.orgs then
        return
    end
    for _, org in ipairs(self.orgs) do
        if org.isDefaultUsername then
            return org.alias or org.username
        end
    end
end

function OrgManager:get_default_username()
    if not self.orgs then
        return
    end
    for _, org in ipairs(self.orgs) do
        if org.isDefaultUsername then
            return org.username
        end
    end
end

function OrgManager:command_in_progress()
    if self.current_job and self.current_job:is_running() then
        return true
    else
        return false
    end
end

function OrgManager:get_org_info(add_success_message)
    local command = string.format("%s org list --json", executable)
    Debug:log("org_manager.lua", "Executing command: %s", command)
    local args = Util.split(command, " ")
    table.remove(args, 1)
    local new_job = Job:new({
        command = executable,
        args = args,
        on_exit = function(j)
            vim.schedule(function()
                local sfdx_output = j:result()
                sfdx_output = table.concat(sfdx_output)
                Debug:log("org_manager.lua", "Result from command:")
                Debug:log("org_manager.lua", sfdx_output)
                local json_ok, sfdx_response = pcall(vim.json.decode, sfdx_output)
                if not json_ok or not sfdx_response then
                    vim.notify(
                        "Failed to parse the 'org list' SFDX command output",
                        vim.log.levels.ERROR
                    )
                    return
                end
                if add_success_message then
                    Util.clear_and_notify("Successfully refreshed org info")
                end
                self:parse_orgs(sfdx_response)
            end)
        end,
        env = Util.get_env(),
        on_stderr = function(_, data)
            vim.schedule(function()
                Debug:log("org_manager.lua", "Command stderr is: %s", data)
            end)
        end,
    })
    Debug:log(
        "org_manager.lua",
        "Job in progress?: %s",
        tostring(self.current_job and self.current_job:is_running() or "false")
    )
    if not self.current_job or not self.current_job:is_running() then
        self.current_job = new_job
        self.current_job:start()
    else
        Util.notify_command_in_progress("default org")
    end
end

function OrgManager:select_org()
    local idx = vim.fn.line(".") - 2
    local org_alias = self.orgs[idx].alias
    local org_username = self.orgs[idx].username
    local org_alias_or_username = org_alias or org_username
    local command = string.format("%s config set target-org %s --json", executable, org_username)
    Debug:log("org_manager.lua", "Selected org: " .. org_alias_or_username)
    Debug:log("org_manager.lua", "Executing command: %s", command)
    local args = Util.split(command, " ")
    table.remove(args, 1)
    local new_job = Job:new({
        command = executable,
        args = args,
        on_exit = function(j)
            vim.schedule(function()
                local sfdx_output = j:result()
                sfdx_output = table.concat(sfdx_output)
                Debug:log("org_manager.lua", "Result from command:")
                Debug:log("org_manager.lua", sfdx_output)
                local json_ok, sfdx_response = pcall(vim.json.decode, sfdx_output)
                if not json_ok or not sfdx_response then
                    vim.notify(
                        "Failed to parse the 'config set target-org' SFDX command output",
                        vim.log.levels.ERROR
                    )
                    return
                end

                if
                    sfdx_response.result
                    and sfdx_response.result.failures
                    and #sfdx_response.result.failures > 0
                then
                    for _, failure in ipairs(sfdx_response.result.failures) do
                        if failure.message then
                            vim.notify(failure.message, vim.log.levels.ERROR)
                            return
                        end
                    end
                elseif
                    sfdx_response.result
                    and sfdx_response.result.successes
                    and #sfdx_response.result.successes > 0
                then
                    Util.clear_and_notify(
                        string.format(
                            "Successfully set target-org to %s. Refreshing org info...",
                            org_alias_or_username
                        )
                    )
                    self:get_org_info(true)
                end
            end)
        end,
        env = Util.get_env(),
        on_stderr = function(_, data)
            vim.schedule(function()
                Debug:log("org_manager.lua", "Command stderr is: %s", data)
            end)
        end,
    })
    Debug:log(
        "org_manager.lua",
        "Job in progress?: %s",
        tostring(self.current_job and self.current_job:is_running() or "false")
    )
    if not self.current_job or not self.current_job:is_running() then
        self.current_job = new_job
        self.current_job:start()
    else
        Util.notify_command_in_progress("default org")
    end
    Popup:close_popup()
end

function OrgManager:set_default_org()
    local default_org_indicator = Config:get_options().org_manager.default_org_indicator
    if not self.orgs then
        vim.notify("No orgs available", vim.log.levels.ERROR)
        return
    end

    Popup:create_popup({ number = true, allow_selection = true })
    Popup:write_to_popup("Select an org:\n")

    for _, org in ipairs(self.orgs) do
        local default = org.isDefaultUsername and default_org_indicator or ""
        Popup:append_to_popup(
            string.format("%s (%s) %s", org.alias or "NO ALIAS SET", org.username, default)
        )
    end
end

local org_manager = OrgManager:new()

return org_manager
