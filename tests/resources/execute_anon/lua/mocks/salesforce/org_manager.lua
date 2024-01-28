local MockOrgManager = {}

function MockOrgManager:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function MockOrgManager:get_default_username()
    return "test@username.com"
end

return MockOrgManager
