local M = {}

local function snacks()
  local existing = rawget(_G, "Snacks")
  if existing then
    return existing
  end

  local ok, module = pcall(require, "snacks")
  return ok and module or nil
end

function M.project_root()
  if _G.LazyVim and LazyVim.root then
    return LazyVim.root()
  end

  return (vim.uv or vim.loop).cwd()
end

function M.buffer_dir()
  if vim.bo.buftype == "" then
    local filepath = vim.api.nvim_buf_get_name(0)
    if filepath ~= "" then
      return vim.fn.fnamemodify(filepath, ":p:h")
    end
  end

  return vim.fn.getcwd()
end

local function terminal_command_name(command)
  if command == nil then
    return "shell"
  end

  if type(command) == "table" then
    return command[1] or "command"
  end

  return command:match("^%s*([^%s]+)") or "command"
end

local terminal_registry = {}

local function remember_terminal(terminal)
  if not terminal or not terminal.buf or not terminal:buf_valid() then
    return
  end

  local buf = terminal.buf
  terminal_registry[buf] = terminal
  if vim.b[buf].nvim_terminal_registry then
    return
  end

  vim.b[buf].nvim_terminal_registry = true
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      terminal_registry[buf] = nil
    end,
  })
end

local function native_terminal(buf)
  local terminal = { buf = buf, native = true }

  function terminal:buf_valid()
    return vim.api.nvim_buf_is_valid(self.buf)
  end

  function terminal:show()
    if not self:buf_valid() then
      return self
    end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == self.buf then
        local tabpage = vim.api.nvim_win_get_tabpage(win)
        if tabpage ~= vim.api.nvim_get_current_tabpage() then
          vim.api.nvim_set_current_tabpage(tabpage)
        end
        vim.api.nvim_set_current_win(win)
        return self
      end
    end

    vim.cmd("botright split")
    vim.api.nvim_win_set_buf(0, self.buf)
    return self
  end

  function terminal:focus()
    return self:show()
  end

  function terminal:hide()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == self.buf then
        pcall(vim.api.nvim_win_close, win, true)
        break
      end
    end
    return self
  end

  function terminal:close()
    if self:buf_valid() then
      vim.api.nvim_buf_delete(self.buf, { force = true })
    end
  end

  return terminal
end

