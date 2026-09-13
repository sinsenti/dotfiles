local M = {}

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
