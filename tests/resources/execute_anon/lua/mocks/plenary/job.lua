local Debug = require("salesforce.debug")
local PlenaryJobMock = {}

local mock_output = vim.fn.readfile("tests/resources/execute_anon/mock-output.txt")

function PlenaryJobMock:new(args)
    Debug:log("Mock plenary.job", "Creating new instance")
    local o = {}
    setmetatable(o, self)
    self.__index = self
    self.on_exit = args.on_exit
    return o
end

function PlenaryJobMock:result()
    return mock_output
end

function PlenaryJobMock:start()
    self.on_exit(self, 0)
end

return PlenaryJobMock
