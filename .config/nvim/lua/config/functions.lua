local M = {}

-- =============================================================================
-- 1. MARKDOWN UTILITIES
-- =============================================================================

-- Wrap text with '**' from cursor to Flash target
function M.flash_wrap_markdown_bold()
  local start_win = vim.api.nvim_get_current_win()
  local start_buf = vim.api.nvim_get_current_buf()
  local start_row, start_col = unpack(vim.api.nvim_win_get_cursor(start_win))

  local current_line = vim.api.nvim_get_current_line()
  local word_start_col = start_col
  while word_start_col > 0 and current_line:sub(word_start_col, word_start_col):match("%w") do
    word_start_col = word_start_col - 1
  end
  if not current_line:sub(word_start_col + 1, word_start_col + 1):match("%w") then
    word_start_col = word_start_col + 1
  end

  require("flash").jump({
    continue = false,
    action = function(match)
      local end_row = match.pos[1]
      local end_col = match.pos[2] + 1

      local target_line = vim.api.nvim_buf_get_lines(start_buf, end_row - 1, end_row, false)[1]
      local word_end_col = end_col
      while word_end_col <= #target_line and target_line:sub(word_end_col, word_end_col):match("%w") do
        word_end_col = word_end_col + 1
      end

      vim.api.nvim_buf_set_text(start_buf, end_row - 1, word_end_col - 1, end_row - 1, word_end_col - 1, { "**" })
      vim.api.nvim_buf_set_text(start_buf, start_row - 1, word_start_col, start_row - 1, word_start_col, { "**" })

      local final_col = start_col
      if start_row == end_row and word_start_col <= start_col then
        final_col = start_col + 2
      end

      vim.api.nvim_win_set_cursor(start_win, { start_row, final_col })
    end,
  })
end

function M.align_markdown_table_columns()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1]

  local start_row = cursor_row
  while start_row > 1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, start_row - 2, start_row - 1, false)[1]
    if not line or not line:match("^%s*|") then
      break
    end
    start_row = start_row - 1
  end

  local end_row = cursor_row
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  while end_row <= total_lines do
    local line = vim.api.nvim_buf_get_lines(bufnr, end_row - 1, end_row, false)[1]
    if not line or not line:match("^%s*|") then
      break
    end
    end_row = end_row + 1
  end
  end_row = end_row - 1

  if start_row > end_row then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, end_row, false)
  local table_data = {}
  local col_widths = {}

  for _, line in ipairs(lines) do
    local row_cells = {}
    local clean_line = vim.trim(line):gsub("^|", ""):gsub("|$", "")
    clean_line = vim.trim(clean_line)

    for cell in (clean_line .. "|"):gmatch("(.-)|") do
      table.insert(row_cells, vim.trim(cell))
    end

    -- FIXED REDUNDANCY: Determine if separator row using a single clean regex look ahead
    local is_sep_row = line:match("^%s*|[%s%-%:]*|") ~= nil
    table.insert(table_data, { cells = row_cells, is_separator = is_sep_row })

    if not is_sep_row then
      for i, cell in ipairs(row_cells) do
        col_widths[i] = math.max(col_widths[i] or 0, vim.fn.strdisplaywidth(cell))
      end
    end
  end

  local formatted_lines = {}
  for _, row in ipairs(table_data) do
    local formatted_row = {}
    for i, cell in ipairs(row.cells) do
      local target_width = col_widths[i] or 0
      if row.is_separator then
        table.insert(formatted_row, string.rep("-", target_width + 2))
      else
        local padding = target_width - vim.fn.strdisplaywidth(cell)
        table.insert(formatted_row, " " .. cell .. string.rep(" ", padding) .. " ")
      end
    end
    table.insert(formatted_lines, "|" .. table.concat(formatted_row, "|") .. "|")
  end

  vim.api.nvim_buf_set_lines(bufnr, start_row - 1, end_row, false, formatted_lines)
end

