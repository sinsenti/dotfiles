local M = {}

for _, module_name in ipairs({ "markdown", "scratchpads", "git", "tmux", "filesystem" }) do
  local module = require("config.functions." .. module_name)
  M = vim.tbl_extend("force", M, module)
end

return M
