-- Download and bootstrap package manager (Packer)
local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

-- Specify plugins.
require('packer').startup(function(use)
  use 'wbthomason/packer.nvim'

  -- Plugins go here
  use {
    'sainnhe/gruvbox-material',
    config = function() require('plugins/gruvbox-material').config() end,
  }

  use {
    'nvim-lualine/lualine.nvim',
    requires = { 'kyazdani42/nvim-web-devicons', opt = true },
    config = function() require('plugins/lualine').config() end,
  }

  use {
    'nvim-telescope/telescope.nvim',
    branch = '0.1.x',
    requires = { 'nvim-lua/plenary.nvim' },
    config = function() require('plugins/telescope').config() end,
  }

  use {
    'nvim-treesitter/nvim-treesitter',
    run = function()
      local ts_update = require('nvim-treesitter.install').update({ with_sync = true })
      ts_update()
    end,
    config = function() require('plugins/treesitter').config() end,
  }

  use {
    'numToStr/Comment.nvim',
    config = function() require('Comment').setup() end
  }

  use {
    'phaazon/hop.nvim',
    branch = 'v2',
    config = function() require('plugins/hop').config() end,
  }

  use { 'tpope/vim-fugitive' }

  use {
    'neovim/nvim-lspconfig',
    config = function() require('plugins/lspconfig').config() end,
  }

  use { 'ntpeters/vim-better-whitespace' }

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if packer_bootstrap then
    require('packer').sync()
  end
end)

require('options').set_options()
