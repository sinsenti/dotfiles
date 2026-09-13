local M = {}

-- Shared float constructor. Callers still own buffer options and dimensions so
-- this helper does not change any existing scratchpad behavior.
function M.open_float(buf, width, height, row, col, opts)
  opts = opts or {}
  local config = {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = opts.style or "minimal",
    border = opts.border or "rounded",
  }

  if opts.title then
    config.title = opts.title
    config.title_pos = opts.title_pos or "center"
  end

  return vim.api.nvim_open_win(buf, true, config)
end

return M
