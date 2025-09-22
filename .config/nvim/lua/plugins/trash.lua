return {
  {
    "Thiago4532/mdmath.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      -- Filetypes that the plugin will be enabled by default.
      filetypes = { "markdown" },
      -- Color of the equation, can be a highlight group or a hex color.
      -- Examples: 'Normal', '#ff0000'
      foreground = "Normal",
      -- Hide the text when the equation is under the cursor.
      anticonceal = true,
      -- Hide the text when in the Insert Mode.
      hide_on_insert = true,
      -- Enable dynamic size for non-inline equations.
      dynamic = true,
      -- Configure the scale of dynamic-rendered equations.
      -- dynamic_scale = 1.0,
      dynamic_scale = 0.8,
      -- Interval between updates (milliseconds).
      update_interval = 400,

      -- Internal scale of the equation images, increase to prevent blurry images when increasing terminal
      -- font, high values may produce aliased images.
      -- WARNING: This do not affect how the images are displayed, only how many pixels are used to render them.
      --          See `dynamic_scale` to modify the displayed size.
      internal_scale = 1.0,
    },

    -- The build is already done by default in lazy.nvim, so you don't need
    -- the next line, but you can use the command `:MdMath build` to rebuild
    -- if the build fails for some reason.
    -- build = ':MdMath build'
  },
  {
    "benlubas/molten-nvim",
    lazy = false,
    version = "^1.0.0", -- use version <2.0.0 to avoid breaking changes
    dependencies = { "3rd/image.nvim" },
    build = ":UpdateRemotePlugins",
    init = function()
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
