local Config = require("salesforce.config")
local Debug = require("salesforce.debug")
local Popop = require("plenary.popup")

local PopupManager = {}

function PopupManager:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function PopupManager:create_window()
    Debug:log("popup.lua", "Creating popup window")
    local config = Config:get_options().popup
    local width = config.width or 80
    local height = config.height or 15
    local borderchars = config.borderchars
    self.bufnr = vim.api.nvim_create_buf(false, true)

    local win_id = Popop.create(self.bufnr, {
        title = "Salesforce",
        line = math.floor(((vim.o.lines - height) / 2) - 1),
        col = math.floor((vim.o.columns - width) / 2),
        minwidth = width,
        minheight = height,
        borderchars = borderchars,
    })

    return win_id
end

function PopupManager:create_popup(args)
    if self.win_id and self.bufnr then
        return
    end

    self.win_id = self:create_window()

    vim.api.nvim_buf_set_option(self.bufnr, "bufhidden", "delete")
    vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)
    vim.api.nvim_buf_set_name(self.bufnr, "Salesforce popup")
    if args and args.number then
        vim.api.nvim_win_set_option(self.win_id, "number", true)
    end
    vim.api.nvim_buf_set_keymap(
        self.bufnr,
        "n",
        "q",
        "<cmd>lua require('salesforce.popup'):close_popup()<CR>",
        { noremap = true, silent = true }
    )
    vim.api.nvim_buf_set_keymap(
        self.bufnr,
        "n",
        "<esc>",
        "<cmd>lua require('salesforce.popup'):close_popup()<CR>",
        { noremap = true, silent = true }
    )
    vim.api.nvim_buf_set_keymap(
        self.bufnr,
        "n",
        "<CR>",
        "<cmd>lua require('salesforce.org_manager'):select_org()<CR>",
        {}
    )
end

function PopupManager:append_to_popup(data)
    if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
        -- split data into lines if it's a single string with newlines
        vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
        if type(data) == "string" then
            data = vim.split(data, "\n")
        end
        vim.api.nvim_buf_set_lines(self.bufnr, -1, -1, false, data)
        vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)
    end
end

function PopupManager:write_to_popup(data)
    if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
        -- split data into lines if it's a single string with newlines
        vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
        if type(data) == "string" then
            data = vim.split(data, "\n")
        end
        vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, data)
        vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)
    end
end

function PopupManager:clear_popup()
    if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
        vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
        vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})
        vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)
    end
end

function PopupManager:get_win_id()
    return self.win_id
end

function PopupManager:close_popup()
    Debug:log("popup.lua", "Closing Salesforce popup")
    Debug:log("popup.lua", "win_id is %s", tostring(self.win_id))
    if self.win_id and vim.api.nvim_win_is_valid(self.win_id) then
        vim.api.nvim_win_close(self.win_id, { force = true })
        self.bufnr = nil
        self.win_id = nil
    end
end

local popup_manager = PopupManager:new()

return popup_manager
