-- You can use this loaded variable to enable conditional parts of your plugin.
if _G.SalesforceLoaded then
    return
end

_G.SalesforceLoaded = true

vim.api.nvim_create_user_command("Salesforce", function()
    require("salesforce").toggle()
end, {})
