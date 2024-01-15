-- Add current directory to 'runtimepath' to be able to use 'lua' files
vim.cmd([[let &rtp.=','.getcwd()]])

-- Set up 'mini.test' and 'mini.doc' only when calling headless Neovim (like with `make test` or `make documentation`)
-- Add 'mini.nvim' to 'runtimepath' to be able to use 'mini.test'
-- Assumed that 'mini.nvim' is stored in 'deps/mini.nvim'
vim.cmd("set rtp+=deps/mini.nvim")
vim.cmd("set rtp+=deps/plenary.nvim")

-- Set up 'mini.test'
require("mini.test").setup()

-- Set up 'mini.doc'
require("mini.doc").setup()
