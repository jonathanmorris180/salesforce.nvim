local helpers = dofile("tests/helpers.lua")
local Debug = require("salesforce.debug")

-- See https://github.com/echasnovski/mini.nvim/blob/main/lua/mini/test.lua for more documentation

local child = helpers.new_child_neovim()
local eq_config = helpers.expect.config_equality
local eq_type_config = helpers.expect.config_type_equality

local T = MiniTest.new_set({
    hooks = {
        -- This will be executed before every (even nested) case
        pre_case = function()
            -- Restart child process with minimal 'init.lua' script
            child.setup()
            child.lua([[M = require("salesforce")]])
            child.lua([[C = require("salesforce.config")]])
        end,
        -- This will be executed one after all tests from this set are finished
        post_once = child.stop,
    },
})

-- Tests related to the `setup` method.
T["setup()"] = MiniTest.new_set()

T["setup()"]["sets exposed methods and default options value"] = function()
    Debug:log("test_config.lua", "setup() test")
    child.lua([[M.setup()]])

    -- global object that holds your plugin information
    eq_type_config(child, "debug", "boolean")
    eq_config(child, "debug", false)
end

T["setup()"]["overrides default values"] = function()
    child.lua([[M.setup({
        debug = true,
    })]])

    -- assert the value, and the type
    eq_type_config(child, "debug", "boolean")
    eq_config(child, "debug", true)
end

return T
