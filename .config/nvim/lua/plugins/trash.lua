local function has_multiple_panes_or_splits()
  -- Check for Neovim splits in current tab
  if #vim.api.nvim_tabpage_list_wins(0) > 1 then
    return true
  end
  -- Check for multiple Tmux panes in current window
  if vim.env.TMUX then
    local output = vim.fn.system("tmux display-message -p '#{window_panes}'")
    local panes = tonumber(output:match("%d+")) or 1
    if panes > 1 then
      return true
    end
  end
  return false
end

return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "markdown", "todotxt" },
      auto_install = true,
      highlight = { enable = true },
    },
  },
  {
    "powerman/vim-plugin-ruscmd",
    event = "VeryLazy",
  },
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
      "TmuxNavigatorProcessList",
    },
    keys = {
      { "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
      { "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
      { "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
      { "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
      { "<c-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
      {
        "th",
        function()
          if has_multiple_panes_or_splits() then
            vim.cmd("TmuxNavigateLeft")
          else
            vim.cmd("bprevious")
          end
        end,
        desc = "Navigate Left or Previous Buffer",
      },
      {
        "tl",
        function()
          if has_multiple_panes_or_splits() then
            vim.cmd("TmuxNavigateRight")
          else
            vim.cmd("bnext")
          end
        end,
        desc = "Navigate Right or Next Buffer",
      },
    },
  },
  {
    "xiyaowong/transparent.nvim",
    event = "VeryLazy",
    config = function()
      require("transparent").setup({})
    end,
  },

  {
    "folke/twilight.nvim",
    event = "LazyFile",
    config = function()
      require("twilight").setup({
        throttle = 20,
        context = 5, -- Limit how many lines of context it looks at
      })
    end,
  },
  {
    "folke/zen-mode.nvim",
    event = "BufRead",
    config = function()
      require("zen-mode").setup({
        window = {
          backdrop = 1,
          -- comment this to make it to default
          width = 1, -- width of the Zen window
          height = 1, -- height of the Zen window
          options = {
            signcolumn = "no", -- disable signcolumn
            number = false, -- disable number column
            relativenumber = false, -- disable relative numbers
            -- cursorline = false, -- disable cursorline
            -- cursorcolumn = false, -- disable cursor column
            -- foldcolumn = '0', -- disable fold column
            -- list = false, -- disable whitespace characters
          },
        },
        plugins = {
          -- disable some global vim options (vim.o...)
          options = {
            enabled = true,
            ruler = true, -- disables the ruler text in the cmd line area
            showcmd = false, -- disables the command in the last line of the screen
            -- you may turn on/off statusline in zen mode by setting 'laststatus'
            -- statusline will be shown only if 'laststatus' == 3
            laststatus = 0, -- turn off the statusline in zen mode
          },
          twilight = { enabled = false }, -- enable to start Twilight when zen mode opens
          gitsigns = { enabled = false }, -- disables git signs
          tmux = { enabled = true }, -- disable Tmux integration
        },
      })
    end,
  },
}
