local M = {}
local terminal = require("config.functions.terminal")

local standard_venvs = { ".venv", "venv", "env" }
local ignored_parts = {
  ".git",
  ".venv",
  "venv",
  "env",
  "__pycache__",
  ".pytest_cache",
  ".tox",
  "build",
  "dist",
}

local function display_path(path)
  return vim.fn.fnamemodify(path, ":~")
end

local function is_file(path)
  return vim.fn.filereadable(path) == 1
end

local function normalize_dir(path)
  path = path ~= nil and path ~= "" and path or vim.fn.getcwd()
  path = vim.fn.fnamemodify(path, ":p")
  if vim.fn.isdirectory(path) == 0 then
    path = vim.fn.fnamemodify(path, ":h")
  end
  return vim.fs.normalize(path)
end

local function ancestor_dirs(start, limit)
  local dirs = {}
  local dir = normalize_dir(start)

  for _ = 1, limit do
    dirs[#dirs + 1] = dir
    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end

  return dirs
end

local function custom_venv_python_paths(dir)
  local paths = {}
  local seen = {}

  for _, pattern in ipairs({
    vim.fs.joinpath(dir, "*/bin/python"),
    vim.fs.joinpath(dir, ".[A-Za-z0-9_]*/bin/python"),
  }) do
    for _, path in ipairs(vim.fn.glob(pattern, false, true)) do
      if is_file(path) and not seen[path] then
        paths[#paths + 1] = path
        seen[path] = true
      end
    end
  end

  table.sort(paths)
  return paths
end

local function runner_in_directory(dir)
  if
    vim.fn.executable("uv") == 1
    and (is_file(vim.fs.joinpath(dir, "pyproject.toml")) or is_file(vim.fs.joinpath(dir, "uv.lock")))
  then
    return {
      command = { "uv", "run", "--project", dir, "python" },
      label = "uv (" .. display_path(dir) .. ")",
    }
  end

  for _, venv_name in ipairs(standard_venvs) do
    local python = vim.fs.joinpath(dir, venv_name, "bin", "python")
    if is_file(python) then
      if vim.fn.executable("uv") == 1 then
        return {
          command = { "uv", "run", "--python", python, "python" },
          label = "uv (" .. display_path(dir) .. "/" .. venv_name .. ")",
        }
      end

      return {
        command = { python },
        label = "venv (" .. display_path(dir) .. "/" .. venv_name .. ")",
      }
    end
  end

  local custom_paths = custom_venv_python_paths(dir)
  if #custom_paths == 1 then
    return {
      command = { custom_paths[1] },
      label = display_path(vim.fn.fnamemodify(custom_paths[1], ":h:h")),
    }
  end

  if #custom_paths > 1 then
    local choices = {}
    for _, python in ipairs(custom_paths) do
      choices[#choices + 1] = {
        command = { python },
        label = display_path(vim.fn.fnamemodify(python, ":h:h")),
      }
    end
    return nil, choices
  end
end

local function fallback_runner()
  for _, executable in ipairs({ "python3", "python" }) do
    if vim.fn.executable(executable) == 1 then
      return { command = { executable }, label = executable }
    end
  end
end

local function resolve_runner(start, callback)
  for _, dir in ipairs(ancestor_dirs(start, 4)) do
    local runner, choices = runner_in_directory(dir)
    if runner then
      callback(runner)
      return
    end

    if choices then
      vim.ui.select(choices, {
        prompt = "Select Python environment",
        format_item = function(choice)
          return choice.label
        end,
      }, function(choice)
        if choice then
          callback(choice)
        end
      end)
      return
    end
  end

  local runner = fallback_runner()
  if runner then
    callback(runner)
  else
    vim.notify("No Python interpreter found on PATH", vim.log.levels.ERROR, { title = "Python" })
  end
end

local function ignored_path(path)
  for _, part in ipairs(ignored_parts) do
    if path:find("/" .. part .. "/", 1, true) or path:match("^" .. part .. "/") then
      return true
    end
  end
  return false
end

local function python_files(cwd)
  local files = {}
  local seen = {}

  if vim.fn.executable("fd") == 1 and vim.system then
    local result = vim
      .system({
        "fd",
        "--type",
        "f",
        "--extension",
        "py",
        "--hidden",
        "--exclude",
        ".git",
        "--exclude",
        ".venv",
        "--exclude",
        "venv",
        "--exclude",
        "env",
        "--exclude",
        "__pycache__",
        "--exclude",
        ".pytest_cache",
        "--exclude",
        ".tox",
        "--exclude",
        "build",
        "--exclude",
        "dist",
      }, { cwd = cwd, text = true })
      :wait()

    if result.code == 0 then
      for line in (result.stdout or ""):gmatch("[^\r\n]+") do
        local path = vim.fs.joinpath(cwd, line)
        if not seen[path] then
          files[#files + 1] = path
          seen[path] = true
        end
      end
    end
  end

  if #files == 0 then
    for _, path in ipairs(vim.fn.globpath(cwd, "**/*.py", false, true)) do
      if not ignored_path(path) and not seen[path] then
        files[#files + 1] = path
        seen[path] = true
      end
    end
  end

  table.sort(files)
  return files
end

local function pick_python_file(callback)
  local cwd = normalize_dir(vim.fn.getcwd())
  local files = python_files(cwd)
  if #files == 0 then
    vim.notify("No Python files found in " .. display_path(cwd), vim.log.levels.INFO, { title = "Python" })
    return
  end

  local entries = {}
  local lookup = {}
  for _, path in ipairs(files) do
    local entry = vim.fn.fnamemodify(path, ":.")
    entries[#entries + 1] = entry
    lookup[entry] = path
  end

  local function choose(entry)
    if entry and lookup[entry] then
      callback(lookup[entry])
    end
  end

  local ok, fzf = pcall(require, "fzf-lua")
  if ok then
    fzf.fzf_exec(entries, {
      prompt = "Python> ",
      fzf_opts = { ["--no-sort"] = "" },
      actions = {
        ["default"] = function(selected)
          choose(selected and selected[1])
        end,
      },
    })
    return
  end

  vim.ui.select(entries, { prompt = "Select Python file" }, choose)
end

local function run_file(file)
  file = vim.fn.fnamemodify(vim.fn.expand(file), ":p")
  if not is_file(file) then
    vim.notify("Python file not found: " .. file, vim.log.levels.ERROR, { title = "Python" })
    return
  end

  if not file:match("%.py$") then
    vim.notify("Not a Python file: " .. file, vim.log.levels.WARN, { title = "Python" })
    return
  end

  local current_file = vim.fn.expand("%:p")
  if current_file == file and vim.bo.modified then
    vim.cmd("update")
  end

  resolve_runner(vim.fn.fnamemodify(file, ":h"), function(runner)
    local command = vim.deepcopy(runner.command)
    command[#command + 1] = file

    local name = "python: " .. vim.fn.fnamemodify(file, ":t")
    terminal.toggle_terminal_command(command, {
      cwd = vim.fn.getcwd(),
      name = name,
      interactive = false,
      win = { title = name, title_pos = "center" },
    })
  end)
end

-- Run the current Python buffer, or open a picker when the current buffer is
-- not a Python file. The environment search mirrors the zsh py() helper while
-- using argument arrays instead of eval.
function M.py(file)
  if file and file ~= "" then
    run_file(file)
    return
  end

  local current_file = vim.fn.expand("%:p")
  if vim.bo.filetype == "python" and is_file(current_file) then
    run_file(current_file)
  else
    pick_python_file(run_file)
  end
end

vim.api.nvim_create_user_command("RunPython", function(opts)
  M.py(opts.args ~= "" and opts.args or nil)
end, {
  nargs = "?",
  complete = "file",
  desc = "Run a Python file with the nearest project environment",
})

return M
