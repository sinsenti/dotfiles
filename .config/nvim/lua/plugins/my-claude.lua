local sessions = {} -- Dynamic array storage holding tracking descriptors
local session_labels = {} -- Unique custom names mapped by buffer handles
local active_idx = 0
local claude_win = nil
local saved_ui_opts = {} -- Storage array caching workspace states for restoration

-- Picker Window References
local picker_list_win = nil
local picker_prev_win = nil
local picker_list_buf = nil

-- Quick Notes Window References
local notes_buf = nil
local notes_win = nil

-- Utility: Purge dead or manually killed buffers from session tracking pool
local function clean_invalid_sessions()
  local valid = {}
  for _, buf in ipairs(sessions) do
    if vim.api.nvim_buf_is_valid(buf) then
      table.insert(valid, buf)
    end
  end
  sessions = valid
  if active_idx > #sessions then
    active_idx = #sessions
  end
  if #sessions == 0 then
    active_idx = 0
  end
end

-- Zen Engine: Hide all global editor panels and screen boundaries
local function apply_zen_mode()
  if next(saved_ui_opts) == nil then
    saved_ui_opts.laststatus = vim.o.laststatus
    saved_ui_opts.showtabline = vim.o.showtabline
    saved_ui_opts.ruler = vim.o.ruler
    saved_ui_opts.cmdheight = vim.o.cmdheight
  end

  vim.o.laststatus = 0 -- Hides Neovim statusline panels completely
  vim.o.showtabline = 0 -- Removes buffer/tabline element strips from top margins
  vim.o.ruler = false -- Disables bottom line/column numerical string fields
  vim.o.cmdheight = 0 -- Collapses command entry line to allow edge terminal drawing
end

-- Zen Engine: Safely return global UI options back to standard workspace presets
local function restore_ui_mode()
  if saved_ui_opts.laststatus then
    vim.o.laststatus = saved_ui_opts.laststatus
  end
  if saved_ui_opts.showtabline then
    vim.o.showtabline = saved_ui_opts.showtabline
  end
  if saved_ui_opts.ruler ~= nil then
    vim.o.ruler = saved_ui_opts.ruler
  end
  if saved_ui_opts.cmdheight then
    vim.o.cmdheight = saved_ui_opts.cmdheight
  end
  saved_ui_opts = {}
end

-- Utility: Calculate pure 100% borderless display grids filling the monitor viewport
local function get_fullscreen_config()
  return {
    relative = "editor",
    width = vim.o.columns,
    height = vim.o.lines,
    row = 0,
    col = 0,
    style = "minimal",
    border = "none",
  }
end

-- Core Terminal Spawning Loop: Launches processes and maps background event listeners
local function ensure_terminal_running(current_buf)
  local job_id = vim.b[current_buf].terminal_job_id
  local is_alive = false
  if job_id then
    is_alive = pcall(vim.fn.jobpid, job_id)
  end

  if vim.bo[current_buf].buftype ~= "terminal" or not is_alive then
    local cmd = vim.b[current_buf].custom_cmd or "claude"

    vim.fn.termopen(cmd, {
      on_exit = function()
        vim.schedule(function()
          local target_idx = nil
          for i, b in ipairs(sessions) do
            if b == current_buf then
              target_idx = i
              break
            end
          end
          if target_idx then
            remove_session_by_idx(target_idx)
          end
        end)
      end,
    })

    -- Route syntactic properties dynamically based on active binary command paths
    if cmd:match("claude") then
      vim.bo[current_buf].filetype = "claude"
    else
      vim.bo[current_buf].filetype = "terminal"
    end
    vim.bo[current_buf].scrollback = 100000

    vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { buffer = current_buf, desc = "Exit Terminal Mode" })
    vim.keymap.set("t", "<A-u>", "<PageUp>", { buffer = current_buf, silent = true, desc = "Scroll Up" })
    vim.keymap.set("t", "<A-d>", "<PageDown>", { buffer = current_buf, silent = true, desc = "Scroll Down" })
  end
end

