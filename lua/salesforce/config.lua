local Config = {}

function Config:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    -- default config values
    o.options = {
        debug = {
            to_file = false,
            to_command_line = false,
        },
        popup = {
            -- The width of the popup window.
            width = 100,
            -- The height of the popup window.
            height = 20,
            -- The border characters to use for the popup window
            borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
        },
        file_manager = {
            ignore_conflicts = false,
        },
        org_manager = {
            default_org_indicator = "󰄬",
        },
    }

    return o
end

function Config:get_options()
    return self.options
end

function Config:setup(options)
    options = options or {}
    self.options = vim.tbl_deep_extend("keep", options, self.options)
end

local config = Config:new()

return config
