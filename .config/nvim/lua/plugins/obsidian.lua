return {
  "epwalsh/obsidian.nvim",
  version = "*",
  event = "VeryLazy",
  -- ft = "markdown",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "ibhagwan/fzf-lua",
    "hrsh7th/nvim-cmp",
    "nvim-treesitter",
  },
  config = function()
    require("obsidian").setup({
      -- disable_frontmatter = false,
      --to open obsidian by :ObsdianOpen
      -- use_advanced_uri = true,
      open_app_foreground = true,
      follow_url_func = function(url)
        -- Open the URL in the default web browser on Linux
        vim.fn.jobstart({ "xdg-open", url })
      end,

      workspaces = {
        {
          name = "obsidian",
          path = "~/git/obsidian",
        },
      },
      daily_notes = {
        date_format = "%d-%m-%Y",
        default_tags = { "daily-notes" },
      },
      templates = {
        folder = "~/git/obsidian/Templates",
        date_format = "%d-%m-%y",
        time_format = "%H:%M",
      },
      ui = {
        enable = true,
        checkboxes = {
          -- [' '] = { char = '󰄱', hl_group = 'ObsidianTodo' },
          -- ['x'] = { char = '', hl_group = 'ObsidianDone' },
          -- ['~'] = { char = '󰰱', hl_group = 'ObsidianTilde' },
          -- ['!'] = { char = '', hl_group = 'ObsidianImportant' },
          [" "] = { char = "☐", hl_group = "ObsidianTodo" },
          ["x"] = { char = "", hl_group = "ObsidianDone" },
          -- ['>'] = { char = '', hl_group = 'ObsidianRightArrow' },
        },
        hl_groups = {
          ObsidianTodo = { bold = true, fg = "#13ff00" },
          ObsidianDone = { bold = true, fg = "#89ddff" },
          ObsidianRightArrow = { bold = true, fg = "#f78c6c" },
          ObsidianTilde = { bold = true, fg = "#ff5370" },
          ObsidianImportant = { bold = true, fg = "#d73128" },
          ObsidianBullet = { bold = true, fg = "#89ddff" },
          ObsidianRefText = { underline = true, fg = "#c792ea" },
          ObsidianExtLinkIcon = { fg = "#c792ea" },
          ObsidianTag = { italic = true, fg = "#89ddff" },
          ObsidianBlockID = { italic = true, fg = "#89ddff" },
          ObsidianHighlightText = { bg = "#75662e" },
        },
      },
    })
    -- vim.keymap.set("n", "<leader>ov", ":ObsidianOpen<CR>", { noremap = true, silent = true })
    -- vim.keymap.set('n', '<leader>on', ':ObsidianNew', {})
    -- vim.keymap.set("n", "<leader>or", ":ObsidianRename", {})
    -- vim.keymap.set("n", "<leader>oi", ":ObsidianPasteImg<CR>", {})

    -- vim.keymap.set("n", "<leader>oo", ":Obsidian", {})
    vim.keymap.set("n", "<leader>of", ":ObsidianQuickSwitch<CR>", { noremap = true, silent = true })
    vim.keymap.set("n", "<leader>og", ":ObsidianSearch<CR>", { desc = "Find words", noremap = true, silent = true })
    vim.keymap.set("n", "<leader>ol", ":ObsidianLinks<CR>", { noremap = true, silent = true })
    vim.keymap.set("n", "<leader>ob", ":ObsidianBacklinks<CR>", { noremap = true, silent = true })
    vim.keymap.set("n", "<leader>ot", ":ObsidianNewFromTemplate", {})
    vim.keymap.set("n", "<leader>ot", function()
      vim.api.nvim_feedkeys(":ObsidianNewFromTemplate ", "n", false)
      vim.schedule(function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(".md<Left><Left><Left>", true, false, true), "t", false)
      end)
    end, { noremap = true, silent = true, desc = "Create new note from template" })

    function ToggleCheckbox()
      local line = vim.api.nvim_get_current_line()
      if line:find("%[x%]") then
        line = line:gsub("%[x%]", "[ ]", 1)
      else
        line = line:gsub("%[ ]", "[x]", 1)
      end
      vim.api.nvim_set_current_line(line)
    end

    -- vim.api.nvim_set_keymap('n', '<leader>ot', ':lua ToggleCheckbox()<CR>', { noremap = true, silent = true, desc = ' Toggle checkbox' })
  end,
}
