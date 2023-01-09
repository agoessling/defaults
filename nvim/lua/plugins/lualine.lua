local M = {}

M.config = function()
  require('lualine').setup {
    options = {
      theme = 'gruvbox-material'
    },
    sections = {
      lualine_c = {
        {
          'filename',
          file_status = true,
          path = 1,
        },
      },
    },
  }
end

return M
