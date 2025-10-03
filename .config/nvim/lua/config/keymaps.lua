local opts = { noremap = true, silent = true }

local function a(desctiption)
  return vim.tbl_deep_extend("force", opts, { desc = desctiption })
end

vim.keymap.set("n", "<leader>mp", ":MarkdownPreview<CR>", a("preview of .md"))
vim.keymap.set("n", "<leader>oa", ":ObsidianToggleCheckbox<CR>04la<space><space><space><esc>0", a("Add in obsidian"))

vim.keymap.set("n", "<leader>re", ":MoltenEvaluateOperator<CR>", { desc = "evaluate operator", silent = true })
vim.keymap.set("n", "<leader>ro", ":noautocmd MoltenEnterOutput<CR>", { desc = "open output window", silent = true })
vim.keymap.set("n", "<leader>rr", ":MoltenReevaluateCell<CR>", { desc = "re-eval cell", silent = true })
vim.keymap.set(
  "v",
  "<leader>r",
  ":<C-u>MoltenEvaluateVisual<CR>gv",
  { desc = "execute visual selection", silent = true }
)
vim.keymap.set("n", "<leader>rh", ":MoltenEvaluateLine<CR>", { desc = "evaluate line", silent = true })
vim.keymap.set("n", "<leader>rh", ":MoltenHideOutput<CR>", { desc = "close output window", silent = true })
vim.keymap.set("n", "<leader>dd", ":MoltenDelete<CR>", { desc = "delete Molten cell", silent = true })
vim.keymap.set("n", "<leader>rx", ":MoltenOpenInBrowser<CR>", { desc = "open output in browser", silent = true })
vim.keymap.set("n", "<leader>rd", ":MoltenDeinit<CR>", { desc = "deinit ", silent = true })

vim.keymap.set("n", "<leader>z", ":ZenMode<CR>", a("toggle zoom mode"))
vim.keymap.set("n", "<leader>y", "ggyG", a("copy full file"))
vim.keymap.set("n", "<leader>p", "<esc>ggVGp", a("change full file"))
vim.keymap.set("n", "<c-h>", ":TmuxNavigateLeft<CR>", opts)
vim.keymap.set("n", "<c-l>", ":TmuxNavigateRight<CR>", opts)
vim.keymap.set("n", "<c-j>", ":TmuxNavigateDown<CR>", opts)
vim.keymap.set("n", "<c-k>", ":TmuxNavigateUp<CR>", opts)

vim.keymap.set("n", "<leader>-", ":Oil<CR>", opts)

vim.keymap.set("t", "jk", "<C-\\><C-n>", opts)
vim.keymap.set("n", "<leader>df", ":DeleteFile", {})

vim.keymap.set("i", "<C-h>", "<C-w>", opts)
vim.keymap.set("i", "<c-a>", "<Esc>mpggyG'p:delmarks p<cr>", opts)
vim.keymap.set("n", "<leader>mz", "bb]s1z=", a("Fix spelling mistake"))
vim.keymap.set("n", "<leader>ms", ":set spell!<cr>", a("Toggle spelling"))
vim.keymap.set("n", "<leader>mc", ":mksession!<cr>", a("[C]reate Session"))

