local Config = require("salesforce.config")

local Salesforce = {}

-- setup Salesforce options and merge them with user provided ones.
function Salesforce.setup(opts)
    Salesforce.config = Config:setup(opts)
end

return Salesforce
