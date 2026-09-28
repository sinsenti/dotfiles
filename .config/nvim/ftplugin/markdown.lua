-- Force manual folds for Markdown files
vim.opt_local.foldmethod = "manual"

vim.keymap.set("n", "tm", require("config.functions.markdown").pick_markdown_heading, {
  buffer = true,
  desc = "Pick Markdown heading",
})
vim.keymap.set("n", "<leader>mh", require("config.functions.markdown").pick_markdown_heading, {
  buffer = true,
  desc = "Pick Markdown heading",
})
