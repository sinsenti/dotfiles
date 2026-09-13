local M = {}

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

function M.toggle_diffview_commit()
  local has_diffview, diffview_lib = pcall(require, "diffview.lib")
  if has_diffview and next(diffview_lib.views) ~= nil then
    vim.cmd("DiffviewClose")
    return
  end

  require("snacks").picker.git_log({
    confirm = function(picker, item)
      picker:close()

      if not item then
        return
      end

      local commit = item.commit
        or item.hash
        or (item.data and (item.data.commit or item.data.hash))
        or (item.data and item.data.oid)

      if not commit then
        vim.notify("No commit hash found: " .. vim.inspect(item), vim.log.levels.ERROR)
        return
      end

      vim.cmd("DiffviewOpen " .. commit)
      vim.cmd("DiffviewToggleFiles")
    end,
  })
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
          vim.cmd("DiffviewToggleFiles")
        end
      end,
    })
  end
end

function M.toggle_diffview()
  local has_diffview, diffview_lib = pcall(require, "diffview.lib")
  if has_diffview and next(diffview_lib.views) == nil then
    vim.cmd("DiffviewOpen")
    vim.cmd("DiffviewToggleFiles")
  else
    vim.cmd("DiffviewClose")
  end
end

-- =============================================================================
-- 5. OTHER MISCELLANEOUS SYSTEM UTILITIES
-- =============================================================================


return M
