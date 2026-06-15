return {
  "coder/claudecode.nvim",
  opts = {},
  keys = {
    -- { "<leader>a", "", desc = "+ai", mode = { "n", "v" } },
    { "<leader>qc", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
    { "<leader>qf", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
    { "<leader>qr", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
    { "<leader>qC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
    { "<leader>qb", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
    -- { "<leader>aa", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
    -- {
    --   "<leader>as",
    --   "<cmd>ClaudeCodeTreeAdd<cr>",
    --   desc = "Add file",
    --   ft = { "NvimTree", "neo-tree", "oil" },
    -- },
    -- Diff management
    { "<leader>qa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
    { "<leader>qD", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
  },
}
