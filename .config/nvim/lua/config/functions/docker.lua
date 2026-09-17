local M = {}
local terminal = require("config.functions.terminal")

local compose_project = "a1labs"

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "A1Labs Docker" })
end

local function docker_available()
  if vim.fn.executable("docker") == 1 and vim.system then
    return true
  end

  notify("docker is not available on PATH", vim.log.levels.ERROR)
  return false
end

local function run(command, cwd)
  return vim.system(command, { cwd = cwd, text = true }):wait()
end

local function git_command(args, cwd)
  return vim.list_extend({ "git", "-C", cwd }, args)
end

local function repository_root(start)
  local result = run(git_command({ "rev-parse", "--show-toplevel" }, start), start)
  if result.code ~= 0 then
    notify("The current directory is not inside a Git repository", vim.log.levels.WARN)
    return nil
  end

  return vim.trim(result.stdout or "")
end

local function parse_worktrees(output)
  local worktrees = {}
  local current

  local function finish()
    if current then
      table.insert(worktrees, current)
    end
  end

  for _, line in ipairs(vim.split(output or "", "\n", { trimempty = true })) do
    local path = line:match("^worktree (.+)$")
    if path then
      finish()
      current = { path = path, branch = "detached HEAD" }
    elseif current then
      local branch = line:match("^branch refs/heads/(.+)$")
      if branch then
        current.branch = branch
      elseif line == "detached" then
        current.branch = "detached HEAD"
      end
    end
  end
  finish()

  return worktrees
end

local function list_worktrees(root)
  local result = run(git_command({ "worktree", "list", "--porcelain" }, root), root)
  if result.code ~= 0 then
    notify("Could not list Git worktrees", vim.log.levels.ERROR)
    return nil
  end

  local worktrees = parse_worktrees(result.stdout)
  if #worktrees == 0 then
    notify("No Git worktrees found", vim.log.levels.WARN)
    return nil
  end

  return worktrees
end

