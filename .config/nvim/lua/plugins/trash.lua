return {
  {
    "benlubas/molten-nvim",
    lazy = false,
    version = "^1.0.0", -- use version <2.0.0 to avoid breaking changes
    dependencies = { "3rd/image.nvim" },
    build = ":UpdateRemotePlugins",
    init = function()
      -- these are examples, not defaults. Please see the readme
      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_output_win_max_height = 20
    end,
  },
  {
    -- see the image.nvim readme for more information about configuring this plugin
    "3rd/image.nvim",
    opts = {
      backend = "kitty", -- whatever backend you would like to use
      max_width = 100,
      max_height = 12,
      max_height_window_percentage = math.huge,
      max_width_window_percentage = math.huge,
      window_overlap_clear_enabled = true, -- toggles images when windows are overlapped
      window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
    },
  },
  -- {
  --   "dccsillag/magma-nvim",
  --   lazy = false,
  --   run = ":UpdateRemotePlugins",
  --   -- config = function()
  --   --   require("magma").setup({
  --   --     automatically_open_output = true,
  --   --     output_window_borders = true,
  --   --     output_window_style = "minimal", -- <--- This fixes the 'style' nil error
  --   --     image_provider = "none", -- or "kitty" / "ueberzug" if supported
  --   --     cell_highlight_group = "Visual",
  --   --     save_path = vim.fn.stdpath("data") .. "/magma",
  --   --     wrap_output = true,
  --   --   })
  --   -- end,
  -- },
  {
    "aveplen/ruscmd.nvim",
    config = true,
  },
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
  },
  -- {
  --   "xiyaowong/transparent.nvim",
  --   lazy = false,
  --   config = function()
  --     require("transparent").setup({})
  --   end,
  -- },

  {
    "folke/twilight.nvim",
    config = function()
      require("twilight").setup({})
    end,
  },
  {
    "folke/zen-mode.nvim",
    event = "BufRead",
    config = function()
      require("zen-mode").setup({
        window = {
          backdrop = 1,
          -- width = 120, -- width of the Zen window
          -- height = 1, -- height of the Zen window
          options = {
            signcolumn = "no", -- disable signcolumn
            number = false, -- disable number column
            relativenumber = false, -- disable relative numbers
            -- cursorline = false, -- disable cursorline
            -- cursorcolumn = false, -- disable cursor column
            -- foldcolumn = '0', -- disable fold column
            -- list = false, -- disable whitespace characters
          },
        },
        plugins = {
          -- disable some global vim options (vim.o...)
          options = {
            enabled = true,
            ruler = true, -- disables the ruler text in the cmd line area
            showcmd = false, -- disables the command in the last line of the screen
            -- you may turn on/off statusline in zen mode by setting 'laststatus'
            -- statusline will be shown only if 'laststatus' == 3
            laststatus = 0, -- turn off the statusline in zen mode
          },
          twilight = { enabled = false }, -- enable to start Twilight when zen mode opens
          gitsigns = { enabled = false }, -- disables git signs
          tmux = { enabled = true }, -- disable Tmux integration
        },
      })
    end,
  },
}
