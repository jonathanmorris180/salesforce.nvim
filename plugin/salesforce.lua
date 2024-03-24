local Util = require("salesforce.util")

if not Util.salesforce_cli_available() then
    Util.clear_and_notify("Salesforce CLI not found. Please install it.", vim.log.levels.ERROR)
    return
end

local Anon = require("salesforce.execute_anon")
local Testrunner = require("salesforce.test_runner")
local Popup = require("salesforce.popup")
local FileManager = require("salesforce.file_manager")
local Diff = require("salesforce.diff")
local Config = require("salesforce.config")
local OrgManager = require("salesforce.org_manager")
local Debug = require("salesforce.debug")

Debug:log("salesforce.lua", "Initializing Salesforce plugin commands...")

vim.api.nvim_create_user_command("SalesforceExecuteFile", function()
    Anon.execute_anon()
end, {})

vim.api.nvim_create_user_command("SalesforceToggleCommandLineDebug", function()
    local new_val = not Config:get_options().debug.to_command_line
    Config:get_options().debug.to_command_line = new_val
    vim.notify("Salesforce console debugging is " .. (new_val and "enabled" or "disabled"))
end, {})

vim.api.nvim_create_user_command("SalesforceToggleLogFileDebug", function()
    local new_val = not Config:get_options().debug.to_file
    Config:get_options().debug.to_file = new_val
    vim.notify("Salesforce log file debugging is " .. (new_val and "enabled" or "disabled"))
end, {})

vim.api.nvim_create_user_command("SalesforceRefreshOrgInfo", function()
    Util.clear_and_notify("Refreshing org info...") -- keep this here instead of in function below so that messages aren't overridden after org selection
    OrgManager:get_org_info(true)
end, {})

vim.api.nvim_create_user_command("SalesforceClosePopup", function()
    Popup:close_popup()
end, {})

vim.api.nvim_create_user_command("SalesforceRefocusPopup", function()
    Popup:refocus()
end, {})

vim.api.nvim_create_user_command("SalesforceExecuteCurrentMethod", function()
    Testrunner.execute_current_method()
end, {})

vim.api.nvim_create_user_command("SalesforceExecuteCurrentClass", function()
    Testrunner.execute_current_class()
end, {})

vim.api.nvim_create_user_command("SalesforcePushToOrg", function()
    FileManager.push_to_org()
end, {})

vim.api.nvim_create_user_command("SalesforceRetrieveFromOrg", function()
    FileManager.pull_from_org()
end, {})

vim.api.nvim_create_user_command("SalesforceDiffFile", function()
    Diff.diff_with_org()
end, {})

vim.api.nvim_create_user_command("SalesforceSetDefaultOrg", function()
    OrgManager:set_default_org()
end, {})