-- =============================================================================
-- 2. TRANSLATOR SCRATCHPAD
-- =============================================================================

function M.translation_scratchpad()
  local buf = vim.api.nvim_create_buf(false, true)

  -- FIXED: Modernized deprecated vim.api.nvim_buf_set_option calls

  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
  vim.api.nvim_buf_set_option(buf, "wrap", true)

  local width = math.min(80, math.floor(vim.o.columns * 0.6))
  local height = math.min(10, math.floor(vim.o.lines * 0.3))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Type Text to Translate ",
    title_pos = "center",
  })

  vim.cmd("startinsert")

  local function process_and_translate()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local full_text = table.concat(lines, " "):gsub("^%s*(.-)%s*$", "%1")

    if full_text == "" then
      return
    end

    local clean_text = full_text:gsub('[%*%_#%-%[%]%(%)%`%"]', " ")
    local first_word = clean_text:match("(%a+)") or clean_text:match("([а-яА-ЯёЁ]+)") or ""

    local is_russian = first_word:match("[а-яА-ЯёЁ]")
    local target_lang = is_russian and "ru:en" or "en:ru"
    local direction_label = is_russian and "RU ➔ EN" or "EN ➔ RU"

    vim.fn.jobstart({ "trans", "-brief", "-no-auto", target_lang, full_text }, {
      stdout_buffered = true,
      on_stdout = function(_, data)
        if data and #data > 0 and data[1] ~= "" then
          local result = table.concat(data, "\n"):gsub("^%s*(.-)%s*$", "%1")
          vim.fn.setreg("+", result)
          vim.fn.setreg('"', result)

          vim.notify(result, vim.log.levels.INFO, {
            title = "Translation (" .. direction_label .. ") [Copied]",
            icon = "󰗊",
          })
        end
      end,
      on_stderr = function(_, data)
        if data and data[1] ~= "" then
          local err_msg = table.concat(data, "\n"):gsub("\27%[[0-9;]*m", ""):gsub("^%s*(.-)%s*$", "%1")
          if #err_msg > 0 then
            vim.notify(err_msg, vim.log.levels.ERROR, { title = "Translation Error" })
          end
        end
      end,
    })
  end

  local triggered = false
  local function safe_trigger_and_close()
    if not triggered then
      triggered = true
      process_and_translate()
    end
    vim.cmd("stopinsert")
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      if not triggered then
        triggered = true
        process_and_translate()
      end
    end,
  })

  vim.keymap.set({ "n" }, "<Esc>", safe_trigger_and_close, { buffer = buf, silent = true })
  vim.keymap.set("n", "q", safe_trigger_and_close, { buffer = buf, silent = true })
end

-- =============================================================================
-- 4. GIT UTILITIES
-- =============================================================================

function M.open_neogit_in_current_dir()
  require("neogit").open({
    cwd = vim.fn.expand("%:p:h"),
    kind = "replace",
  })
end

local function run_git(dir, args)
  local cmd = string.format("git -C %s %s", vim.fn.shellescape(dir), args)
  return vim.fn.system(cmd)
end

