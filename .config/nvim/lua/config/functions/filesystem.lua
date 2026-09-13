local M = {}

function M.close_tab_or_buffer()
  if #vim.api.nvim_list_tabpages() > 1 then
    vim.cmd("tabclose")
  else
    local has_snacks, snacks = pcall(require, "snacks")
    if has_snacks and snacks.bufdelete then
      snacks.bufdelete()
    else
      vim.cmd("bdelete")
    end
  end
end

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

        -- 1. Try matching path from query input (~/ or /)
        if query:match("^/") or query:match("^~") then
          local expanded = vim.fn.expand(query)
          if vim.fn.filereadable(expanded) == 1 then
            filepath = expanded
          end
        end

        -- 2. Try getting file from fzf selection
        if filepath == "" and selected and #selected > 0 then
          filepath = fzf.path.entry_to_file(selected[1]).path or selected[1]
        end

        -- 3. Fallback: If no file selected/typed, use the CURRENT buffer's file path
        if filepath == "" or not filepath then
          filepath = vim.api.nvim_buf_get_name(0)
        end

        -- If current buffer is unnamed / empty buffer, stop here
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
      ["default"] = function(selected, opts)
        local fzf_lua = require("fzf-lua")
        local query = (opts and opts.last_query) or fzf_lua.get_last_query() or ""
        local cmd_to_run

        if query:sub(1, 1) == "!" then
          cmd_to_run = query:sub(2):match("^%s*(.-)%s*$")
        elseif selected and #selected > 0 then
          cmd_to_run = selected[1]
        end

        if not cmd_to_run or #cmd_to_run == 0 then
          return
        end

        vim.schedule(function()
          -- Calculate floating window dimensions (80% width, 60% height)
          local width = math.floor(vim.o.columns * 0.8)
          local height = math.floor(vim.o.lines * 0.6)
          local row = math.floor((vim.o.lines - height) / 2)
          local col = math.floor((vim.o.columns - width) / 2)

          -- Create scratch buffer and open float
          local buf = vim.api.nvim_create_buf(false, true)
          local win = vim.api.nvim_open_win(buf, true, {
            relative = "editor",
            width = width,
            height = height,
            row = row,
            col = col,
            style = "minimal",
            border = "rounded",
          })

          -- Open terminal in float and enter insert mode
          local term_cmd = string.format("zsh -i -c %s", vim.fn.shellescape(cmd_to_run))
          vim.fn.termopen(term_cmd)
          vim.cmd("startinsert")
        end)
      end,
    },
  })
end, { desc = "Zsh Command History" })


function M.open_help_splits()
  local left_file = vim.fn.expand("~/git/project/help.md")
  local right_file = vim.fn.expand("~/git/project/help1.md")

  -- Close all other splits in the current tab page
  vim.cmd("only")

  -- Open the left file in the main window
  vim.cmd("edit " .. vim.fn.fnameescape(left_file))
  local left_win = vim.api.nvim_get_current_win()

  -- Create a vertical split on the right for the second file
  vim.cmd("rightbelow vsplit " .. vim.fn.fnameescape(right_file))

  -- Return cursor focus to the left window
  vim.api.nvim_set_current_win(left_win)
end


function M.search_json_and_copy_value()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local raw_text = table.concat(lines, "\n")

  if raw_text:match("^%s*$") then
    vim.notify("Buffer is empty!", vim.log.levels.WARN)
    return
  end

  local ok, decoded = pcall(vim.json.decode, raw_text)
  if not ok or type(decoded) ~= "table" then
    vim.notify("Failed to parse valid JSON from buffer", vim.log.levels.ERROR)
    return
  end

  local entries = {}
  local lookup = {}

  local function flatten(obj, path)
    if type(obj) == "table" then
      local is_array = (vim.islist and vim.islist(obj)) or vim.tbl_islist(obj)
      if is_array then
        for i, val in ipairs(obj) do
          local new_path = string.format("%s[%d]", path, i)
          if type(val) == "table" then
            flatten(val, new_path)
          else
            local val_str = val == nil and "null" or tostring(val)
            local item_str = string.format("%s: %s", new_path, val_str)
            table.insert(entries, item_str)
            lookup[item_str] = val_str
          end
        end
      else
        for k, v in pairs(obj) do
          local new_path = path == "" and tostring(k) or (path .. "." .. tostring(k))
          if type(v) == "table" then
            flatten(v, new_path)
          else
            local val_str = v == nil and "null" or tostring(v)
            local item_str = string.format("%s: %s", new_path, val_str)
            table.insert(entries, item_str)
            lookup[item_str] = val_str
          end
        end
      end
    end
  end

  flatten(decoded, "")

  if #entries == 0 then
    vim.notify("No JSON key-value pairs found", vim.log.levels.WARN)
    return
  end

  table.sort(entries)

  require("fzf-lua").fzf_exec(entries, {
    prompt = "JSON Keys> ",
    actions = {
      ["default"] = function(selected)
        if not selected or #selected == 0 then
          return
        end
        local choice = selected[1]
        local val_to_copy = lookup[choice]

        if val_to_copy then
          vim.fn.setreg("+", val_to_copy)
          vim.fn.setreg('"', val_to_copy)
          vim.notify("Copied: " .. val_to_copy, vim.log.levels.INFO, { title = "JSON Copy" })
        end
      end,
    },
  })
end


return M
