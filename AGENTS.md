# AGENTS.md - Development Guide for AI Coding Agents

This file contains essential information for AI coding agents working on salesforce.nvim, a Neovim plugin for Salesforce development.

## Project Overview

**Language:** Lua (Neovim plugin)  
**Purpose:** Salesforce development tooling for Neovim  
**Dependencies:** plenary.nvim (async/jobs), nvim-treesitter (Apex parsing), mini.nvim (testing)

## Build, Lint, and Test Commands

### Available Make Targets
```bash
make test           # Run all tests using mini.nvim test framework
make test-debug     # Run tests with DEBUG=1 for verbose output
make test-ci        # Install dependencies and run tests (CI)
make lint           # Format code with stylua
make deps           # Install test dependencies (mini.nvim, plenary.nvim, nvim-treesitter)
make documentation  # Generate documentation using mini.doc
```

### Running Tests
- **All tests:** `make test`
- **Single test:** Not directly supported. Tests are collected from `tests/` directory by `scripts/minitest.lua`
- **Debug mode:** `make test-debug` or `DEBUG=1 make test`
- **Test files location:** `tests/*.lua` (currently only `test_config.lua` and `test_execute_anon.lua`)

### Linting
- **Format code:** `make lint`
- **Check formatting:** `stylua --check .`
- Configuration in `stylua.toml`

## Code Style Guidelines

### Formatting (stylua.toml)
- **Indentation:** 4 spaces (no tabs)
- **Line width:** 100 characters
- **Quotes:** Double quotes preferred
- **Call parentheses:** Always required (no_call_parentheses = false)

### Import/Require Conventions
```lua
-- External dependencies first
local Job = require("plenary.job")

-- Internal modules second (alphabetical order)
local Config = require("salesforce.config")
local Debug = require("salesforce.debug")
local Util = require("salesforce.util")

-- Module table
local M = {}
```

### Module Structure Patterns

**Singleton Pattern (preferred for stateful modules):**
```lua
local ModuleName = {}

function ModuleName:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

local instance = ModuleName:new()
return instance
```

**Simple Module Pattern (for stateless utilities):**
```lua
local M = {}

M.function_name = function()
    -- implementation
end

return M
```

### Naming Conventions
- **Functions/Methods:** snake_case (e.g., `execute_anon`, `push_to_org`)
- **Local functions:** snake_case, defined before module table
- **Methods:** Use colon syntax `:` for OOP (e.g., `Config:setup()`, `Debug:log()`)
- **Callbacks:** Suffix with `_callback` (e.g., `push_to_org_callback`)
- **Constants:** UPPER_SNAKE_CASE (rare, usually in config)
- **Private functions:** Local functions or prefixed with underscore

### Error Handling Patterns

**Early Returns for Validation:**
```lua
if not default_username then
    Util.notify_default_org_not_set()
    return
end
```

**pcall for External Data Parsing:**
```lua
local json_ok, sfdx_response = pcall(vim.json.decode, sfdx_output)
if not json_ok or not sfdx_response then
    vim.notify("Failed to parse SFDX response", vim.log.levels.ERROR)
    return
end
```

**vim.schedule for Async UI Operations:**
```lua
vim.schedule(function()
    -- operations that modify UI/buffers
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end)
```

### Documentation Style

Use **EmmyLua/LuaCATS annotations** for all public functions:

```lua
--- Execute anonymous Apex code from visual selection or entire buffer
---
---@param opts table | nil Options table
---   - debug: boolean - Enable debug mode
---@return nil
---@usage `require("salesforce.execute_anon").execute()`
function M.execute_anon(opts)
    -- implementation
end
```

**Documentation sections:**
- Module header with brief description
- Function description (one line summary)
- `@param` for each parameter with type and description
- `@return` for return values
- `@usage` for usage examples
- `@private` for internal functions

### Common Patterns

**Job Management (prevent concurrent jobs):**
```lua
if not M.current_job or not M.current_job:is_running() then
    M.current_job = Job:new({
        command = "sf",
        args = args,
        on_exit = callback,
    })
    M.current_job:start()
else
    Util.notify_command_in_progress("operation_name")
end
```

**Extended Job:is_running():**
```lua
function Job:is_running()
    if self.handle and not vim.loop.is_closing(self.handle) and vim.loop.is_active(self.handle) then
        return true
    else
        return false
    end
end
```

**User Command Creation:**
```lua
vim.api.nvim_create_user_command("SalesforceCommand", function()
    require("salesforce.module").function()
end, {})
```

**Config Access:**
```lua
local options = Config:get_options()
local value = options.section.option
```

**Debug Logging:**
```lua
Debug:log("filename.lua", "Message with %s", format_arg)
```

## Testing Guidelines

### Test Structure (mini.test framework)
```lua
local helpers = dofile("tests/helpers.lua")
local child = helpers.new_child_neovim()

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.setup()
            child.lua([[M = require("salesforce")]])
        end,
        post_once = child.stop,
    },
})

T["module_function()"] = MiniTest.new_set()
T["module_function()"]["handles valid input"] = function()
    -- Arrange
    local input = "test"
    
    -- Act
    local result = child.lua_get([[M.function("test")]])
    
    -- Assert
    MiniTest.expect.equality(result, expected)
end

return T
```

### Mocking Strategy
- Override modules using `package.loaded`: `package.loaded["module"] = mock`
- Mock plenary.job for CLI commands (see `tests/resources/execute_anon/plenary_override.lua`)
- Use `vim.schedule` mocks to avoid async issues in tests
- Test resources in `tests/resources/` directory

## Key Architecture Notes

- **Entry point:** `lua/salesforce/init.lua` (setup function)
- **Commands:** Defined in `plugin/salesforce.lua` (auto-loaded)
- **Job execution:** All Salesforce CLI commands via plenary.job
- **Popup display:** Custom popup module for output windows
- **File monitoring:** Uses `vim.loop.new_fs_event()` for watching files
- **Treesitter integration:** Parses Apex code to find test methods/classes
- **Config:** Singleton pattern with deep merge for user options

## Common Pitfalls

1. **Async operations:** Always wrap buffer/UI modifications in `vim.schedule()`
2. **Job management:** Check if job is running before starting new one
3. **Module requires:** Avoid circular dependencies; use lazy loading if needed
4. **Test isolation:** Each test should be independent; use `pre_case` hooks
5. **Error messages:** Use appropriate `vim.log.levels` (ERROR, WARN, INFO)
6. **CLI output:** Always parse JSON with `pcall(vim.json.decode, output)`

## Contributing Checklist

- [ ] Run `make lint` before committing
- [ ] Add tests for new functionality (follow existing test patterns)
- [ ] Update documentation strings with EmmyLua annotations
- [ ] Regenerate docs with `make documentation` if public API changed
- [ ] Follow singleton or simple module patterns consistently
- [ ] Use `Debug:log()` for debugging, not `print()` or `vim.notify()`
- [ ] Ensure proper error handling with early returns and user notifications
