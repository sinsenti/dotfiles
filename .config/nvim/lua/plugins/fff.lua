-- Helper function to validate text before pasting into the live_grep UI
local function is_valid_text(text)
  if not text or text == "" then
    return false
  end

  -- 1. Check line count (if there are 2 or more newlines, it's more than 2 lines)
  local _, line_count = text:gsub("\n", "\n")
  if line_count >= 2 then
    return false
  end

  -- 2. Check character/symbol limit (max 100 characters)
  local max_symbols = 100
  if string.len(text) > max_symbols then
    return false
  end

  return true
end

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
          local clipboard = vim.fn.getreg("+") or ""

          require("fff").live_grep({ cwd = root })

          if is_valid_text(clipboard) then
            clipboard = clipboard:gsub("[\n\r]", " ")
            vim.schedule(function()
              -- Combine the clipboard text and the internal <Esc> key code
              local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
              vim.api.nvim_input(clipboard .. esc)
            end)
          end
        end,
        mode = "n",
        desc = "Grep Workspace (Clipboard Context)",
      },
      {
        "fw",
        function()
          -- 1. Execute a native yank directly into the system clipboard "+" register
          vim.cmd([[normal! "+y]])

          -- 2. Grab the freshly yanked text from the register
          local selection = vim.fn.getreg("+") or ""

          -- 3. Resolve the project root path
          local root = vim.fs.root(0, { ".git" }) or vim.uv.cwd()

          -- 4. Open grep UI in the project root directory
          require("fff").live_grep({ cwd = root })

          -- 5. Send the text string to the prompt and hit Escape (if valid)
          if is_valid_text(selection) then
            selection = selection:gsub("[\n\r]", " ")
            vim.schedule(function()
              local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
              vim.api.nvim_input(selection .. esc)
            end)
          end
        end,
        mode = "v",
        desc = "Grep Workspace (Project Root - Visual Selection to Clipboard)",
      },
      {
        "FW",
        function()
          local clipboard = vim.fn.getreg("+") or ""

          -- Open grep UI in the default directory
          require("fff").live_grep()

          if is_valid_text(clipboard) then
            clipboard = clipboard:gsub("[\n\r]", " ")
            vim.schedule(function()
              local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
              vim.api.nvim_input(clipboard .. esc)
            end)
          end
        end,
        mode = "n",
        desc = "Grep Workspace (Default Dir - Clipboard Context)",
      },
      {
        "FW",
        function()
          -- 1. Execute a native yank directly into the system clipboard "+" register
          vim.cmd([[normal! "+y]])

          -- 2. Grab the freshly yanked text from the register
          local selection = vim.fn.getreg("+") or ""

          -- 3. Open grep UI in the default directory
          require("fff").live_grep()

          -- 4. Send the text string to the prompt and hit Escape (if valid)
          if is_valid_text(selection) then
            selection = selection:gsub("[\n\r]", " ")
            vim.schedule(function()
              local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
              vim.api.nvim_input(selection .. esc)
            end)
          end
        end,
        mode = "v",
        desc = "Grep Workspace (Default Dir - Visual Selection to Clipboard)",
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
