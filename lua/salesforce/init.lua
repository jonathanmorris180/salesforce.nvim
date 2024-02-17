--- *salesforce.nvim* Plugin for developing Salesforce applications with Neovim
--- *Salesforce*
---
--- MIT License Copyright (c) 2024 Jonathan Morris
---
--- ==============================================================================
---
--- Provides a set of utilities that emulate the commands of the Salesforce
--- extension for VS Code. Out of the box commands include:
--- - `SalesforceExecuteFile`: Execute the current file as anonymous Apex
--- - `SalesforceToggleCommandLineDebug`: Toggle debug logging for the console (this can also be set in |Salesforce.setup|)
--- - `SalesforceToggleLogFileDebug`: Toggle file debug logging (this can also be set in |Salesforce.setup|)
--- - `SalesforceRefreshOrgInfo`: Refresh the org info for the current project
--- - `SalesforceClosePopup`: Close the popup window
--- - `SalesforceRefocusPopup`: Refocus the cursor in the popup window
--- - `SalesforceExecuteCurrentMethod`: Execute the test method under the cursor
--- - `SalesforceExecuteCurrentClass`: Execute all test methods in the current class
--- - `SalesforcePushToOrg`: Push the current file to the org
--- - `SalesforceRetrieveFromOrg`: Pull the current file from the org
--- - `SalesforceDiffFile`: Diff the current file against the file in the org
--- - `SalesforceSetDefaultOrg`: Set the default org for the current project
---
--- # Setup ~
--- To use this plugin, you must first setup your project by running `require("salesforce").setup({})`.
--- You can pass in a lua table of options to customize the plugin. The default options are:
--- >
--- {
---     debug = {
---         to_file = false, -- logs debug messages to a file at vim.fn.stdpath("cache") .. "/salesforce.log"
---         to_command_line = false,
---     },
---     popup = {
---         -- The width of the popup window.
---         width = 100,
---         -- The height of the popup window.
---         height = 20,
---         -- The border characters to use for the popup window
---         borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
---     },
---     file_manager = {
---         ignore_conflicts = false, -- ignores conflicts on "sf project retrieve/deploy"
---     },
---     org_manager = {
---         default_org_indicator = "󰄬",
---     },
---     -- Default SF CLI executable (should not need to be changed)
---     sf_executable = "sf",
--- }
--- <
local Config = require("salesforce.config")

local Salesforce = {}

--- Setup function
---
---@param opts table | nil Module config table. See |Config.options|.
---
---@usage `require("salesforce").setup({})`
function Salesforce.setup(opts)
    Salesforce.config = Config:setup(opts)
end

return Salesforce
