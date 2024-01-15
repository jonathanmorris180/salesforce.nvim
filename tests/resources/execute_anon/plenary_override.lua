---@diagnostic disable: different-requires
vim.cmd("set rtp+=tests/resources/execute_anon/")
vim.cmd("set cmdheight=20")
require("plenary.reload").reload_module("plenary.job")
