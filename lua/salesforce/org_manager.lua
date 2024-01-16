local Job = require("plenary.job")
local Util = require("salesforce.util")
local Debug = require("salesforce.debug")
local Popup = require("salesforce.popup")
local Config = require("salesforce.config")

local OrgManager = {}

function OrgManager:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    self:get_org_info(false)
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
    for _, org in ipairs(self.orgs) do
        if org.isDefaultUsername then
            return org.alias
        end
    end
end

function OrgManager:get_org_info(add_log)
    if add_log then
        Util.clear_and_notify("Refreshing org info...")
    end
    local command = "sf org list --json"
    Debug:log("org_manager.lua", "Executing command: %s", command)
    local args = Util.split(command, " ")
    table.remove(args, 1)
    Job:new({
        command = "sf",
        args = args,
        on_exit = function(j)
            vim.schedule(function()
                local sfdx_output = j:result()
                sfdx_output = table.concat(sfdx_output)
                Debug:log("org_manager.lua", "Result from command:")
                Debug:log("org_manager.lua", sfdx_output)
                local json_ok, sfdx_response = pcall(vim.json.decode, sfdx_output)
                if not json_ok or not sfdx_response then
                    vim.notify("Failed to parse the SFDX command output", vim.log.levels.ERROR)
                    return
                end
                if add_log then
                    Util.clear_and_notify("Successfully refreshed org info")
                end
                self:parse_orgs(sfdx_response)
            end)
        end,
        on_stderr = function(_, data)
            vim.schedule(function()
                Debug:log("org_manager.lua", "Command stderr is: %s", data)
            end)
        end,
    }):start()
end

function OrgManager:select_org()
    local idx = vim.fn.line(".") - 2
    local org_alias = self.orgs[idx].alias
    local org_username = self.orgs[idx].username
    local command = string.format("sf config set target-org %s --json", org_username)
    Debug:log("org_manager.lua", "Selected org: " .. org_alias)
    Debug:log("org_manager.lua", "Executing command: %s", command)
    local args = Util.split(command, " ")
    table.remove(args, 1)
    Job:new({
        command = "sf",
        args = args,
        on_exit = function(j)
            vim.schedule(function()
                local sfdx_output = j:result()
                sfdx_output = table.concat(sfdx_output)
                Debug:log("org_manager.lua", "Result from command:")
                Debug:log("org_manager.lua", sfdx_output)
                local json_ok, sfdx_response = pcall(vim.json.decode, sfdx_output)
                if not json_ok or not sfdx_response then
                    vim.notify("Failed to parse the SFDX command output", vim.log.levels.ERROR)
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
                        string.format("Successully set target-org to %s", org_alias)
                    )
                    self:get_org_info(true)
                end
            end)
        end,
        on_stderr = function(_, data)
            vim.schedule(function()
                Debug:log("org_manager.lua", "Command stderr is: %s", data)
            end)
        end,
    }):start()
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
        Popup:append_to_popup(string.format("%s (%s) %s", org.alias, org.username, default))
    end
end

local org_manager = OrgManager:new()

return org_manager
