local M = {}

M.set_options = function()
  -- Appearance
  vim.o.showbreak = '↪'
  vim.o.showmode = false
  vim.o.wrap = true
  vim.o.ruler = false
  vim.o.number = true
  vim.o.cursorline = true
  vim.o.colorcolumn = '+1'

  -- Wildcard and search
  vim.opt.wildmode = {'longest', 'list', 'full'}
  vim.o.hlsearch = true
  vim.o.ignorecase = true
  vim.o.smartcase = true
  vim.o.incsearch = true

  -- Formatting
  vim.o.expandtab = true
  vim.o.shiftwidth = 2
  vim.o.softtabstop = 2
  vim.o.textwidth = 100
  vim.o.scrolloff = 3
  vim.g.python_recommended_style = 0

  -- Keymaps
  vim.keymap.set('x', 'p', '"_c<Esc>p', { noremap = true })

  -- Mouse
  vim.o.mouse = nil
end

return M
