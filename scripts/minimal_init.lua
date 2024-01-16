-- Add current directory to 'runtimepath' to be able to use 'lua' files
local cwd = vim.fn.getcwd()
vim.opt.runtimepath:append(cwd)
vim.opt.runtimepath:append(cwd .. "/deps/mini.nvim")
vim.opt.runtimepath:append(cwd .. "/deps/plenary.nvim")
vim.opt.runtimepath:append(cwd .. "/deps/nvim-treesitter")
vim.cmd("set cmdheight=20")

-- Set up 'mini.test' and 'mini.doc' only when calling headless Neovim (like with `make test` or `make documentation`)
-- Add 'mini.nvim' to 'runtimepath' to be able to use 'mini.test'
-- Assumed that 'mini.nvim' is stored in 'deps/mini.nvim'

-- Set up 'mini.test'
require("mini.test").setup()

-- Set up 'mini.doc'
require("mini.doc").setup()
