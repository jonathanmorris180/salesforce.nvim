local Salesforce = {}

--- Your plugin configuration with its default values.
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
Salesforce.options = {
    -- Prints useful logs about what event are triggered, and reasons actions are executed.
    debug = false,
}

--- Define your salesforce setup.
---
---@param options table Module config table. See |Salesforce.options|.
---
---@usage `require("salesforce").setup()` (add `{}` with your |Salesforce.options| table)
function Salesforce.setup(options)
    options = options or {}

    Salesforce.options = vim.tbl_deep_extend("keep", options, Salesforce.options)

    return Salesforce.options
end

return Salesforce
