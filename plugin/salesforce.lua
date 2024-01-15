local Anon = require("salesforce.execute_anon")
local Testrunner = require("salesforce.test_runner")
local Popup = require("salesforce.popup")

vim.api.nvim_create_user_command("SalesfoceExecuteFile", function()
    Anon.execute_anon()
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
