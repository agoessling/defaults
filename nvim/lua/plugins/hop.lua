local M = {}

M.config = function()
  local hop = require('hop')
  hop.setup { keys = 'etovxqpdygfblzhckisuran' }
  vim.keymap.set({ 'n', 'v', 'o' }, 'f', hop.hint_char2)
end

return M
