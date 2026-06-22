local map = vim.keymap.set
local opts = { noremap = true, silent = true }
local function a(desctiption)
  return vim.tbl_deep_extend("force", opts, { desc = desctiption })
end

local f = require("config.functions")

-- git

map("n", "<leader>mr", ":RenderMarkdown buf_toggle<cr>", a("toggle rendering .md"))
map("n", "<leader>gr", ":Git reset --soft HEAD~1<cr>", a("Git reset --soft HEAD~1"))
map("n", "<leader>hg", "<cmd>Neogit<cr>", { desc = "Git Status (Left Side)" })
map("n", "<leader>gg", f.open_neogit_in_current_dir, { desc = "Open neogit" })
map("n", "<leader>ga", f.show_git_status_noice, { desc = "Git Status Toast Notification" })
map("n", "<leader>gd", f.toggle_diffview, { desc = "Toggle Diffview" })
map("n", "<leader>gt", f.git_stash_with_prompt, { desc = "Git Stash All (Including Untracked)" })
map("n", "<leader>gc", f.git_commit_with_prompt, { desc = "Git Commit Staged Changes" })
map("n", "<leader>gs", f.toggle_diffview_branch, { desc = "Toggle Diffview against branch" })

map("n", "<leader>gw", ":FzfLua git_branches<cr>", a("git checkout"))
map("n", "<leader>gf", ":Gdiffsplit<cr>", a("File diff"))

map("n", "<leader>GG", ":vert Git<cr>", a("Git | only"))
map("n", "<leader>GA", ":Git add .<cr>", a("Git add ."))
map("n", "<leader>GM", ":vert Git commit<cr>", a("Git commit vertical"))
map("n", "<leader>GS", ":Neogit stash<cr>", a("Neogit stash"))

-- tabs

map("n", "<leader><tab><tab>", "<cmd>tabnext<cr>", { desc = "Next Tab" })
map("n", "<leader>tk", "<cmd>tabclose<cr>", { desc = "Close Tab" })
map("n", "<leader>to", "<cmd>tabonly<cr>", { desc = "Close Other Tabs" })
map("n", "<leader>tp", "<cmd>tabprevious<cr>", { desc = "Previous Tab" })
map("n", "<leader>tn", "<cmd>tabnext<cr>", { desc = "Next Tab" })
map("n", "<leader>tf", "<cmd>tabfirst<cr>", { desc = "First Tab" })
map("n", "<leader>tl", "<cmd>tablast<cr>", { desc = "Last Tab" })
map("n", "<leader>tt", "<cmd>tabnext<cr>", { desc = "Next Tab" })

-- navigation

map("v", "J", ":m '>+1<CR>gv=gv", a("move selected lines"))
map("v", "K", ":m '<-2<CR>gv=gv", a("move selected lines"))
map("n", "<C-d>", "<C-d>zz", opts)
map("n", "<C-u>", "<C-u>zz", opts)
map("n", "n", "nzzzv", opts)
map("n", "N", "Nzzzv", opts)
map("n", "<c-h>", ":TmuxNavigateLeft<cr>", opts)
map("n", "<c-l>", ":TmuxNavigateRight<cr>", opts)
map("n", "<c-j>", ":TmuxNavigateDown<cr>", opts)
map("n", "<c-k>", ":TmuxNavigateUp<cr>", opts)
map("n", "<Up>", ":resize -2<cr>", opts)
map("n", "<Down>", ":resize +2<cr>", opts)
map("n", "<Left>", ":vertical resize -2<cr>", opts)
map("n", "<Right>", ":vertical resize +2<cr>", opts)

map("n", "<leader>mz", "bb]s1z=", a("Fix spelling mistake"))
map("n", "<leader>ms", ":set spell!<cr>", a("Toggle spelling"))
-- map("n", "<leader>mc", ":mksession!<cr>", a("[C]reate Session"))

-- help

-- map({ "n", "v" }, "x", '"_x', opts)
-- map({ "n", "v" }, "X", '"_X', opts)
-- map({ "n", "v" }, "c", '"_c', opts)
-- map({ "n", "v" }, "C", '"_C', opts)

map("n", "q:", ":q<cr>", { desc = "misclick" })
map("n", "<leader>a", ":q<cr>", a("quit"))
map("n", "<leader>z", ":ZenMode<cr>", a("toggle zoom mode"))
map("n", "<leader>y", "ggyG", a("copy full file"))
map("n", "<leader>p", "<esc>ggVGp", a("change full file"))
map("n", "<c-s>", ":w<cr>", opts)
map("i", "<c-a>", "<Esc>mpggyG'p:delmarks p<cr>", opts)

map("t", "<Esc>", [[<C-\><C-n>]], { desc = "Exit Terminal Mode" })
map("t", "jk", "<C-\\><C-n>", opts)

map("n", "tw", ":Twilight<cr>", opts)
map("n", "Q", ":q<cr>", opts)
map("n", "WW", ":w<cr>", opts)
map("n", "WQ", ":wqa<cr>", opts)
map({ "n", "v" }, "E", "$", opts)
map({ "n", "v" }, "B", "^", opts)
map("n", "<Esc>", ":noh<cr>:NoiceDismiss<cr>", opts)
map("n", "ss", ":vsplit<cr>", opts)
map("n", "sv", ":split<cr>", opts)

map("n", "TT", ":TransparentToggle<cr>", a("Toggle transparetn mode"))
map("n", "<leader>df", ":DeleteFile", {})

-- notes
map("n", "<leader>nn", ":Dooing<cr>", a("Dooing open"))
map("n", "<leader>nt", ":DooingDue<cr>", a("Dooing today tasks"))
vim.keymap.del("n", "<leader>n") -- Unmaps '<leader>tn' in Normal mode

-- functions
vim.keymap.set("n", "<leader>mt", f.translation_scratchpad, { desc = "Open translation scratchpad" })
vim.keymap.set("n", "<leader>ma", f.flash_wrap_markdown_bold, a("Wrap text with '**' from cursor to Flash target"))
vim.keymap.set("n", "<leader>mc", f.generate_markdown_map, a("Generate .md map"))
map("n", "<leader>me", f.align_markdown_table_columns, { desc = "Align Markdown Table Columns" })
map("n", "<leader>fo", ":FzfBigOpen<cr>", a("Find Big File (Raw Mode)"))
map("n", "<leader>sh", ":PickFromZshHistory<cr>", a("Pick from Zsh history"))
map("n", "SS", f.toggle_split_orientation, { desc = "Toggle Split Orientation Layout" })
map("n", "<leader>oc", f.strip_buffer_comments, { desc = "Strip all comments from buffer" })
map("n", "<leader>cp", f.copy_clean_filepath, { desc = "Copy escaped forward-slash filepath" })
map("n", "<leader>Fa", f.toggle_codeium, { desc = "Toggle Codeium completion" })

map("n", "<F5>", require("dap").step_into)
map("n", "<leader>mp", ":MarkdownPreview<cr>", a("preview of .md"))

-- Create Neovim note
map("n", "<leader>on", f.create_obsidian_note, { desc = "Create and save Obsidian note" })

-- Make 'j' and 'k' move instantly on display lines without triggering timeouts
map({ "n", "v" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, noremap = true })
map({ "n", "v" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, noremap = true })
