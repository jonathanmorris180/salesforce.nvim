local M = require("salesforce.main")
local Salesforce = {}

-- Toggle the plugin by calling the `enable`/`disable` methods respectively.
function Salesforce.toggle()
    -- when the config is not set to the global object, we set it
    if _G.Salesforce.config == nil then
        _G.Salesforce.config = require("salesforce.config").options
    end

    _G.Salesforce.state = M.toggle()
end

-- starts Salesforce and set internal functions and state.
function Salesforce.enable()
    if _G.Salesforce.config == nil then
        _G.Salesforce.config = require("salesforce.config").options
    end

    local state = M.enable()

    if state ~= nil then
        _G.Salesforce.state = state
    end

    return state
end

-- disables Salesforce and reset internal functions and state.
function Salesforce.disable()
    _G.Salesforce.state = M.disable()
end

-- setup Salesforce options and merge them with user provided ones.
function Salesforce.setup(opts)
    _G.Salesforce.config = require("salesforce.config").setup(opts)
end

_G.Salesforce = Salesforce

return _G.Salesforce
