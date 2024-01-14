local helpers = dofile("tests/helpers.lua")

local child = helpers.new_child_neovim()

local T = MiniTest.new_set({
    hooks = {
        -- This will be executed before every (even nested) case
        pre_case = function()
            -- Restart child process with minimal 'init.lua' script
            child.setup()
            child.lua([[M = require("salesforce")]])
            child.lua([[A = require("salesforce.execute_anon")]])
        end,
        -- This will be executed one after all tests from this set are finished
        post_once = child.stop,
    },
})

local mock_output = vim.fn.readfile("tests/resources/execute_anon/mock-output.txt")
mock_output = table.concat(mock_output)
local test_dir = "tests/resources/execute_anon/example.apex"

local mock_system_call = function()
    local mock = string.format(
        [[
        _G.system_orig = _G.system_orig or vim.fn.system
        vim.fn.system = function(...) 
            _G.system_args = {...}
            return "%s" 
        end
        ]],
        mock_output
    )
    child.lua(mock)
end

local get_buf_content = function()
    local buff_content = child.api.nvim_buf_get_lines(0, 0, -1, false)
    return table.concat(buff_content, "\n")
end

T["execute_anon()"] = MiniTest.new_set()

T["execute_anon()"]["displays a mock value in the scratch buffer"] = function()
    mock_system_call()
    child.lua(string.format([[M.setup({debug = %s})]], tostring(helpers.debug())))
    child.cmd(string.format("e %s", test_dir))
    child.bo.filetype = "apex"
    child.lua([[A.execute_anon()]])

    local buff_content = get_buf_content()
    helpers.expect.equality(buff_content, mock_output)
end

return T