function M.show_git_status_noice()
  local current_file_dir = vim.fn.expand("%:p:h")
  if current_file_dir == "" then
    current_file_dir = vim.fn.getcwd()
  end

  local branch = run_git(current_file_dir, "branch --show-current"):gsub("%s+", "")
  if branch == "" or vim.v.shell_error ~= 0 then
    vim.notify("Current file is not inside a git repository", vim.log.levels.WARN, { title = "Git Status" })
    return
  end

  local status_output = run_git(current_file_dir, "status --porcelain=v1")
  if status_output == "" then
    vim.notify(
      "Working directory completely clean\nRepository: " .. branch,
      vim.log.levels.INFO,
      { title = "Git Status" }
    )
    return
  end

  local lines = vim.split(status_output, "\n")
  local staged, unstaged, untracked = {}, {}, {}
  local total_count = 0

  for _, line in ipairs(lines) do
    if line ~= "" then
      total_count = total_count + 1
      local stage_char = line:sub(1, 1)
      local work_char = line:sub(2, 2)
      local file_path = line:sub(4):gsub("^%.%.%/+", "")
      local clean_line = string.format("%s%s %s", stage_char, work_char, file_path)

      if stage_char == "?" and work_char == "?" then
        table.insert(untracked, clean_line)
      elseif stage_char ~= " " and stage_char ~= "?" then
        table.insert(staged, clean_line)
      else
        table.insert(unstaged, clean_line)
      end
    end
  end

  local msg_sections = { string.format(" Branch: %s\nTotal Changes: %d", branch, total_count) }
  if #staged > 0 then
    table.insert(msg_sections, "● Staged Changes:\n" .. table.concat(staged, "\n"))
  end
  if #unstaged > 0 then
    table.insert(msg_sections, "○ Unstaged Changes:\n" .. table.concat(unstaged, "\n"))
  end
  if #untracked > 0 then
    table.insert(msg_sections, "  Untracked Files:\n" .. table.concat(untracked, "\n"))
  end

  vim.notify(table.concat(msg_sections, "\n\n"), vim.log.levels.INFO, { title = "Git Status", timeout = 4000 })
end

function M.git_stash_with_prompt()
  if vim.fn.system("git status --porcelain") == "" then
    vim.notify("Nothing to stash! Working directory is clean.", vim.log.levels.WARN, { title = "Git Stash" })
    return
  end

  vim.ui.input({ prompt = "Stash Message: " }, function(input)
    if not input or input == "" then
      vim.notify("Stash aborted: Empty message", vim.log.levels.INFO, { title = "Git Stash" })
      return
    end

    local output = vim.fn.system(string.format("git stash push -u -m %s", vim.fn.shellescape(input)))
    if vim.v.shell_error == 0 then
      vim.notify("Stashed successfully:\n" .. input, vim.log.levels.INFO, { title = "Git Stash" })
      vim.api.nvim_exec_autocmds("User", { pattern = "NeogitStatusRefreshed" })
    else
      vim.notify("Stash failed:\n" .. output, vim.log.levels.ERROR, { title = "Git Stash" })
    end
  end)
end

function M.git_commit_with_prompt()
  vim.fn.system("git diff --cached --quiet")
  if vim.v.shell_error == 0 then
    vim.notify("No staged changes to commit!", vim.log.levels.WARN, { title = "Git" })
    return
  end

  vim.ui.input({ prompt = "Commit Message: " }, function(input)
    if not input or input == "" then
      vim.notify("Commit aborted: Empty message", vim.log.levels.INFO, { title = "Git" })
      return
    end

    local output = vim.fn.system(string.format("git commit -m %s", vim.fn.shellescape(input)))
    if vim.v.shell_error == 0 then
      vim.notify("Committed successfully:\n" .. input, vim.log.levels.INFO, { title = "Git" })
      vim.api.nvim_exec_autocmds("User", { pattern = "NeogitStatusRefreshed" })
    else
      vim.notify("Commit failed:\n" .. output, vim.log.levels.ERROR, { title = "Git" })
    end
  end)
end

function M.toggle_diffview_branch()
  local has_diffview, diffview_lib = pcall(require, "diffview.lib")
  if has_diffview and next(diffview_lib.views) ~= nil then
    vim.cmd("DiffviewClose")
  else
    require("snacks").picker.git_branches({
      confirm = function(picker, item)
        picker:close()
        if item and item.branch then
          vim.cmd("DiffviewOpen " .. item.branch)
        end
      end,
    })
  end
end

function M.toggle_diffview()
  local has_diffview, diffview_lib = pcall(require, "diffview.lib")
  if has_diffview and next(diffview_lib.views) == nil then
    vim.cmd("DiffviewOpen")
  else
    vim.cmd("DiffviewClose")
  end
