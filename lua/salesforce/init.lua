local C = require("salesforce.config")
local S = require("salesforce.state")
local Salesforce = {}

-- setup Salesforce options and merge them with user provided ones.
function Salesforce.setup(opts)
    Salesforce.config = C:setup(opts)
end

function Salesforce.toggle()
    S:toggle()
end

-- enable by default
S:enable()

return Salesforce
