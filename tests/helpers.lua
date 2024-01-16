-- partially imported from https://github.com/echasnovski/mini.nvim
local Helpers = {}

-- Add extra expectations
Helpers.expect = vim.deepcopy(MiniTest.expect)

local function error_message(str, pattern)
    return string.format("Pattern: %s\nObserved string: %s", vim.inspect(pattern), str)
end

-- Check equality of a config `prop` against `value` in the given `child` process.
-- @usage config_equality(child, "debug", true)
Helpers.expect.config_equality = MiniTest.new_expectation(
    "config option matches",
    function(child, prop, value)
        return Helpers.expect.equality(
            child.lua_get(string.format('C:get_options()["%s"]', prop)),
            value
        )
    end,
    error_message
)

-- Check type equality of a config `prop` against `value` in the given `child` process.
-- @usage config_type_equality(child, "debug", "boolean")
Helpers.expect.config_type_equality = MiniTest.new_expectation(
    "config option type matches",
    function(child, prop, value)
        return Helpers.expect.equality(
            child.lua_get(string.format('type(C:get_options()["%s"])', prop)),
            value
        )
    end,
    error_message
)

Helpers.expect.match = MiniTest.new_expectation("string matching", function(str, pattern)
    return str:find(pattern) ~= nil
end, error_message)

Helpers.expect.no_match = MiniTest.new_expectation("no string matching", function(str, pattern)
    return str:find(pattern) == nil
end, error_message)

Helpers.debug = function()
    local debug_val = vim.loop.os_environ()["DEBUG"]
    return debug_val == "true"
end

-- Monkey-patch `MiniTest.new_child_neovim` with helpful wrappers
Helpers.new_child_neovim = function()
    local child = MiniTest.new_child_neovim()

    child.setup = function()
        child.restart({ "-u", "scripts/minimal_init.lua" })

        -- Change initial buffer to be readonly. This not only increases execution
        -- speed, but more closely resembles manually opened Neovim.
        child.bo.readonly = false
    end

    child.set_lines = function(arr, start, finish)
        if type(arr) == "string" then
            arr = vim.split(arr, "\n")
        end

        child.api.nvim_buf_set_lines(0, start or 0, finish or -1, false, arr)
    end

    child.get_lines = function(start, finish)
        return child.api.nvim_buf_get_lines(0, start or 0, finish or -1, false)
    end

    child.set_cursor = function(line, column, win_id)
        child.api.nvim_win_set_cursor(win_id or 0, { line, column })
    end

    child.get_cursor = function(win_id)
        return child.api.nvim_win_get_cursor(win_id or 0)
    end

    child.set_size = function(lines, columns)
        if type(lines) == "number" then
            child.o.lines = lines
        end

        if type(columns) == "number" then
            child.o.columns = columns
        end
    end

    child.get_size = function()
        return { child.o.lines, child.o.columns }
    end

    child.expect_screenshot = function(opts, path, screenshot_opts)
        if child.fn.has("nvim-0.8") == 0 then
            MiniTest.skip("Screenshots are tested for Neovim>=0.8 (for simplicity).")
        end

        MiniTest.expect.reference_screenshot(child.get_screenshot(screenshot_opts), path, opts)
    end

    return child
end

return Helpers
