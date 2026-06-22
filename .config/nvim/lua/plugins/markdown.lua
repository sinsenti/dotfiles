return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    enabled = true,
    event = "BufRead",
    opts = {
      heading = {
        enabled = false,
      },
      -- '---' symbols
      dash = {
        enabled = false,
      },
      bullet = {
        enabled = false,
      },
      pipe_table = {
        enabled = true,
        preset = "trimmed",
        -- Turn on / off top & bottom lines.
        border_enabled = true,
        -- cell = "raw",

        -- preset =
      },
    },
  },
  {
    "iamcco/markdown-preview.nvim",
    event = "VeryLazy",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    -- ─── SYSTEM-LEVEL COMPILATION BUILD HOOK ───
    build = "cd app && npm install",
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
    end,
  },
}