-- Scratchpad Engine: Handles creating, positioning, and toggling the Markdown scratch window
local function toggle_quick_notes()
  if notes_win and vim.api.nvim_win_is_valid(notes_win) then
    vim.api.nvim_win_close(notes_win, true)
    notes_win = nil
    if claude_win and vim.api.nvim_win_is_valid(claude_win) and vim.api.nvim_get_current_win() == claude_win then
      vim.cmd("startinsert")
    end
    return
  end

  local notes_path = "/home/user/Documents/notes/claude.md"

  -- Ensure directory structure exists safely
  pcall(function()
    vim.fn.mkdir(vim.fn.fnamemodify(notes_path, ":h"), "p")
  end)

  -- Fetch or create a buffer pointing specifically to the file
  if not notes_buf or not vim.api.nvim_buf_is_valid(notes_buf) then
    notes_buf = vim.fn.bufadd(notes_path)
    vim.fn.bufload(notes_buf)
    vim.bo[notes_buf].bufhidden = "hide"
    vim.bo[notes_buf].filetype = "markdown"
  end

  local width = math.floor(vim.o.columns * 0.65)
  local height = math.floor(vim.o.lines * 0.65)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  notes_win = vim.api.nvim_open_win(notes_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " 󱞎 Quick Notes (Alt+n to close) ",
    title_pos = "center",
  })

  vim.wo[notes_win].winhl = "Normal:NormalFloat,FloatBorder:FloatBorder"
  vim.wo[notes_win].wrap = true -- Soft wrap text lines for seamless markdown reading

  -- Force Normal Mode exit from any terminal or insertion state
  vim.cmd("stopinsert")

  local opts = { buffer = notes_buf, silent = true }
  vim.keymap.set("t", "<A-n>", toggle_quick_notes, opts)
end

-- Live Sub-Engine: Tear down picker overlay panels safely
local function close_sessions_picker()
  if picker_list_win and vim.api.nvim_win_is_valid(picker_list_win) then
    vim.api.nvim_win_close(picker_list_win, true)
  end
  if picker_prev_win and vim.api.nvim_win_is_valid(picker_prev_win) then
    vim.api.nvim_win_close(picker_prev_win, true)
  end
  picker_list_win, picker_prev_win, picker_list_buf = nil, nil, nil

  if claude_win and vim.api.nvim_win_is_valid(claude_win) then
    vim.api.nvim_set_current_win(claude_win)
    vim.cmd("startinsert")
  end
end

