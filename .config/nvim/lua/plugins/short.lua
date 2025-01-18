return {
  {
    'folke/todo-comments.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {
      keywords = {
        TODO = { icon = ' ', color = 'info' },
        FIXME = { icon = ' ', color = 'error' },
        HACK = { icon = ' ', color = 'warning' },
        NOTE = { icon = ' ', color = 'hint' },
      },
      keys = {
        -- { '<leader>ft', '<cmd>TodoTelescope<CR>', desc = 'Find TODOs with Telescope' },
        { '<leader>tl', '<cmd>TodoQuickFix<CR>',  desc = 'List TODOs in quickfix' },
      },
    }

  },

  {
    'preservim/vim-pencil',
  },

  {
    'tpope/vim-obsession',
  },


  {
    'tpope/vim-surround',
  },

  {
    'windwp/nvim-autopairs',
    config = function()
      require('nvim-autopairs').setup {
        check_ts = true,
        fast_wrap = {},
      }
    end,
  },

  {
    'catppuccin/nvim',
    name = 'catppuccin',
    config = function()
      vim.cmd.colorscheme('catppuccin')
    end,
  },

  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    vscode = true,
  opts = { },
    keys = {
      { '<leader>s', mode = { 'n', 'x', 'o' }, function() require('flash').jump() end,              desc = 'Flash' },
      { '<leader>S', mode = { 'n', 'o', 'x' }, function() require('flash').treesitter() end,        desc = 'Flash Treesitter' },
      { 'r',         mode = 'o',               function() require('flash').remote() end,            desc = 'Remote Flash' },
      { 'R',         mode = { 'o', 'x' },      function() require('flash').treesitter_search() end, desc = 'Treesitter Search' },
      { '<c-s>',     mode = { 'c' },           function() require('flash').toggle() end,            desc = 'Toggle Flash Search' },
    },
  },

  {
    'numToStr/Comment.nvim',
    event = { 'BufRead', 'BufNewFile' },
    config = function()
      require('Comment').setup()
    end,
  },

  {
    'xiyaowong/transparent.nvim',
    lazy = false,
    config = function()
      require('transparent').setup({
      })
    end,
  },

  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    keys = {
      {
        '<leader>?',
        function()
          require('which-key').show({ global = false })
        end,
        desc = 'Buffer Local Keymaps (which-key)',
      },
    },
  },
  {
    'NeogitOrg/neogit',
    lazy = false,
    event = 'BufRead',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'sindrets/diffview.nvim',
      'nvim-telescope/telescope.nvim',
      config = true,
    },
  },

}