vim.api.nvim_set_keymap("n", "tw", ":Twilight<cr>", opts)
vim.api.nvim_set_keymap("n", "QQ", ":q<cr>", opts)
vim.api.nvim_set_keymap("n", "WW", ":w<cr>", opts)
vim.api.nvim_set_keymap("n", "WQ", ":wqa<cr>", opts)
vim.api.nvim_set_keymap("n", "<c-s>", ":w<cr>", opts)
vim.api.nvim_set_keymap("n", "E", "$", opts)
vim.api.nvim_set_keymap("n", "B", "^", opts)
vim.keymap.set("n", "<Up>", ":resize -2<cr>", opts)
vim.keymap.set("n", "<Down>", ":resize +2<cr>", opts)
vim.keymap.set("n", "<Left>", ":vertical resize -2<cr>", opts)
vim.keymap.set("n", "<Right>", ":vertical resize +2<cr>", opts)
vim.keymap.set("n", "<Esc>", ":noh<cr>:NoiceDismiss<cr>", opts)
-- vim.keymap.set("i", "jk", "<Esc>", opts)
-- vim.keymap.set("i", "ОЛ", "<Esc>", opts)
-- vim.keymap.set("i", "Jk", "<Esc>", opts)
-- vim.keymap.set("i", "JK", "<Esc>", opts)
vim.keymap.set("n", "ss", ":vsplit<Return>", opts)
vim.keymap.set("n", "sv", ":split<Return>", opts)
vim.keymap.set("n", "<F5>", require("dap").step_into)

vim.keymap.set("n", "<leader>Fa", function()
  local codeium_config = require("codeium.config").options.virtual_text
  codeium_config.manual = not codeium_config.manual
  if codeium_config.manual then
    print("Codeium disabled")
  else
    print("Codeium enabled")
  end
end, { desc = "Toggle Codeium completion" })
vim.keymap.set("n", "<leader>oc", function()
  local ft = vim.bo.filetype
  if vim.tbl_contains({ "python", "yaml" }, ft) then
    vim.cmd([[g/^\s*#/d]])
    vim.cmd([[%s/#.*//]])
  elseif vim.tbl_contains({ "java", "c", "cpp", "cs", "javascript", "go" }, ft) then
    vim.cmd([[g@^\s*//@d]])
    vim.cmd([[%s@//.*@@]])
  end
end, opts)
vim.api.nvim_create_user_command("DeleteFile", function()
  vim.cmd("w")
  local file = vim.fn.expand("%:p")
  if vim.fn.filereadable(file) == 1 then
    vim.fn.delete(file)
  else
  end
  vim.cmd("bdelete")
end, { desc = "Delete the current file and buffer" })
vim.keymap.set("n", "<leader>cp", function()
  local filepath = vim.fn.expand("%:p")
  filepath = filepath:gsub("\\", "/") -- Replace backslashes with forward slashes
  filepath = filepath:gsub(" ", "\\ ") -- Escape spaces by adding a backslash before each
  vim.fn.setreg("+", filepath)
  print("Copied file path to clipboard: " .. filepath)
end, { desc = "Copy file path to clipboard with forward slashes and escaped spaces" })

-- vim.keymap.set("n", "<leader>t", function()
--   local current_dir = vim.fn.expand("%:p:h")
--   if current_dir == "" or vim.fn.isdirectory(current_dir) == 0 then
--     current_dir = vim.fn.getcwd()
--   end
--   local in_terminal = vim.bo.buftype == "terminal"
--   local current_file = vim.fn.expand("%:t")
--   local command = "python " .. current_file
--   vim.fn.setreg("+", command) -- '+' is the system clipboard register
--   if in_terminal then
--     vim.cmd("hide")
--   else
--     require("snacks").terminal("zsh", {
--       cwd = current_dir,
--       env = { TERM = "x-256color" },
--       win = {
--         style = "terminal",
--         relative = "editor",
--         -- height = 0.83,
--         height = 0.83,
--       },
--     })
--   end
-- end, { desc = "Toggle Terminal" })

vim.keymap.set("n", "<leader>DD", function()
  vim.cmd("w")
  local path = vim.fn.expand("%:p:r")
  path = vim.fn.substitute(path, "\\", "/", "g")
  local fileDir = vim.fn.expand("%:p:h")
  local command = "cd " .. fileDir .. " && " .. "clang++ --debug -o " .. path .. " " .. path .. ".cpp && " .. path
  vim.api.nvim_input("<C-/>")
  vim.defer_fn(function()
    vim.api.nvim_put({ command }, "l", true, true)
  end, 100)
end, opts)
