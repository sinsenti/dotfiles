-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local opts = { noremap = true, silent = true }

local function a(desctiption)
  return vim.tbl_deep_extend("force", opts, { desc = desctiption })
end

-- vim.keymap.set("n", "<leader>z", "<leader>uZ", a("toggle zoom mode"))
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
vim.keymap.set("n", "<leader>mt", ":source Session.vim<cr>", a("Toggle Session"))

-- vim.keymap.set("n", "<leader>gg", ":Neogit<cr>", opts)
vim.keymap.set("n", "<leader>gg", ":Neogit cwd=%:p:h<cr>", opts)
-- vim.keymap.set("n", "<leader>gc", ":Neogit commit<cr>", opts)
-- vim.keymap.set("n", "<leader>gp", ":Neogit pull<cr>", opts)
-- vim.keymap.set("n", "<leader>gP", ":Neogit push<cr>", opts)
vim.keymap.set("n", "<leader>ga", ":Git add .<cr>", opts)
-- vim.keymap.set('n', '<leader>gb', ':Telescope git_branches<cr>', opts)
-- vim.keymap.set('n', '<leader>gB', ':G blame<cr>', opts)
-- vim.keymap.set('n', '<leader>gg', ':Git ', { desc = 'Git' })
--
-- vim.keymap.set('n', '<leader>e', ':GoIfErr<cr>', opts)

vim.api.nvim_set_keymap("n", "tw", ":Twilight<cr>", opts)
vim.api.nvim_set_keymap("n", "QQ", ":q<cr>", opts)
vim.api.nvim_set_keymap("n", "WW", ":w<cr>", opts)
vim.api.nvim_set_keymap("n", "WQ", ":wqa<cr>", opts)
vim.api.nvim_set_keymap("n", "<c-s>", ":w<cr>", opts)
vim.api.nvim_set_keymap("n", "TT", ":TransparentToggle<cr>", opts)
vim.api.nvim_set_keymap("n", "E", "$", opts)
vim.api.nvim_set_keymap("n", "B", "^", opts)
vim.keymap.set("n", "<Up>", ":resize -2<cr>", opts)
vim.keymap.set("n", "<Down>", ":resize +2<cr>", opts)
vim.keymap.set("n", "<Left>", ":vertical resize -2<cr>", opts)
vim.keymap.set("n", "<Right>", ":vertical resize +2<cr>", opts)
vim.keymap.set("n", "<Esc>", ":noh<cr>:NoiceDismiss<cr>", opts)
vim.keymap.set("i", "jk", "<Esc>", opts)
vim.keymap.set("i", "ол", "<Esc>", opts)
vim.keymap.set("i", "Jk", "<Esc>", opts)
vim.keymap.set("i", "JK", "<Esc>", opts)
vim.keymap.set("n", "ss", ":vsplit<Return>", opts)
vim.keymap.set("n", "sv", ":split<Return>", opts)
vim.keymap.set("n", "te", ":tabedit<cr>", opts)
-- vim.keymap.set('n', '<tab>', ':tabnext<Return>', opts)
-- vim.keymap.set('n', '<s-tab>', ':tabprev<Return>', opts)

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

-- vim.keymap.set("n", "<leader>md", function()
--   vim.cmd("ZenMode")
--   -- vim.cmd('set spell!')
--   vim.cmd("PencilSoft")
--   vim.cmd("Twilight")
-- end, { desc = "Toggle Zenmode and pensil" })
