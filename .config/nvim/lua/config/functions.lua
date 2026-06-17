local M = {}

-- INFO: Git functions

-- Open Neogit in active directory
function M.open_neogit_in_current_dir()
  require("neogit").open({
    cwd = vim.fn.expand("%:p:h"),
    kind = "replace",
  })
end

-- Helper to run commands relative to a specific directory
local function run_git(dir, args)
  local cmd = string.format("git -C %s %s", vim.fn.shellescape(dir), args)
  return vim.fn.system(cmd)
end

function M.show_git_status_noice()
  -- 1. Get the directory of the currently open file buffer
  local current_file_dir = vim.fn.expand("%:p:h")
  if current_file_dir == "" then
    current_file_dir = vim.fn.getcwd()
  end

  -- 2. Grab current branch name & look for errors
  local branch = run_git(current_file_dir, "branch --show-current"):gsub("%s+", "")
  if branch == "" or vim.v.shell_error ~= 0 then
    vim.notify("Current file is not inside a git repository", vim.log.levels.WARN, { title = "Git Status" })
    return
  end

  -- 3. Grab porcelain status payload
  local status_output = run_git(current_file_dir, "status --porcelain=v1")
  if status_output == "" then
    vim.notify(
      "Working directory completely clean\nRepository: " .. branch,
      vim.log.levels.INFO,
      { title = "Git Status" }
    )
    return
  end

  -- 4. Parse and categorize tracking buckets
  local lines = vim.split(status_output, "\n")
  local staged, unstaged, untracked = {}, {}, {}
  local total_count = 0

  for _, line in ipairs(lines) do
    if line ~= "" then
      total_count = total_count + 1
      local stage_char = line:sub(1, 1)
      local work_char = line:sub(2, 2)
      local file_path = line:sub(4):gsub("^%.%.%/+", "") -- Clean leading relative path tracks

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

  -- 5. Construct structural visual layout sections
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

  -- 6. Trigger notification toast
  vim.notify(table.concat(msg_sections, "\n\n"), vim.log.levels.INFO, {
    title = "Git Status",
    timeout = 4000,
  })
end

-- Git Stash Push with description prompt
function M.git_stash_with_prompt()
  local status_check = vim.fn.system("git status --porcelain")

  if status_check == "" then
    vim.notify("Nothing to stash! Working directory is clean.", vim.log.levels.WARN, { title = "Git Stash" })
    return
  end

  vim.ui.input({ prompt = "Stash Message: " }, function(input)
    if not input or input == "" then
      vim.notify("Stash aborted: Empty message", vim.log.levels.INFO, { title = "Git Stash" })
      return
    end

    local cmd = string.format("git stash push -u -m %s", vim.fn.shellescape(input))
    local output = vim.fn.system(cmd)

    if vim.v.shell_error == 0 then
      vim.notify("Stashed successfully:\n" .. input, vim.log.levels.INFO, { title = "Git Stash" })
      vim.api.nvim_exec_autocmds("User", { pattern = "NeogitStatusRefreshed" })
    else
      vim.notify("Stash failed:\n" .. output, vim.log.levels.ERROR, { title = "Git Stash" })
    end
  end)
end

-- Git Commit with description prompt
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

-- Toggle Diffview against picked Snacks Git branch
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

-- Toggle Diffview for the current working directory files
function M.toggle_diffview()
  local has_diffview, diffview_lib = pcall(require, "diffview.lib")

  if has_diffview and next(diffview_lib.views) == nil then
    vim.cmd("DiffviewOpen")
  else
    vim.cmd("DiffviewClose")
  end
end

-- INFO: Other fucntions

-- Toggle Codeium AI Auto-completion
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

-- Strip all comments from the active buffer based on filetype
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

-- Copy path to clipboard with forward slashes and escaped spaces
function M.copy_clean_filepath()
  local filepath = vim.fn.expand("%:p")
  filepath = filepath:gsub("\\", "/"):gsub(" ", "\\ ")
  vim.fn.setreg("+", filepath)
  print("Copied file path to clipboard: " .. filepath)
end

-- Quick create and save an Obsidian note
function M.create_obsidian_note()
  local filename = vim.fn.input("Enter note name: ")
  if filename == "" then
    return
  end
  vim.cmd("edit ~/git/obsidian/" .. filename .. ".md")
  vim.cmd("write")
end

-- Smart Toggle Snacks Terminal & copy run command to clipboard
function M.toggle_smart_terminal()
  local current_dir = vim.fn.expand("%:p:h")
  if current_dir == "" or vim.fn.isdirectory(current_dir) == 0 then
    current_dir = vim.fn.getcwd()
  end

  if vim.bo.buftype == "terminal" then
    vim.cmd("hide")
  else
    local current_file = vim.fn.expand("%:t")
    vim.fn.setreg("+", "python " .. current_file) -- Copy execution command to system clipboard

    require("snacks").terminal("zsh", {
      cwd = current_dir,
      env = { TERM = "x-256color" },
      win = {
        style = "terminal",
        relative = "editor",
        height = 0.83,
      },
    })
  end
