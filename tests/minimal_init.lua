-- tests/minimal_init.lua

vim.opt.rtp:prepend('.')
vim.opt.rtp:prepend(vim.fn.expand('./deps/plenary.nvim'))

require('nvim-leetcode').setup()
