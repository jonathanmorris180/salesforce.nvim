local D = require("salesforce.util.debug")
local State = {}

function State:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    -- default state values
    o.enabled = false
    return o
end

function State:is_enabled()
    return self.enabled
end

---Toggle the plugin by calling the `enable`/`disable` methods respectively.
---@private
function State:toggle()
    if self.enabled then
        return self:disable():log()
    end

    return self:enable():log()
end

function State:log()
    D:log("state.lua", "Salesforce is %s", self.enabled and "enabled" or "disabled")
    return self
end

---Initializes the plugin.
---@private
function State:enable()
    if self.enabled then
        return self
    end

    self.enabled = true

    return self
end

---Disables the plugin and reset the internal state.
---@private
function State:disable()
    if not self.enabled then
        return self
    end

    -- reset the state
    self.enabled = false

    return self
end

local state = State:new()

return state
