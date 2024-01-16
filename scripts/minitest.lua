local minitest = require("mini.test")

---@diagnostic disable-next-line: undefined-field
if _G.MiniTest == nil then
    minitest.setup()
end
minitest.run()
