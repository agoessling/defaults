local M = {}

M.config = function()
  vim.g.gruvbox_material_foreground = 'material'
  vim.g.gruvbox_material_background = 'soft'
  vim.g.gruvbox_material_enable_italic = 1
  vim.g.gruvbox_material_better_performance = 1

  vim.cmd([[colorscheme gruvbox-material]])
end

return M
