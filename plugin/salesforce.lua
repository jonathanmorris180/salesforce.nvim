-- You can use this loaded variable to enable conditional parts of your plugin.
local S = require("salesforce")
local A = require("salesforce/execute_anon")

vim.api.nvim_create_user_command("SalesforceToggle", function()
    S.toggle()
end, {})

vim.api.nvim_create_user_command("SfdxExecuteFile", function()
    A.execute_anon()
end, {})
