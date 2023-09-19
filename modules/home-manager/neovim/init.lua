
--- underline errors rather than highlight
vim.lsp.handlers['textDocument/publishDiagnostics'] = vim.lsp.with(
  vim.lsp.diagnostic.on_publish_diagnostics, {
    underline = true,
    ---virtual_text = true,
    signs = true,
    update_in_insert = true,
    float = true,
  }
)

vim.o.termguicolors = true
vim.o.syntax = 'on'
vim.o.errorbells = false
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.fixendofline = false
vim.bo.autoindent = true
vim.bo.smartindent = true

vim.o.mouse = 'a'
vim.o.showmode = false
vim.o.number = true
vim.o.relativenumber = true
vim.wo.signcolumn = "yes"

vim.o.tabstop = 2
vim.o.softtabstop = 2
vim.o.shiftwidth = 2
vim.o.expandtab = true

vim.g.mapleader = ' '

local key_mapper = function(mode, key, result)
  vim.api.nvim_set_keymap(
    mode,
    key,
    result,
    {noremap = true, silent = true}
  )
end

--- pane navig
key_mapper('n', '<leader>h', '<C-w>h')
key_mapper('n', '<leader>j', '<C-w>j')
key_mapper('n', '<leader>k', '<C-w>k')
key_mapper('n', '<leader>l', '<C-w>l')

--- exit term
key_mapper('t', '<Esc>', '<C-\\><C-n>')
