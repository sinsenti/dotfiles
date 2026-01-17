return {
  {
    "NeogitOrg/neogit",
    event = "BufRead",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      config = true,
    },
  },
  {
    "tpope/vim-fugitive",
    event = "BufRead",
  },
}
