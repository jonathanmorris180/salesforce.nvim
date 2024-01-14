local C = require("salesforce.config")
local Debugger = {}

function Debugger:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    self.store_logs = false
    self.logs = {}
    return o
end

function Debugger:toggle_store_logs()
    self.store_logs = not self.store_logs
end

function Debugger:get_logs()
    return self.logs
end

---prints only if debug is true.
---
---@param scope string: the scope from where this function is called.
---@param str string: the formatted string.
---@param ... any: the arguments of the formatted string.
---@private
function Debugger:log(scope, str, ...)
    if not C:get_options().debug then
        return
    end

    local info = debug.getinfo(2, "Sl")
    local line = ""

    if info then
        line = "L" .. info.currentline
    end

    local debug_str = string.format(
        "[salesforce:%s %s in %s] > %s",
        os.date("%H:%M:%S"),
        line,
        scope,
        select("#", ...) == 0 and str or string.format(str, ...)
    )
    self:log_str(debug_str)
end

function Debugger:log_str(debug_str)
    print(debug_str)
    if self.store_logs then
        table.insert(self.logs, debug_str)
    end
end

---prints the table if debug is true.
---
---@param table table: the table to print.
---@param indent number?: the default indent value, starts at 0.
---@private
function Debugger:tprint(table, indent)
    if not C:get_options().debug then
        return
    end

    if not indent then
        indent = 0
    end

    for k, v in pairs(table) do
        local formatting = string.rep("  ", indent) .. k .. ": "
        if type(v) == "table" then
            self:log_str(formatting)
            self:tprint(v, indent + 1)
        elseif type(v) == "boolean" then
            self:log_str(formatting .. tostring(v))
        elseif type(v) == "function" then
            self:log_str(formatting .. "FUNCTION")
        else
            self:log_str(formatting .. v)
        end
    end
end

local debugger = Debugger:new()

return debugger