local function select_worktree(worktrees, current_root, callback, all_logs_callback)
  local ordered = {}
  for _, worktree in ipairs(worktrees) do
    if worktree.path == current_root then
      table.insert(ordered, 1, worktree)
    else
      table.insert(ordered, worktree)
    end
  end

  local entries = {
    { all_logs = true, label = "1. All logs (all services)" },
  }
  for index, worktree in ipairs(ordered) do
    local marker = worktree.path == current_root and "* " or "  "
    table.insert(entries, {
      worktree = worktree,
      label = string.format(
        "%d. %s%s  [%s]",
        index + 1,
        marker,
        vim.fn.fnamemodify(worktree.path, ":~"),
        worktree.branch
      ),
    })
  end

  local labels = {}
  local lookup = {}
  for _, entry in ipairs(entries) do
    labels[#labels + 1] = entry.label
    lookup[entry.label] = entry
  end

  local function choose(label)
    local entry = label and lookup[label]
    if not entry then
      return
    end

    if entry.all_logs then
      all_logs_callback()
    else
      callback(entry.worktree)
    end
  end

  -- Use a dedicated picker here so the worktree list has enough room for the
  -- whole project instead of inheriting the compact ui_select height.
  local ok, fzf = pcall(require, "fzf-lua")
  if ok then
    fzf.fzf_exec(labels, {
      prompt = "A1Labs Docker worktree> ",
      fzf_opts = { ["--no-sort"] = "" },
      winopts = {
        width = 0.8,
        height = math.min(math.max(#labels + 6, 12), math.floor(vim.o.lines * 0.9)),
      },
      actions = {
        ["default"] = function(selected)
          choose(selected and selected[1])
        end,
      },
    })
    return
  end

  vim.ui.select(entries, {
    prompt = "A1Labs Docker worktree",
    format_item = function(entry)
      return entry.label
    end,
  }, function(entry)
    if entry then
      choose(entry.label)
    end
  end)
end

local function copy_main_env(main_worktree, selected_worktree)
  local source = vim.fs.joinpath(main_worktree, ".env")
  local destination = vim.fs.joinpath(selected_worktree, ".env")
  if source == destination or vim.fn.filereadable(destination) == 1 or vim.fn.filereadable(source) == 0 then
    return
  end

  local uv = vim.uv or vim.loop
  local ok, error_message = uv.fs_copyfile(source, destination)
  if ok then
    notify("Copied .env from the main worktree", vim.log.levels.INFO)
  else
    notify("Could not copy .env: " .. tostring(error_message), vim.log.levels.ERROR)
  end
end

local function compose_command(args, cwd, project)
  return vim.list_extend({ "docker", "compose", "-p", project or compose_project }, args), cwd
end

local function compose_context(cwd, project)
  project = project or compose_project
  local command = compose_command({ "config", "--services" }, cwd, project)
  local result = run(command, cwd)
  if result.code ~= 0 then
    notify("No usable Docker Compose configuration found in the selected worktree", vim.log.levels.ERROR)
    return nil
  end

  local services = vim.split(vim.trim(result.stdout or ""), "\n", { trimempty = true })
  table.sort(services)
  if #services == 0 then
    notify("The A1Labs Compose project has no services", vim.log.levels.WARN)
    return nil
  end

  return { cwd = cwd, services = services, project = project }
end

local function open_compose_terminal(args, cwd, name, project)
  local command = compose_command(args, cwd, project)
  terminal.toggle_terminal_command(command, {
    cwd = cwd,
    name = name,
    interactive = false,
    win = { title = name, title_pos = "center" },
  })
end

local function open_json_log_terminal(context, service)
  local service_arg = service and (" " .. vim.fn.shellescape(service)) or ""
  local command = string.format(
    "docker compose -p %s logs -f --no-color --no-log-prefix%s | jq --unbuffered -RrC 'fromjson? // .'",
    vim.fn.shellescape(context.project or compose_project),
    service_arg
  )
  local name = service and ("logs: " .. service) or "logs: all services"
  terminal.toggle_terminal_command({ vim.o.shell, "-c", command }, {
    cwd = context.cwd,
    name = name,
    interactive = false,
    win = { title = name, title_pos = "center" },
  })
end

local function open_all_json_logs(context)
  open_json_log_terminal(context)
end

local function open_json_logs(context)
  local targets = { { value = nil, label = "All services (default)" } }
  for _, service in ipairs(context.services) do
    table.insert(targets, { value = service, label = service })
  end
  for index, target in ipairs(targets) do
    target.label = string.format("%d. %s", index, target.label)
  end

  vim.ui.select(targets, {
    prompt = "A1Labs logs (select service)",
    format_item = function(target)
      return target.label
    end,
  }, function(target)
    if not target then
      return
    end

    open_json_log_terminal(context, target.value)
  end)
end

function M.a1labs_docker_logs(cwd, project)
  if not docker_available() then
    return
  end

  cwd = cwd and vim.fn.fnamemodify(vim.fn.expand(cwd), ":p") or vim.fn.getcwd()
  local context = compose_context(cwd, project)
  if context then
    open_json_logs(context)
  end
end

local function running_containers(context)
  local command =
    compose_command({ "ps", "--format", "{{.Name}}|{{.Service}}|{{.State}}|{{.Image}}" }, context.cwd, context.project)
  local result = run(command, context.cwd)
  if result.code ~= 0 then
    notify("Could not list running Compose containers", vim.log.levels.ERROR)
    return {}
  end

  local containers = {}
  for _, line in ipairs(vim.split(vim.trim(result.stdout or ""), "\n", { trimempty = true })) do
    local fields = vim.split(line, "|", { plain = true })
    if fields[1] and fields[1] ~= "" then
      table.insert(containers, {
        name = fields[1],
        label = string.format(
          "%s  (%s)  %s%s",
          fields[1],
          fields[2] or "unknown service",
          fields[3] or "unknown state",
          fields[4] and fields[4] ~= "" and "  " .. fields[4] or ""
        ),
      })
    end
  end

  return containers
end

local function open_container_shell(context)
  local containers = running_containers(context)
  if #containers == 0 then
    notify("No running containers in the selected worktree", vim.log.levels.INFO)
    return
  end

  vim.ui.select(containers, {
    prompt = "A1Labs container shell",
    format_item = function(container)
      return container.label
    end,
  }, function(container)
    if not container then
      return
    end

    local name = "shell: " .. container.name
    terminal.toggle_terminal_command(
      { "docker", "exec", "-it", container.name, "sh", "-c", "exec bash 2>/dev/null || exec sh" },
      {
        cwd = context.cwd,
        name = name,
        win = { title = name, title_pos = "center" },
      }
    )
  end)
end

local function open_custom_compose_command(context)
  vim.ui.input({
    prompt = "docker compose command: ",
    completion = "shellcmdline",
  }, function(args)
    args = args and vim.trim(args) or ""
    if args == "" then
      return
    end

    local command =
      string.format("docker compose -p %s %s", vim.fn.shellescape(context.project or compose_project), args)
    local name = "compose: " .. args
    terminal.toggle_terminal_command({ vim.o.shell, "-c", command }, {
      cwd = context.cwd,
      name = name,
      interactive = false,
      win = { title = name, title_pos = "center" },
    })
  end)
end

local actions = {
  { value = "build", label = "Build and start services" },
  { value = "logs", label = "Logs (JSON formatted)" },
  { value = "up", label = "Start Compose" },
  { value = "down", label = "Stop Compose (down)" },
  { value = "status", label = "Compose status" },
  { value = "shell", label = "Open a container shell" },
  { value = "command", label = "Run a Compose command" },
}

for index, action in ipairs(actions) do
  action.label = string.format("%d. %s", index, action.label)
end

local function select_action(context)
  vim.ui.select(actions, {
    prompt = "A1Labs Docker action",
    format_item = function(action)
      return action.label
    end,
  }, function(action)
    if not action then
      return
    end

    if action.value == "logs" then
      open_json_logs(context)
    elseif action.value == "build" then
      open_compose_terminal({ "up", "-d", "--build" }, context.cwd, "build: a1labs", context.project)
    elseif action.value == "up" then
      open_compose_terminal({ "up", "-d" }, context.cwd, "up: a1labs", context.project)
    elseif action.value == "down" then
      local confirm_down = "Yes, run docker compose down"
      vim.ui.select({ "Cancel", confirm_down }, {
        prompt = "Stop and remove the A1Labs Compose resources?",
      }, function(choice)
        if choice == confirm_down then
          open_compose_terminal({ "down" }, context.cwd, "down: a1labs", context.project)
        end
      end)
    elseif action.value == "status" then
      open_compose_terminal({ "ps" }, context.cwd, "status: a1labs", context.project)
    elseif action.value == "shell" then
      open_container_shell(context)
    elseif action.value == "command" then
      open_custom_compose_command(context)
    end
  end)
end

function M.a1labs_docker_menu()
  if not docker_available() then
    return
  end

  -- A1Labs is a fixed project entry point. The menu therefore works from any
  -- Neovim directory instead of depending on the current buffer's directory.
  local configured_root = vim.env.A1LABS_ROOT or "~/git/project/a1labs"
  local default_root = vim.fn.fnamemodify(vim.fn.expand(configured_root), ":p")
  if vim.fn.isdirectory(default_root) == 0 then
    notify("A1Labs root not found: " .. default_root, vim.log.levels.ERROR)
    return
  end

  local current_root = repository_root(default_root)
  if not current_root then
    return
  end

  local worktrees = list_worktrees(current_root)
  if not worktrees then
    return
  end

  select_worktree(worktrees, current_root, function(worktree)
    copy_main_env(worktrees[1].path, worktree.path)
    local context = compose_context(worktree.path)
    if context then
      select_action(context)
    end
  end, function()
    local main_worktree = worktrees[1] and worktrees[1].path or current_root
    local context = compose_context(main_worktree)
    if context then
      open_all_json_logs(context)
    end
  end)
end

return M
