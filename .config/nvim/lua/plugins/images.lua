return {
  {
    "Thiago4532/mdmath.nvim",
    event = "LazyFile",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      filetypes = { "markdown" },
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

      internal_scale = 1.0,
    },
  },
  {
    "benlubas/molten-nvim",
    event = "LazyFile",
    version = "^1.0.0",
    dependencies = { "3rd/image.nvim" },
    build = ":UpdateRemotePlugins",
    init = function()
      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_output_win_max_height = 20
    end,
  },
  {
    "3rd/image.nvim",
    event = "LazyFile",
    opts = {
      backend = "kitty",
      max_width = 100,
      max_height = 12,
      max_height_window_percentage = math.huge,
      max_width_window_percentage = math.huge,
      window_overlap_clear_enabled = true,
      window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
    },
  },
}