end

-- =============================================================================
-- 5. OTHER MISCELLANEOUS SYSTEM UTILITIES
-- =============================================================================

function M.toggle_codeium()
  local has_codeium, codeium_config = pcall(require, "codeium.config")
  if not has_codeium then
    vim.notify("Codeium plugin not found", vim.log.levels.WARN, { title = "Plugins" })
    return
  end

  local vt = codeium_config.options.virtual_text
  vt.manual = not vt.manual
  if vt.manual then
    print("Codeium disabled")
  else
    print("Codeium enabled")
  end
end

function M.strip_buffer_comments()
  local ft = vim.bo.filetype
  if vim.tbl_contains({ "python", "yaml" }, ft) then
    vim.cmd([[g/^\s*#/d]])
    vim.cmd([[%s/#.*//]])
  elseif vim.tbl_contains({ "java", "c", "cpp", "cs", "javascript", "go", "sql" }, ft) then
    vim.cmd([[g@^\s*//@d]])
    vim.cmd([[%s@//.*@@e]])
  else
    vim.notify("Comment stripping not supported for filetype: " .. ft, vim.log.levels.WARN)
  end
end

function M.copy_clean_filepath()
  local filepath = vim.fn.expand("%:p"):gsub("\\", "/"):gsub(" ", "\\ ")
  vim.fn.setreg("+", filepath)
  print("Copied file path to clipboard: " .. filepath)
end

function M.create_obsidian_note()
  local filename = vim.fn.input("Enter note name: ")
  if filename == "" then
    return
  end
  vim.cmd("edit ~/git/obsidian/" .. filename .. ".md")
  vim.cmd("write")
end

function M.compile_and_run_cpp()
  vim.cmd("w")
  local path = vim.fn.expand("%:p:r"):gsub("\\", "/")
  local fileDir = vim.fn.expand("%:p:h")
  local command = string.format("cd %s && clang++ --debug -o %s %s.cpp && %s", fileDir, path, path, path)

  vim.api.nvim_input("<C-/>")
  vim.defer_fn(function()
    vim.api.nvim_put({ command }, "l", true, true)
  end, 100)
end

function M.open_tab_terminal()
  vim.cmd("tabnew | terminal")
  vim.cmd("startinsert")
end

function M.toggle_split_orientation()
  if #vim.api.nvim_tabpage_list_wins(0) ~= 2 then
    print("Toggle only works with exactly 2 windows")
    return
  end
  vim.cmd(vim.fn.winlayout()[1] == "row" and "wincmd K" or "wincmd H")
end

-- Table Map Generator Configuration
function M.generate_markdown_map()
  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  local old_toc_start, old_toc_end = nil, nil
  for i, line in ipairs(lines) do
    if line:match("^##%s+Table%s+of%s+Contents") then
      old_toc_start = (i > 1 and lines[i - 1] == "") and i - 1 or i
      for j = i + 1, #lines do
        if lines[j]:match("^%-%-%-$") then
          old_toc_end = (j < #lines and lines[j + 1] == "") and j + 1 or j
          break
        end
      end
      break
    end
  end

  if old_toc_start and old_toc_end then
    vim.api.nvim_buf_set_lines(buf, old_toc_start - 1, old_toc_end, false, {})
    lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end

  local map_lines = { "", "## Table of Contents", "" }
  for _, line in ipairs(lines) do
    local hashes, heading_text = line:match("^(#+)%s+(.+)$")
    if hashes and heading_text and #hashes >= 2 and heading_text ~= "Table of Contents" then
      local slug = heading_text:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
      table.insert(map_lines, string.format("[%s](#%s)", heading_text, slug))
    end
  end

  table.insert(map_lines, "")
  table.insert(map_lines, "---")
  table.insert(map_lines, "")

  local target_index = 0
  for i, line in ipairs(lines) do
    if line:match("^#%s+") then
      target_index = i
      break
    end
  end

  vim.api.nvim_buf_set_lines(buf, target_index, target_index, false, map_lines)
end

-- File System Clean targets
vim.api.nvim_create_user_command("DeleteFile", function()
  vim.cmd("w")
  local file = vim.fn.expand("%:p")
  if vim.fn.filereadable(file) == 1 then
    vim.fn.delete(file)
  end
  vim.cmd("bdelete")
end, { desc = "Delete the current file and buffer" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "fugitive",
  callback = function()
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = true, silent = true })
  end,
})

-- Big File performance buffer picker
vim.api.nvim_create_user_command("FzfBigOpen", function()
  local fzf = require("fzf-lua")
  fzf.files({
    prompt = "⚡ BigOpen> ",
    actions = {
      ["default"] = function(selected, opts)
        local filepath = ""
        local query = opts.last_query or ""

        if query:match("^/") or query:match("^~") then
          local expanded = vim.fn.expand(query)
          if vim.fn.filereadable(expanded) == 1 then
            filepath = expanded
          end
        end

        if filepath == "" then
          if not selected or #selected == 0 then
            return
          end
          filepath = fzf.path.entry_to_file(selected[1]).path or selected[1]
        end

        if filepath == "" or not filepath then
          return
        end

        vim.g.neovim_loading_bigfile = true
        vim.opt.eventignore:append({ "BufReadPre", "BufReadPost", "FileType" })

        local success, err = pcall(function()
          vim.cmd("edit " .. vim.fn.fnameescape(filepath))
          local buf = vim.api.nvim_get_current_buf()

          vim.opt_local.swapfile = false
          vim.opt_local.undofile = false
          vim.opt_local.foldmethod = "manual"
          vim.opt_local.wrap = false
          vim.opt_local.statuscolumn = ""
          vim.opt_local.relativenumber = false
          vim.opt_local.syntax = "off"

          pcall(vim.treesitter.stop, buf)
          local clients = vim.lsp.get_clients({ bufnr = buf })
          for _, client in ipairs(clients) do
            vim.lsp.buf_detach_client(buf, client.id)
          end
        end)

        vim.opt.eventignore:remove({ "BufReadPre", "BufReadPost", "FileType" })
        vim.g.neovim_loading_bigfile = false

        vim.notify(
          success and "File parsed safely via Fast Raw Mode." or "BigOpen Picker error: " .. tostring(err),
          success and vim.log.levels.INFO or vim.log.levels.ERROR
        )
      end,
    },
  })
end, { desc = "Fuzzy search or open an absolute file path instantly" })

-- Pick command from Zsh History picker
vim.api.nvim_create_user_command("PickFromZshHistory", function()
  local zsh_history_path = vim.fn.expand("~/.zsh_history")
  if vim.fn.filereadable(zsh_history_path) == 0 then
    vim.notify("Could not read .zsh_history file", vim.log.levels.ERROR)
    return
  end

  local lines = vim.fn.readfile(zsh_history_path)
  local processed_commands = {}
  local seen = {}

  for i = #lines, 1, -1 do
    local cmd = lines[i]:gsub("^:%s*%d+:%d+;", ""):match("^%s*(.-)%s*$")
    if cmd and cmd ~= "" and not seen[cmd] then
      table.insert(processed_commands, cmd)
      seen[cmd] = true
    end
  end

  require("fzf-lua").fzf_exec(processed_commands, {
    prompt = "Zsh> ",
    fzf_opts = { ["--no-sort"] = "" },
    actions = {
      ["default"] = function(selected)
        if not selected or #selected == 0 then
          return
        end
        local cmd_to_run = selected[1]
        vim.schedule(function()
          vim.cmd(string.format("split | resize 12 | terminal zsh -i -c %s", vim.fn.shellescape(cmd_to_run)))
          vim.cmd("startinsert")
        end)
      end,
    },
  })
end, { desc = "Zsh Command History" })

return M
