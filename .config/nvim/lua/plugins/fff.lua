return {
  {
    "dmtrKovalenko/fff.nvim",
    cmd = { "FFFind", "FFGrep" },
    build = function()
      require("fff.download").download_or_build_binary()
    end,
    opts = {
      prompt_vim_mode = true,
      prompt = " ",
      preview = {
        line_numbers = true,
      },
      keymaps = {
        select_split = "<C-v>",
        select_vsplit = "<C-s>",
        move_up = { "<Up>", "<C-p>" }, -- default
        move_down = { "<Down>", "<C-n>" }, -- default
      },
      grep = {
        modes = { "regex", "fuzzy", "plain" },
      },
      layout = {
        height = 1.0,
        width = 1.0,
        preview_size = 0.65,
      },
      git = {
        status_text_color = false, -- default
      },
      debug = {
        enabled = false,
        show_scores = false,
        show_file_info = {
          file_info = true, -- size, type, git status, frecency
          score_breakdown = true, -- total + match type, bonuses, modifiers, penalty
          timings = false,
          full_path = false,
        },
      },
    },
    keys = {
      {
        "<leader><space>",
        function()
          -- Automatically finds the project root directory
          local root = vim.fs.root(0, { ".git" }) or vim.uv.cwd()
          require("fff").find_files({ cwd = root })
        end,
        desc = "Find Files (Project Root)",
      },
      {
        "ff",
        function()
          require("fff").find_files()
        end,
        desc = "Find Files (fff)",
      },
      {
        "fw",
        function()
          local root = vim.fs.root(0, { ".git" }) or vim.uv.cwd()
          require("fff").live_grep({ cwd = root })
        end,
        desc = "Grep Workspace (Project Root)",
      },
      {
        "FW",
        function()
          require("fff").live_grep()
        end,
        desc = "Grep Workspace (default  directory)",
      },

      {
        "fW",
        function()
          local root = vim.fs.root(0, { ".git" }) or vim.uv.cwd()
          require("fff").live_grep({
            cwd = root,
            query = vim.fn.expand("<cword>"),
          })
        end,
        desc = "Search Current Word (Project Root)",
      },
    },
  },
}
