local M = {}

for _, module_name in ipairs({
  "markdown",
  "scratchpads",
  "git",
  "filesystem",
  "terminal",
  "json",
  "tmux",
  "commands",
  "helpers",
  "aws",
}) do
  local module = require("config.functions." .. module_name)
  M = vim.tbl_extend("force", M, module)
end

return M
