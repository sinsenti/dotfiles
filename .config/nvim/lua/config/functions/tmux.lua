local M = {}
local terminal = require("config.functions.terminal")

function M.a1labs_workmux_dashboard()
  local root = vim.fn.fnamemodify(vim.fn.expand(vim.env.A1LABS_ROOT or "~/git/project/a1labs"), ":p")
  if vim.fn.isdirectory(root) == 0 then
    vim.notify("A1Labs root not found: " .. root, vim.log.levels.ERROR, { title = "Workmux" })
    return
  end
  if vim.fn.executable("workmux") == 0 then
    vim.notify("workmux is not available on PATH", vim.log.levels.ERROR, { title = "Workmux" })
    return
  end

  terminal.focus_terminal_command({ "workmux", "dashboard" }, {
    cwd = root,
    name = "workmux: dashboard",
    win = { title = "workmux: dashboard", title_pos = "center" },
  })
end

function M.tmux_next_window()
  if vim.env.TMUX then
    vim.fn.system("tmux next-window")
  else
    vim.notify("Not running inside a Tmux session", vim.log.levels.WARN)
  end
end

function M.tmux_previous_window()
  if vim.env.TMUX then
    vim.fn.system("tmux previous-window")
  else
    vim.notify("Not running inside a Tmux session", vim.log.levels.WARN)
  end
end
function M.tmux_kill_pane()
  if vim.env.TMUX then
    vim.fn.system("tmux kill-pane")
  else
    vim.notify("Not running inside a Tmux session", vim.log.levels.WARN)
  end
end

function M.tmux_split_horizontal()
  if not vim.env.TMUX then
    vim.notify("Not running inside a Tmux session", vim.log.levels.WARN)
    return
  end

  local output = vim.fn.system('tmux display-message -p "#{window_panes}"')
  local pane_count = tonumber(vim.trim(output))

  if pane_count and pane_count > 1 then
    vim.fn.system("tmux select-pane -t :.+")
  else
    vim.fn.system('tmux split-window -h -c "#{pane_current_path}"')
  end
end
function M.tmux_split_vertical()
  if vim.env.TMUX then
    vim.fn.system('tmux split-window -v -c "#{pane_current_path}"')
  else
    vim.notify("Not running inside a Tmux session", vim.log.levels.WARN)
  end
end

function M.tmux_create_window()
  if vim.env.TMUX then
    vim.fn.system('tmux new-window -c "#{pane_current_path}"')
  else
    vim.notify("Not running inside a Tmux session", vim.log.levels.WARN)
  end
end

function M.search_tmux_windows()
  if not vim.env.TMUX then
    vim.notify("Not running inside a Tmux session", vim.log.levels.WARN)
    return
  end

  local windows =
    vim.fn.systemlist([[tmux list-windows -F "#{window_index}: #{window_name}#{?window_active, (active),}"]])
  if vim.v.shell_error ~= 0 or #windows == 0 then
    vim.notify("Could not fetch Tmux windows", vim.log.levels.ERROR)
    return
  end

  -- Move the currently active window to the bottom of the list
  local items = {}
  local active_item = nil

  for _, win in ipairs(windows) do
    if win:match("%(active%)") then
      active_item = win
    else
      table.insert(items, win)
    end
  end

  if active_item then
    table.insert(items, active_item)
  end

  -- Helper function to resolve zoxide path and open tmux window
  local function create_window_from_query(query)
    query = (query and query:gsub("^%s*(.-)%s*$", "%1")) or ""
    if query == "" then
      vim.fn.system("tmux new-window")
      return
    end

    -- Run zoxide to find a matching path
    local z_path = vim.fn.system({ "zoxide", "query", query }):gsub("%s+$", "")

    if vim.v.shell_error == 0 and z_path ~= "" then
      local folder_name = vim.fn.fnamemodify(z_path, ":t")
      vim.fn.system({ "tmux", "new-window", "-c", z_path, "-n", folder_name })
    else
      -- Fallback to opening standard window with query as name if zoxide has no match
      vim.fn.system({ "tmux", "new-window", "-n", query })
      vim.notify("Created new Tmux window: " .. query, vim.log.levels.INFO)
    end
  end

  require("fzf-lua").fzf_exec(items, {
    prompt = "Tmux Windows> ",
    fzf_opts = { ["--no-sort"] = "" },
    actions = {
      ["default"] = function(selected, opts)
        -- 1. Switch to selected window if a match was found
        if selected and #selected > 0 then
          local window_idx = selected[1]:match("^(%d+):")
          if window_idx then
            vim.fn.system("tmux select-window -t " .. window_idx)
            return
          end
        end

        -- 2. Fallback: Query zoxide and create window
        create_window_from_query(opts and opts.last_query)
      end,

      -- Press Ctrl-a to force-create window via zoxide search
      ["ctrl-a"] = function(_, opts)
        create_window_from_query(opts and opts.last_query)
      end,
    },
  })
end

return M
