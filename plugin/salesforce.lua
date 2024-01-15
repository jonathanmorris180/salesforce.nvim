local Anon = require("salesforce.execute_anon")
local Testrunner = require("salesforce.test_runner")
local Popup = require("salesforce.popup")
local FileManager = require("salesforce.file_manager")
local Diff = require("salesforce.diff")
local Config = require("salesforce.config")

vim.api.nvim_create_user_command("SalesfoceExecuteFile", function()
    Anon.execute_anon()
end, {})

vim.api.nvim_create_user_command("SalesforceToggleDebug", function()
    local new_val = not Config:get_options().debug
    Config:get_options().debug = new_val
    vim.notify("Salesforce debugging is " .. (new_val and "enabled" or "disabled"))
end, {})

vim.api.nvim_create_user_command("SalesforceClosePopup", function()
    Popup:close_popup()
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

vim.api.nvim_create_user_command("SalesforcePullFromOrg", function()
    FileManager.pull_from_org()
end, {})

vim.api.nvim_create_user_command("SalesforceDiffFile", function()
    Diff.diff_with_org()
end, {})
