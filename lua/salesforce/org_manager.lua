local Job = require("plenary.job")
local Util = require("salesforce.util")
local Debug = require("salesforce.debug")

local OrgManager = {}

function OrgManager:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    self:init()
    return o
end

function OrgManager:parse_orgs(json)
    local results = {}
    for _, orgType in pairs(json.result) do
        for _, org in ipairs(orgType) do
            table.insert(results, {
                alias = org.alias,
                username = org.username,
                connectedStatus = org.connectedStatus,
                isDefaultDevHubUsername = org.isDefaultDevHubUsername,
                isDefaultUsername = org.isDefaultUsername,
            })
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

function OrgManager:init()
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

local org_manager = OrgManager:new()

return org_manager