local function terminal_list()
  local terminals = {}
  local seen = {}
  local module = snacks()

  if module and module.terminal then
    for _, terminal in ipairs(module.terminal.list()) do
      remember_terminal(terminal)
      terminals[#terminals + 1] = terminal
      seen[terminal.buf] = true
    end
  end

  -- Recover Snacks terminal buffers if their window object is not currently
  -- returned by Snacks. Ignore plain :terminal buffers such as the shell used
  -- to launch a search; t. is intended to manage this terminal collection.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local info = vim.b[buf].snacks_terminal
    if
      vim.api.nvim_buf_is_valid(buf)
      and vim.bo[buf].buftype == "terminal"
      and info
      and not vim.b[buf].overseer_task
      and not seen[buf]
    then
      local terminal = native_terminal(buf)
      terminal.name = info.name or "terminal"
      terminal.cwd = info.cwd
      terminal.id = info.id
      terminals[#terminals + 1] = terminal
      seen[buf] = true
    end
  end

  table.sort(terminals, function(a, b)
    local a_info = vim.b[a.buf].snacks_terminal or {}
    local b_info = vim.b[b.buf].snacks_terminal or {}
    local a_name = a.name or a_info.name or terminal_command_name(a_info.cmd)
    local b_name = b.name or b_info.name or terminal_command_name(b_info.cmd)
    if (a.id or a_info.id or 0) == (b.id or b_info.id or 0) then
      return a_name < b_name
    end
    return (a.id or a_info.id or 0) < (b.id or b_info.id or 0)
  end)
  return terminals
end

local function terminal_label(terminal, index)
  local info = vim.b[terminal.buf].snacks_terminal or {}
  local name = terminal.name or info.name or terminal_command_name(info.cmd)
  local count = terminal.id or info.id or index
  local cwd = terminal.cwd or info.cwd
  cwd = cwd and vim.fn.fnamemodify(cwd, ":~") or "unknown cwd"
  local active = vim.api.nvim_get_current_buf() == terminal.buf and "*" or " "
  return string.format("%s[%s] %-24s %s", active, count, name, cwd)
end

local function terminal_preview(items, preview_lines, lookup)
  local terminal = lookup[items and items[1]]
  if not terminal or not terminal:buf_valid() then
    return { "Terminal buffer is no longer available" }
  end

  local ok, lines = pcall(vim.api.nvim_buf_get_lines, terminal.buf, 0, -1, false)
  if not ok then
    return { "Unable to read terminal output" }
  end

  local max_lines = math.max(1, math.min(200, tonumber(preview_lines) or 100))
  local first = math.max(1, #lines - max_lines + 1)
  local preview = {}
  if first > 1 then
    preview[#preview + 1] = string.format("… %d earlier lines omitted …", first - 1)
  end
  for index = first, #lines do
    preview[#preview + 1] = lines[index]
  end

  if #preview == 0 then
    return { "(terminal has no output yet)" }
  end
  return preview
end

function M.fullscreen_terminal_opts(opts)
  opts = opts or {}
  local terminal_name = opts.name or "terminal"
  local on_buf = opts.win and opts.win.on_buf
  local defaults = {
    cwd = M.project_root(),
    win = {
      style = "terminal",
      position = "float",
      row = 0,
      col = 0,
      width = 0,
      -- Leave the global lualine/statusline row visible at the bottom.
      height = function()
        local rows = vim.o.lines - vim.o.cmdheight
        if vim.o.laststatus > 0 then
          rows = rows - 1
        end
        return math.max(rows, 1)
      end,
      border = "none",
    },
  }

  local merged = vim.tbl_deep_extend("force", defaults, opts)
  merged.name = terminal_name
  merged.win.title = merged.win.title or terminal_name
  merged.win.on_buf = function(win)
    local info = vim.b[win.buf].snacks_terminal or {}
    info.name = terminal_name
    vim.b[win.buf].snacks_terminal = info
    if on_buf then
      on_buf(win)
    end
  end

  return merged
end

local function use_terminal(method, command, opts)
  local module = snacks()
  if not module or not module.terminal then
    vim.notify("Snacks terminal is not available", vim.log.levels.ERROR, { title = "Terminal" })
    return
  end

  opts = vim.tbl_deep_extend("force", { name = terminal_command_name(command) }, opts or {})
  local terminal = module.terminal[method](command, M.fullscreen_terminal_opts(opts))
  remember_terminal(terminal)
  return terminal
end

function M.toggle_terminal_command(command, opts)
  return use_terminal("toggle", command, opts)
end

-- Focus an existing terminal when called elsewhere, but hide it when the
-- current buffer is that terminal. This is useful for named tool terminals.
function M.focus_terminal_command(command, opts)
  return use_terminal("focus", command, opts)
end

function M.toggle_fullscreen_terminal()
  M.toggle_terminal_command(nil, { count = vim.v.count1, name = "shell" })
end

function M.toggle_terminal_here()
  M.toggle_terminal_command(nil, {
    count = vim.v.count1,
    cwd = M.buffer_dir(),
    name = "shell",
  })
end

function M.toggle_terminal()
  local terminals = terminal_list()
  local current_buf = vim.api.nvim_get_current_buf()
  if terminals then
    for _, terminal in ipairs(terminals) do
      if terminal.buf == current_buf then
        terminal:hide()
        return
      end
    end
  end

  M.toggle_fullscreen_terminal()
end

function M.pick_terminal()
  local terminals = terminal_list()
  if #terminals == 0 then
    vim.notify("No open terminals", vim.log.levels.INFO, { title = "Terminal" })
    return
  end

  local entries = {}
  local lookup = {}
  for index, terminal in ipairs(terminals) do
    local label = terminal_label(terminal, index)
    entries[#entries + 1] = label
    lookup[label] = terminal
  end

  local function focus_selected(selected)
    local terminal = selected and lookup[selected[1]]
    if terminal and terminal:buf_valid() then
      terminal:show():focus()
    end
  end

  local ok, fzf = pcall(require, "fzf-lua")
  if ok then
    fzf.fzf_exec(entries, {
      prompt = "Terminals> ",
      fzf_opts = { ["--no-sort"] = "" },
      preview = function(items, preview_lines)
        return terminal_preview(items, preview_lines, lookup)
      end,
      actions = { ["default"] = focus_selected },
    })
    return
  end

  vim.ui.select(entries, { prompt = "Terminals" }, function(label)
    focus_selected(label and { label } or nil)
  end)
end

local function cycle_terminal(direction)
  local terminals = terminal_list()
  if not terminals or #terminals == 0 then
    vim.notify("No open terminals", vim.log.levels.INFO, { title = "Terminal" })
    return
  end

  local current_buf = vim.api.nvim_get_current_buf()
  local current_index = 0
  for index, terminal in ipairs(terminals) do
    if terminal.buf == current_buf then
      current_index = index
      break
    end
  end

  local count = vim.v.count1
  local target_index
  if current_index == 0 then
    target_index = direction > 0 and 1 or #terminals
  else
    target_index = ((current_index - 1 + direction * count) % #terminals) + 1
  end

  terminals[target_index]:show():focus()
end

function M.next_terminal()
  cycle_terminal(1)
end

function M.previous_terminal()
  cycle_terminal(-1)
end

function M.close_terminal()
  local terminals = terminal_list()
  local current_buf = vim.api.nvim_get_current_buf()
  if terminals then
    for _, terminal in ipairs(terminals) do
      if terminal.buf == current_buf then
        terminal:close()
        return
      end
    end
  end

  vim.notify("Current buffer is not a terminal", vim.log.levels.INFO, { title = "Terminal" })
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

return M
