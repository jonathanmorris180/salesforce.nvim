-- You can use this loaded variable to enable conditional parts of your plugin.
print("Loaded salesforce plugin!")
local S = require("salesforce")

vim.api.nvim_create_user_command("Salesforce", function()
    S.toggle()
end, {})