-- Live Sub-Engine: Construct side-by-side picker matrix panels
local function show_sessions_picker()
  clean_invalid_sessions()

  picker_list_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[picker_list_buf].buftype = "nofile"
  vim.bo[picker_list_buf].bufhidden = "wipe"

  -- Ensure notes buffer exists so it can be previewed/referenced safely
  local notes_path = "/home/user/Documents/notes/claude.md"
  if not notes_buf or not vim.api.nvim_buf_is_valid(notes_buf) then
    pcall(function()
      vim.fn.mkdir(vim.fn.fnamemodify(notes_path, ":h"), "p")
    end)
    notes_buf = vim.fn.bufadd(notes_path)
    vim.fn.bufload(notes_buf)
    vim.bo[notes_buf].bufhidden = "hide"
    vim.bo[notes_buf].filetype = "markdown"
  end

  local function refresh_picker_list_lines()
    vim.bo[picker_list_buf].modifiable = true
    local lines = { "  󱞎 Quick Notes File" } -- First option option definition

    for i = 1, #sessions do
      local buf = sessions[i]
      local cmd_path = vim.b[buf].custom_cmd or "claude"
      local default_label = cmd_path:match("claude") and string.format("Session %d", i)
        or string.format("Terminal %d", i)
      local label = session_labels[buf] or default_label
      local indicator = (i == active_idx) and "➔ " or "  "
      table.insert(lines, string.format("%s%s", indicator, label))
    end
    vim.api.nvim_buf_set_lines(picker_list_buf, 0, -1, false, lines)
    vim.bo[picker_list_buf].modifiable = false
  end

  refresh_picker_list_lines()

  local total_width = math.floor(vim.o.columns * 0.85)
  local height = math.floor(vim.o.lines * 0.85)
  local list_width = 25
  local prev_width = total_width - list_width - 2
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - total_width) / 2)

  picker_list_win = vim.api.nvim_open_win(picker_list_buf, true, {
    relative = "editor",
    width = list_width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Active Chats ",
    title_pos = "center",
  })

  -- Set initial preview target window based on layout cursor alignments
  local initial_row = (active_idx > 0 and active_idx <= #sessions) and (active_idx + 1) or 1
  local initial_buf = initial_row == 1 and notes_buf or sessions[initial_row - 1]

  picker_prev_win = vim.api.nvim_open_win(initial_buf, false, {
    relative = "editor",
    width = prev_width,
    height = height,
    row = row,
    col = col + list_width + 2,
    style = "minimal",
    border = "rounded",
    title = " Live Preview ",
    title_pos = "center",
  })

  local hl_patch = "Normal:Normal,NormalFloat:Normal,FloatNormal:Normal,SignColumn:Normal,MsgArea:Normal"
  vim.wo[picker_list_win].winhl = hl_patch
  vim.wo[picker_prev_win].winhl = hl_patch
  vim.wo[picker_prev_win].wrap = (initial_row == 1)

  local init_line_count = vim.api.nvim_buf_line_count(initial_buf)
  if init_line_count > 0 then
    pcall(vim.api.nvim_win_set_cursor, picker_prev_win, { init_line_count, 0 })
  end
  pcall(vim.api.nvim_win_set_cursor, picker_list_win, { initial_row, 0 })

  local group = vim.api.nvim_create_augroup("ClaudePickerTracker", { clear = true })
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = picker_list_buf,
    group = group,
    callback = function()
      if not picker_prev_win or not vim.api.nvim_win_is_valid(picker_prev_win) then
        return
      end
      local current_row = vim.api.nvim_win_get_cursor(picker_list_win)[1]
      local target_buf = current_row == 1 and notes_buf or sessions[current_row - 1]

      if target_buf and vim.api.nvim_buf_is_valid(target_buf) then
        vim.api.nvim_win_set_buf(picker_prev_win, target_buf)
        vim.wo[picker_prev_win].wrap = (current_row == 1)
        local line_count = vim.api.nvim_buf_line_count(target_buf)
        if line_count > 0 then
          pcall(vim.api.nvim_win_set_cursor, picker_prev_win, { line_count, 0 })
        end
      end
    end,
  })

  local opts = { buffer = picker_list_buf, silent = true }

  -- Reusable selection action triggered by either Enter or 'l'
  local function accept_selection()
    local selected_row = vim.api.nvim_win_get_cursor(picker_list_win)[1]

    -- If first option is picked, break HUD loop layout and open notes file
    if selected_row == 1 then
      if picker_list_win and vim.api.nvim_win_is_valid(picker_list_win) then
        vim.api.nvim_win_close(picker_list_win, true)
      end
      if picker_prev_win and vim.api.nvim_win_is_valid(picker_prev_win) then
        vim.api.nvim_win_close(picker_prev_win, true)
      end
      picker_list_win, picker_prev_win, picker_list_buf = nil, nil, nil
      toggle_quick_notes()
      return
    end

    active_idx = selected_row - 1
    if picker_list_win and vim.api.nvim_win_is_valid(picker_list_win) then
      vim.api.nvim_win_close(picker_list_win, true)
    end
    if picker_prev_win and vim.api.nvim_win_is_valid(picker_prev_win) then
      vim.api.nvim_win_close(picker_prev_win, true)
    end
    picker_list_win, picker_prev_win, picker_list_buf = nil, nil, nil

    local current_buf = sessions[active_idx]
    apply_zen_mode()
    if not claude_win or not vim.api.nvim_win_is_valid(claude_win) then
      claude_win = vim.api.nvim_open_win(current_buf, true, get_fullscreen_config())
    else
      vim.api.nvim_win_set_buf(claude_win, current_buf)
    end
    vim.wo[claude_win].winhl = "Normal:Normal,NormalFloat:Normal,FloatNormal:Normal,SignColumn:Normal,MsgArea:Normal"

    ensure_terminal_running(current_buf)
    vim.cmd("startinsert")
  end

  -- Bind both Enter and 'l' to open the selection choice
  vim.keymap.set("n", "<CR>", accept_selection, opts)
  vim.keymap.set("n", "l", accept_selection, opts)

  vim.keymap.set("n", "dd", function()
    local selected_row = vim.api.nvim_win_get_cursor(picker_list_win)[1]
    if selected_row == 1 then
      return
    end -- Shield note engine descriptor from deletion actions

    remove_session_by_idx(selected_row - 1)
    clean_invalid_sessions()
    if #sessions == 0 then
      close_sessions_picker()
      return
    end
    refresh_picker_list_lines()
    local new_row = math.min(selected_row, #sessions + 1)
    pcall(vim.api.nvim_win_set_cursor, picker_list_win, { new_row, 0 })

    local target_buf = new_row == 1 and notes_buf or sessions[new_row - 1]
    if target_buf and vim.api.nvim_buf_is_valid(target_buf) then
      vim.api.nvim_win_set_buf(picker_prev_win, target_buf)
      vim.wo[picker_prev_win].wrap = (new_row == 1)
      local lc = vim.api.nvim_buf_line_count(target_buf)
      if lc > 0 then
        pcall(vim.api.nvim_win_set_cursor, picker_prev_win, { lc, 0 })
      end
    end
  end, opts)

  vim.keymap.set("n", "r", function()
    local selected_row = vim.api.nvim_win_get_cursor(picker_list_win)[1]
    if selected_row == 1 then
      return
    end -- Guard notes file option from modifications

    local target_buf = sessions[selected_row - 1]
    local cmd_path = vim.b[target_buf].custom_cmd or "claude"
    local default_name = cmd_path:match("claude") and string.format("Session %d", selected_row - 1)
      or string.format("Terminal %d", selected_row - 1)
    local current_name = session_labels[target_buf] or default_name
    local new_name = vim.fn.input("Rename Item: ", current_name)
    if new_name and new_name ~= "" then
      session_labels[target_buf] = new_name
      refresh_picker_list_lines()
    end
    pcall(vim.api.nvim_win_set_cursor, picker_list_win, { selected_row, 0 })
  end, opts)

  vim.keymap.set("n", "q", close_sessions_picker, opts)
  vim.keymap.set("n", "<Esc>", close_sessions_picker, opts)
  vim.keymap.set("n", "<A-o>", close_sessions_picker, opts)
end

local function remove_session_by_idx(idx)
  if idx < 1 or idx > #sessions then
    return
  end
  local buf_to_remove = sessions[idx]
  table.remove(sessions, idx)

  if #sessions == 0 then
    active_idx = 0
    if claude_win and vim.api.nvim_win_is_valid(claude_win) then
      vim.api.nvim_win_close(claude_win, true)
      claude_win = nil
    end
    restore_ui_mode()
    if vim.api.nvim_buf_is_valid(buf_to_remove) then
      pcall(vim.api.nvim_buf_delete, buf_to_remove, { force = true })
    end
    return
  end

  if active_idx > #sessions then
    active_idx = #sessions
  end
  if claude_win and vim.api.nvim_win_is_valid(claude_win) then
    vim.api.nvim_win_set_buf(claude_win, sessions[active_idx])
    vim.cmd("startinsert")
  end
  if vim.api.nvim_buf_is_valid(buf_to_remove) then
    pcall(vim.api.nvim_buf_delete, buf_to_remove, { force = true })
  end
end

local function toggle_claude_code(mode)
  clean_invalid_sessions()
  if claude_win and vim.api.nvim_win_is_valid(claude_win) and not mode then
    vim.api.nvim_win_close(claude_win, true)
    claude_win = nil
    restore_ui_mode()
    return
  end

  apply_zen_mode()
  if mode == true or mode == "resume" or mode == "terminal" or #sessions == 0 then
    local buf = vim.api.nvim_create_buf(false, true)
    table.insert(sessions, buf)
    active_idx = #sessions

    -- Assign the structural binary execution path right at instantiation
    if mode == "terminal" then
      vim.b[buf].custom_cmd = vim.o.shell
    elseif mode == "resume" then
      vim.b[buf].custom_cmd = "claude --resume"
    else
      vim.b[buf].custom_cmd = "claude"
    end
  end

  local current_buf = sessions[active_idx]
  if not claude_win or not vim.api.nvim_win_is_valid(claude_win) then
    claude_win = vim.api.nvim_open_win(current_buf, true, get_fullscreen_config())
  else
    vim.api.nvim_win_set_buf(claude_win, current_buf)
  end

  vim.wo[claude_win].winhl = "Normal:Normal,NormalFloat:Normal,FloatNormal:Normal,SignColumn:Normal,MsgArea:Normal"
  ensure_terminal_running(current_buf)
  vim.cmd("startinsert")
end

-- Central layout master toggle function called by <A-a>
local function hide_all_or_toggle_claude()
  local any_open = (picker_list_win and vim.api.nvim_win_is_valid(picker_list_win))
    or (picker_prev_win and vim.api.nvim_win_is_valid(picker_prev_win))
    or (notes_win and vim.api.nvim_win_is_valid(notes_win))
    or (claude_win and vim.api.nvim_win_is_valid(claude_win))

  if any_open then
    if picker_list_win and vim.api.nvim_win_is_valid(picker_list_win) then
      pcall(vim.api.nvim_win_close, picker_list_win, true)
    end
    if picker_prev_win and vim.api.nvim_win_is_valid(picker_prev_win) then
      pcall(vim.api.nvim_win_close, picker_prev_win, true)
    end
    picker_list_win, picker_prev_win, picker_list_buf = nil, nil, nil

    if notes_win and vim.api.nvim_win_is_valid(notes_win) then
      pcall(vim.api.nvim_win_close, notes_win, true)
    end
    notes_win = nil

    if claude_win and vim.api.nvim_win_is_valid(claude_win) then
      pcall(vim.api.nvim_win_close, claude_win, true)
    end
    claude_win = nil

    restore_ui_mode()
  else
    toggle_claude_code(false)
  end
end

local function cycle_session(direction)
  clean_invalid_sessions()
  if #sessions <= 1 then
    return
  end
  active_idx = active_idx + direction
  if active_idx > #sessions then
    active_idx = 1
  end
  if active_idx < 1 then
    active_idx = #sessions
  end

  if claude_win and vim.api.nvim_win_is_valid(claude_win) then
    vim.api.nvim_win_set_buf(claude_win, sessions[active_idx])
    vim.cmd("startinsert")
  else
    toggle_claude_code(false)
  end
end

-- Plugin declaration structure evaluated by lazy core architectures
local M = {
  "claude-local",
  dir = vim.fn.stdpath("config"),
  lazy = false,
  keys = {
    {
      "<A-a>",
      function()
        hide_all_or_toggle_claude()
      end,
      mode = { "n", "t", "i" },
      desc = "Toggle/Hide All Claude UI Elements",
      silent = true,
    },
    {
      "<A-c>",
      function()
        toggle_claude_code(true)
      end,
      mode = { "n", "t" },
      desc = "Spawn New Claude Session",
      silent = true,
    },
    {
      "<A-r>",
      function()
        toggle_claude_code("resume")
      end,
      mode = { "n", "t" },
      desc = "Open Claude Session Picker",
      silent = true,
    },
    {
      "<A-k>",
      function()
        remove_session_by_idx(active_idx)
      end,
      mode = { "n", "t" },
      desc = "Remove Current Session",
      silent = true,
    },
    {
      "<A-l>",
      function()
        cycle_session(1)
      end,
      mode = { "n", "t" },
      desc = "Next Layout Session (Right)",
      silent = true,
    },
    {
      "<A-h>",
      function()
        cycle_session(-1)
      end,
      mode = { "n", "t" },
      desc = "Prev Layout Session (Left)",
      silent = true,
    },
    {
      "<A-o>",
      function()
        show_sessions_picker()
      end,
      mode = { "n", "t" },
      desc = "Show Session List HUD",
      silent = true,
    },
    {
      "<A-n>",
      function()
        toggle_quick_notes()
      end,
      mode = { "n", "t", "i" },
      desc = "Toggle Quick Notes Scratchpad",
      silent = true,
    },

    -- NATIVE SHELL TOGGLE MATRIX: Instantiates standard terminal sessions inside your fullscreen layout
    {
      "<A-t>",
      function()
        toggle_claude_code("terminal")
      end,
      mode = { "n", "t" },
      desc = "Spawn New Shell Terminal",
      silent = true,
    },
  },
}

return M
