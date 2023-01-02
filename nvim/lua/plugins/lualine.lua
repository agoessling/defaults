local M = {}

M.config = function()
  require('lualine').setup {
    options = {
      theme = 'gruvbox-material'
    }
  }
end

return M
