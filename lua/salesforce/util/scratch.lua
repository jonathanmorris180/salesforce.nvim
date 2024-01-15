local C = require("salesforce.config")
local P = require("plenary.popup")

local ScratchBufferCreator = {}

function ScratchBufferCreator:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ScratchBufferCreator:create_scratch()
    if self.bufnr == nil or not vim.api.nvim_buf_is_valid(self.bufnr) then
        if self.bufnr == nil or not vim.api.nvim_buf_is_valid(self.bufnr) then
            self.bufnr = vim.api.nvim_create_buf(false, true)
        end

        -- check if the buffer is already displayed in a window
        local win_found = false
        for _, win_id in pairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_get_buf(win_id) == self.bufnr then
                win_found = true
                break
            end
        end

        -- if not displayed, open it in a vertical split
        if not win_found then
            vim.cmd("vsplit")
            vim.api.nvim_win_set_buf(0, self.bufnr)
        end
    end
end

function ScratchBufferCreator:write_to_scratch(data)
    if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
        -- split data into lines if it's a single string with newlines
        if type(data) == "string" then
            data = vim.split(data, "\n")
        end
        vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, data)
    end
end

function ScratchBufferCreator:clear_scratch()
    if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
        vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})
    end
end

function ScratchBufferCreator:close_scratch()
    if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
        vim.api.nvim_buf_delete(self.bufnr, { force = true })
        self.bufnr = nil
    end
end

local scratch_buffer_creator = ScratchBufferCreator:new()

return scratch_buffer_creator
