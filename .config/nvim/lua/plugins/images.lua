return {
  {
    "Thiago4532/mdmath.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      filetypes = { "markdown" },
      foreground = "Normal",
      anticonceal = true,
      hide_on_insert = true,
      dynamic = true,
      dynamic_scale = 0.8,
      update_interval = 400,
      internal_scale = 1.0,
    },
    config = function(_, opts)
      -- 1. Safely initialize mdmath setup options
      require("mdmath").setup(opts)

      -- 2. Intercept the background parser pipeline to protect against dead picker previews
      local overlay = pcall(require, "mdmath.overlay") and require("mdmath.overlay")
      if overlay and overlay.parse then
        local original_parse = overlay.parse
        overlay.parse = function(bufnr, ...)
          -- ONLY run treesitter parsing if the buffer handle is alive and valid
          if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
            pcall(original_parse, bufnr, ...)
          end
        end
      end
    end,
  },
  -- {
  --   "benlubas/molten-nvim",
  --   event = "LazyFile",
  --   version = "^1.0.0",
  --   dependencies = { "3rd/image.nvim" },
  --   build = ":UpdateRemotePlugins",
  --   init = function()
  --     vim.g.molten_image_provider = "image.nvim"
  --     vim.g.molten_output_win_max_height = 20
  --   end,
  -- },
  {
    "3rd/image.nvim",
    event = "VeryLazy",
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