end

-- Save, build, and debug C++ files in terminal overlay
function M.compile_and_run_cpp()
  vim.cmd("w")
  local path = vim.fn.expand("%:p:r"):gsub("\\", "/")
  local fileDir = vim.fn.expand("%:p:h")
  local command = string.format("cd %s && clang++ --debug -o %s %s.cpp && %s", fileDir, path, path, path)

  -- Open terminal overlay toggle (simulates your shortcut)
  vim.api.nvim_input("<C-/>")

  -- Paste execution command string safely after a tiny structural latency gap
  vim.defer_fn(function()
    vim.api.nvim_put({ command }, "l", true, true)
  end, 100)
end

-- Open a completely clean terminal in a brand new dedicated tab layout
function M.open_tab_terminal()
  vim.cmd("tabnew")
  vim.cmd("terminal")
  vim.cmd("startinsert")
end

-- Toggle window layout orientation between horizontal and vertical splits
function M.toggle_split_orientation()
  local win_count = #vim.api.nvim_tabpage_list_wins(0)
  if win_count ~= 2 then
    print("Toggle only works with exactly 2 windows")
    return
  end

  local layout = vim.fn.winlayout()
  if layout[1] == "row" then
    vim.cmd("wincmd K") -- Flips side-by-side (row) layout to stacked vertically
  else
    vim.cmd("wincmd H") -- Flips stacked (col) layout to side-by-side
  end
end

-- markdown function

function M.align_markdown_table_columns()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1]

  -- 1. Scan upwards to find the start of the table
  local start_row = cursor_row
  while start_row > 1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, start_row - 2, start_row - 1, false)[1]
    if not line or not line:match("^%s*|") then
      break
    end
    start_row = start_row - 1
  end

  -- 2. Scan downwards to find the end of the table
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

  -- Guard clause: Make sure we are actually on a table
  if start_row > end_row then
    return
  end

  -- 3. Parse the table rows and calculate maximum widths for each column
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, end_row, false)
  local table_data = {}
  local col_widths = {}

  for _, line in ipairs(lines) do
    local row_cells = {}

    -- Strip leading/trailing structural whitespace & pipes completely to isolate text content
    local clean_line = vim.trim(line):gsub("^|", ""):gsub("|$", "")
    clean_line = vim.trim(clean_line)

    for cell in (clean_line .. "|"):gmatch("(.-)|") do
      table.insert(row_cells, vim.trim(cell))
    end

    table.insert(table_data, row_cells)

    -- Track maximum length per column index natively (ignoring separator rows)
    for i, cell in ipairs(row_cells) do
      local is_sep_cell = cell:match("^%s*:%-+%s*$")
        or cell:match("^%s*%-+:%s*$")
        or cell:match("^%s*%-+%s*$")
        or cell:match("^%s*:%-+:%s*$")
      if not is_sep_cell then
        local cell_len = vim.fn.strdisplaywidth(cell)
        col_widths[i] = math.max(col_widths[i] or 0, cell_len)
      end
    end
  end

  -- 4. Reconstruct the aligned table strings
  local formatted_lines = {}
  for idx, row_cells in ipairs(table_data) do
    local formatted_row = {}

    -- Detect if this row is the separator delimiter line (e.g., |---|---|)
    local is_separator = true
    for _, cell in ipairs(row_cells) do
      if
        cell ~= ""
        and not cell:match("^%s*:%-+%s*$")
        and not cell:match("^%s*%-+:%s*$")
        and not cell:match("^%s*%-+%s*$")
        and not cell:match("^%s*:%-+:%s*$")
      then
        is_separator = false
      end
    end

    for i, cell in ipairs(row_cells) do
      local target_width = col_widths[i] or 0

      if is_separator then
        -- Separator matches the text width plus its own 2 flanking pad spaces exactly
        table.insert(formatted_row, string.rep("-", target_width + 2))
      elseif idx == 1 then
        -- Center headers perfectly on the first row within the target width boundaries
        local total_padding = target_width - vim.fn.strdisplaywidth(cell)
        local left_padding = math.floor(total_padding / 2)
        local right_padding = total_padding - left_padding

        table.insert(
          formatted_row,
          " " .. string.rep(" ", left_padding) .. cell .. string.rep(" ", right_padding) .. " "
        )
      else
        -- Left-align text content cleanly with exactly 1 padding space on the edges
        local padding = target_width - vim.fn.strdisplaywidth(cell)
        table.insert(formatted_row, " " .. cell .. string.rep(" ", padding) .. " ")
      end
    end

    -- Stitch back together cleanly without adding extra trailing cells or layout shifting
    table.insert(formatted_lines, "|" .. table.concat(formatted_row, "|") .. "|")
  end

  -- 5. Write the beautiful aligned lines straight back into your buffer window
  vim.api.nvim_buf_set_lines(bufnr, start_row - 1, end_row, false, formatted_lines)
