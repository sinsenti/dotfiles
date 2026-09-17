local M = {}
local terminal = require("config.functions.terminal")

local environments = { "dev", "prod", "all" }
local fallback_agents = {
  "quote",
  "dashboard-api",
  "internal-email-listener",
  "customer-email-listener",
}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "A1AWS" })
end

local function has_a1aws()
  if vim.fn.executable("a1aws") == 1 then
    return true
  end

  notify("a1aws was not found on PATH", vim.log.levels.ERROR)
  return false
end

local function open_terminal(command, title, auto_close)
  terminal.toggle_terminal_command(command, {
    name = title,
    auto_close = auto_close,
    start_insert = auto_close,
    auto_insert = auto_close,
    win = {
      title = title,
      title_pos = "center",
    },
  })
end

local function agents()
  if vim.fn.executable("a1aws") ~= 1 or not vim.system then
    return fallback_agents
  end

  local result = vim.system({ "a1aws", "agents" }, { text = true }):wait()
  if result.code ~= 0 then
    return fallback_agents
  end

  local names = {}
  for line in (result.stdout or ""):gmatch("[^\r\n]+") do
    local name = line:match("^%s*(%S+)%s+%S+%s+%S+")
    if name and name ~= "agent" then
      table.insert(names, name)
    end
  end

  return #names > 0 and names or fallback_agents
end

local function select_value(items, prompt, callback, format_item)
  vim.ui.select(items, {
    prompt = prompt,
    format_item = format_item,
  }, callback)
end

local function input_value(prompt, default, callback)
  vim.ui.input({ prompt = prompt, default = default or "" }, callback)
end

local function select_environment(callback)
  select_value(environments, "A1AWS environment", callback)
end

local function select_agent_environment(callback)
  select_value(agents(), "A1AWS agent", function(agent)
    if not agent then
      return
    end

    select_environment(function(environment)
      if environment then
        callback(agent, environment)
      end
    end)
  end)
end

local function run_simple(command, title)
  open_terminal(command, title, false)
end

local function run_log_command(command, title, auto_close)
  open_terminal(command, title, auto_close)
end

local log_actions = {
  { value = "tail", label = "Tail live logs" },
  { value = "since", label = "Show logs since a duration" },
  { value = "latest", label = "Open the latest full stream" },
  { value = "grep", label = "Search logs" },
  { value = "stream", label = "Open a specific stream" },
}

local function run_log_action(action)
  select_agent_environment(function(agent, environment)
    if action == "tail" then
      run_log_command(
        { "a1aws", "logs", "tail", agent, environment, "--json" },
        string.format("A1AWS tail: %s/%s", agent, environment),
        true
      )
      return
    end

    if action == "since" then
      input_value("Duration (for example 2h): ", "2h", function(duration)
        if duration == nil or duration == "" then
          return
        end

        run_log_command(
          { "a1aws", "logs", "since", agent, duration, environment, "--json" },
          string.format("A1AWS since %s: %s/%s", duration, agent, environment),
          false
        )
      end)
      return
    end

    if action == "latest" then
      run_log_command(
        { "a1aws", "logs", "latest", agent, environment, "--json" },
        string.format("A1AWS latest: %s/%s", agent, environment),
        true
      )
      return
    end

    if action == "grep" then
      local default_pattern = vim.fn.expand("<cword>")
      input_value("CloudWatch filter pattern: ", default_pattern, function(pattern)
        if pattern == nil or pattern == "" then
          return
        end

        input_value("Duration (for example 1h): ", "1h", function(duration)
          if duration == nil or duration == "" then
            return
          end

          run_log_command(
            { "a1aws", "logs", "grep", agent, pattern, environment, duration, "--json" },
            string.format("A1AWS grep: %s/%s", agent, environment),
            true
          )
        end)
      end)
      return
    end

    input_value("Stream name or task ID: ", "", function(stream)
      if stream == nil or stream == "" then
        return
      end

      run_log_command(
        { "a1aws", "logs", "stream", agent, stream, environment, "--json" },
        string.format("A1AWS stream: %s/%s", agent, environment),
        true
      )
    end)
  end)
end

function M.a1aws_logs()
  if not has_a1aws() then
    return
  end

  select_value(log_actions, "A1AWS logs", function(action)
    if action then
      run_log_action(action.value)
    end
  end, function(item)
    return item.label
  end)
end

local main_actions = {
  { value = "logs", label = "Logs" },
  { value = "env", label = "Deployed environment" },
  { value = "agents", label = "List agents" },
  { value = "whoami", label = "Who am I?" },
  { value = "login", label = "AWS SSO login" },
  { value = "help", label = "Show a1aws help" },
}

function M.a1aws()
  if not has_a1aws() then
    return
  end

  select_value(main_actions, "A1AWS", function(action)
    if not action then
      return
    end

    if action.value == "logs" then
      M.a1aws_logs()
      return
    end

    if action.value == "agents" then
      run_simple({ "a1aws", "agents" }, "A1AWS agents")
      return
    end

    if action.value == "help" then
      run_simple({ "a1aws", "help" }, "A1AWS help")
      return
    end

    if action.value == "whoami" or action.value == "login" then
      select_environment(function(environment)
        local command = { "a1aws", action.value, environment }
        run_simple(command, "A1AWS " .. action.value)
      end)
      return
    end

    select_agent_environment(function(agent, environment)
      run_simple({ "a1aws", "env", agent, environment }, string.format("A1AWS env: %s/%s", agent, environment))
    end)
  end, function(item)
    return item.label
  end)
end

vim.api.nvim_create_user_command("A1Aws", function()
  M.a1aws()
end, { desc = "Open the A1AWS command menu" })

vim.api.nvim_create_user_command("A1AwsLogs", function()
  M.a1aws_logs()
end, { desc = "Open the A1AWS logs menu" })

return M
