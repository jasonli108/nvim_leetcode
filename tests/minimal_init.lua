-- tests/minimal_init.lua

vim.opt.rtp:prepend('.')
vim.opt.rtp:prepend(vim.fn.expand('~/.local/share/nvim/site/pack/packer/start/plenary.nvim'))

require('nvim-leetcode').setup()