end

-- Automatically register the :DeleteFile command
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

-- HIGH-PERFORMANCE FZF-LUA FILE PICKER (WITH ABSOLUTE PATH FALLBACK)

vim.api.nvim_create_user_command("FzfBigOpen", function()
  local fzf = require("fzf-lua")

  fzf.files({
    prompt = "⚡ BigOpen> ",
    actions = {
      ["default"] = function(selected, opts)
        local filepath = ""
        local query = opts.last_query or ""

        -- 1. PRIORITIZE EXPLICIT PATH OVERRIDES:
        -- Check if the user typed or pasted an absolute path or a home directory path (~/)
        if query:match("^/") or query:match("^~") then
          -- Expand environment variables or '~' to get the real absolute path string
          local expanded_path = vim.fn.expand(query)

          -- Confirm the file actually exists on the filesystem
          if vim.fn.filereadable(expanded_path) == 1 then
            filepath = expanded_path
          end
        end

        -- 2. STANDARD PICKER FALLBACK:
        -- If no valid absolute path was typed, fall back to standard selected list entries
        if filepath == "" then
          if not selected or #selected == 0 then
            return
          end
          filepath = fzf.path.entry_to_file(selected[1]).path or selected[1]
        end

        -- Final safety check before altering Neovim states
        if filepath == "" or not filepath then
          return
        end

        -- 3. Safely blind Neovim before loading the target buffer
        vim.g.neovim_loading_bigfile = true
        vim.opt.eventignore:append({ "BufReadPre", "BufReadPost", "FileType" })

        -- 4. Execute optimization script within a safe protected block
        local success, err = pcall(function()
          vim.cmd("edit " .. vim.fn.fnameescape(filepath))
          local buf = vim.api.nvim_get_current_buf()

          -- Strip performance-heavy modules instantly
          vim.opt_local.swapfile = false
          vim.opt_local.undofile = false
          vim.opt_local.foldmethod = "manual"
          vim.opt_local.wrap = false
          vim.opt_local.statuscolumn = ""
          vim.opt_local.relativenumber = false
          vim.opt_local.syntax = "off"

          -- Kill active Treesitter parsers on this thread
          pcall(vim.treesitter.stop, buf)

          -- Kill active LSP handshakes on this buffer
          local clients = vim.lsp.get_clients({ bufnr = buf })
          for _, client in ipairs(clients) do
            vim.lsp.buf_detach_client(buf, client.id)
          end
        end)

        -- 5. GUARANTEED TEARDOWN: Restores your global event channels
        vim.opt.eventignore:remove({ "BufReadPre", "BufReadPost", "FileType" })
        vim.g.neovim_loading_bigfile = false

        -- User Status feedback toasts
        if not success then
          vim.notify("BigOpen Picker error: " .. tostring(err), vim.log.levels.ERROR)
        else
          vim.notify("File parsed safely via Fast Raw Mode.", vim.log.levels.INFO)
        end
      end,
    },
  })
end, { desc = "Fuzzy search or open an absolute file path instantly" })

-- pick command from zsh history and execute in fast terminal

vim.api.nvim_create_user_command("PickFromZshHistory", function()
  local zsh_history_path = vim.fn.expand("~/.zsh_history")

  if vim.fn.filereadable(zsh_history_path) == 0 then
    vim.notify("Could not read .zsh_history file", vim.log.levels.ERROR)
    return
  end

  -- Read the history file lines
  local lines = vim.fn.readfile(zsh_history_path)
  local processed_commands = {}
  local seen = {} -- Track duplicates

  -- Process the file backwards (from most recent to oldest)
  for i = #lines, 1, -1 do
    local line = lines[i]
    -- Strip the Zsh metadata prefix: ": 1717449587:0;YOUR_COMMAND" -> "YOUR_COMMAND"
    local cmd = line:gsub("^:%s*%d+:%d+;", "")
    cmd = cmd:match("^%s*(.-)%s*$") -- Trim spaces

    -- Only add non-empty, unique commands to keep the picker clean
    if cmd and cmd ~= "" and not seen[cmd] then
      table.insert(processed_commands, cmd)
      seen[cmd] = true
    end
  end

  -- Feed the clean list into Fzf-lua
  require("fzf-lua").fzf_exec(processed_commands, {
    prompt = "Zsh> ",
    fzf_opts = {
      ["--no-sort"] = "",
    },
    actions = {
      ["default"] = function(selected)
        if not selected or #selected == 0 then
          return
        end
        local cmd_to_run = selected[1]

        -- Drop down to a terminal split and run it immediately
        vim.schedule(function()
          local interactive_cmd =
            string.format("split | resize 12 | terminal zsh -i -c %s", vim.fn.shellescape(cmd_to_run))
          vim.cmd(interactive_cmd)
          vim.cmd("startinsert")
        end)
      end,
    },
  })
end, { desc = "Zsh Command History" })

return M
