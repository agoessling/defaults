local M = {}

M.config = function()
  require('nvim-treesitter.configs').setup {
    ensure_installed = { 'bash', 'cpp', 'vim', 'lua', 'help', 'c', 'python' },
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = false,
    },
    indent = {
      enable = true,
      disable = { 'python' },
    },
  }
end

return M
