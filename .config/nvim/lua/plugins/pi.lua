return {
  {
    "zgs225/pi2.nvim",
    version = "v1.5.6",
    cmd = {
      "Pi",
      "PiContinue",
      "PiResume",
      "PiNewTab",
      "PiNewSession",
      "PiToggleChat",
      "PiToggleLayout",
      "PiAbort",
      "PiStop",
      "PiAttention",
      "PiTree",
      "PiFork",
      "PiClone",
      "PiSessions",
      "PiSubNew",
      "PiSubSwitch",
      "PiSubParent",
      "PiSubClose",
      "PiSubView",
      "PiDiff",
      "PiSendMention",
      "PiAttachImage",
      "PiPasteImage",
      "PiCompact",
      "PiSessionName",
      "PiSelectModel",
      "PiCycleModel",
      "PiSelectThinking",
      "PiCycleThinking",
      "PiToggleThinking",
      "PiToggleAutoCompaction",
      "PiToggleDebug",
    },
    dependencies = {
      "MeanderingProgrammer/render-markdown.nvim",
      "HakonHarnes/img-clip.nvim",
    },
    opts = {
      layout = {
        default = "side",
        side = {
          position = "right",
          width = 72,
        },
      },
      reload = {
        -- Reload unmodified buffers and report skipped modified buffers.
        mode = "notify",
      },
      -- Leave project trust disabled initially. `--approve` trusts local
      -- .pi resources; it is not an edit-approval mechanism.
    },
    keys = {
      { "<leader>ii", "<cmd>Pi<cr>", mode = { "n", "v" }, desc = "Pi chat" },
      { "<leader>ic", "<cmd>PiSendMention<cr>", mode = { "n", "v" }, desc = "Send context to Pi" },
      { "<leader>ir", "<cmd>PiResume<cr>", mode = { "n", "v" }, desc = "Resume Pi session" },
      { "<leader>is", "<cmd>PiSessions<cr>", desc = "Pi sessions" },
      { "<leader>id", "<cmd>PiDiff<cr>", desc = "Review Pi changes" },
      { "<leader>in", "<cmd>PiNewSession<cr>", desc = "New Pi session" },
      { "<leader>ix", "<cmd>PiAbort<cr>", desc = "Abort Pi" },
      { "<leader>iP", "<cmd>PiPasteImage<cr>", mode = { "n", "v" }, desc = "Paste image into Pi" },
    },
    config = function(_, opts)
      require("pi").setup(opts)
    end,
  },
}
