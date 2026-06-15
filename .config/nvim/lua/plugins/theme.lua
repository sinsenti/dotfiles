return {
  {
    "folke/tokyonight.nvim",
    -- lazy = false,
    -- priority = 1000,
    opts = {
      -- style = "moon", -- Explicitly lock to your preferred moon sub-theme
      on_highlights = function(hl, c)
        -- Map your specific line highlights cleanly inside the theme engine
        hl.CursorLineNr = { fg = "#ffffff", bold = true }
        -- hl.CursorLineNr = { fg = c.blue }
        hl.LineNrAbove = { fg = "#565f89" }
        hl.LineNrBelow = { fg = "#565f89" }
      end,
    },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd([[colorscheme tokyonight-moon]])
    end,
  },
}
