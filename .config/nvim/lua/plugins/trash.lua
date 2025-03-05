return {
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
  },
  {
    "aveplen/ruscmd.nvim",
    config = true,
  },
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
  },
  {
    "xiyaowong/transparent.nvim",
    lazy = false,
    config = function()
      require("transparent").setup({})
    end,
  },

  {
    "MeanderingProgrammer/markdown.nvim",
    main = "render-markdown",
    event = "BufRead",
    opts = {},
    name = "render-markdown", -- Only needed if you have another plugin named markdown.nvim
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons", "echasnovski/mini.nvim" }, -- if you use the mini.nvim suite
  },
}
