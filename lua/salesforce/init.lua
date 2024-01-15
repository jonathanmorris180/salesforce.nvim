local Config = require("salesforce.config")
local State = require("salesforce.state")

local Salesforce = {}

-- setup Salesforce options and merge them with user provided ones.
function Salesforce.setup(opts)
    Salesforce.config = Config:setup(opts)
end

function Salesforce.toggle()
    State:toggle()
end

-- enable by default
State:enable()

return Salesforce
