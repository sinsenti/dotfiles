local map = vim.keymap.set
local opts = { noremap = true, silent = true }
local function a(desctiption)
  return vim.tbl_deep_extend("force", opts, { desc = desctiption })
end

local f = require("config.functions")

-- git
local modes = { "n", "i", "v", "t" }
for _, mode in ipairs(modes) do
  vim.keymap.set(mode, "<A-o>", "<Nop>", { noremap = true, silent = true })
end

map("n", "t", "<Nop>", { desc = "Disabled t" })
map("n", "tk", f.close_tab_or_buffer, { desc = "Close Tab or Buffer" })
map("n", "tt", f.open_neogit_in_current_dir, { desc = "Open neogit" })
map("n", "td", f.toggle_diffview, { desc = "Toggle Diffview" })
map("n", "ta", ":q<cr><cr>", a("quit"))
map("n", "tq", ":q<cr><cr>", a("quit"))
map("n", "tw", ":w<cr>", a("save file"))
map("n", "ts", f.google_search_scratchpad, { desc = "Default browser search" })
map("n", "tn", f.tmux_next_window, { desc = "Tmux next window" })
map("n", "TL", f.tmux_next_window, { desc = "Tmux next window" })
map("n", "TH", f.tmux_previous_window, { desc = "Tmux previous window" })
map("n", "t'", f.search_tmux_windows, { desc = "Search tmux windows" })
map("n", "tc", f.tmux_create_window, { desc = "Tmux create window" })

map("n", "t;", f.tmux_split_horizontal, { desc = "Tmux split horizontal" })
map("n", "t-", f.tmux_split_horizontal, { desc = "Tmux split horizontal" })
map("n", "t=", f.tmux_split_vertical, { desc = "Tmux split vertical" })

map("n", "<leader>0", f.open_help_splits, { desc = "Open Help Split View" })
map("n", "TK", f.tmux_kill_pane, { desc = "Tmux kill pane" })

-- map("n", "<leaderk", f.toggle_smart_terminal, a(""))
map("n", "T", f.open_neogit_in_current_dir, { desc = "Open neogit" })
map("n", "<leader>gr", ":Git reset --soft HEAD~1<cr>", a("Git reset --soft HEAD~1"))
map("n", "<leader>gg", f.open_neogit_in_current_dir, { desc = "Open neogit" })
map("n", "<leader>ga", f.show_git_status_noice, { desc = "Git Status Toast Notification" })
map("n", "<leader>gd", f.toggle_diffview, { desc = "Toggle Diffview" })
map("n", "<leader>gt", f.git_stash_with_prompt, { desc = "Git Stash All (Including Untracked)" })
map("n", "<leader>gs", f.toggle_diffview_branch, { desc = "Toggle Diffview against branch" })
map("n", "<leader>gS", f.toggle_diffview_commit, { desc = "Toggle Diffview against branch" })
map("n", "<leader>hg", "<cmd>Neogit<cr>", { desc = "Git Status" })

map("n", "<leader>gw", ":FzfLua git_branches<cr>", a("git checkout"))
map("n", "<leader>gf", ":Gdiffsplit<cr>", a("File diff"))

map("n", "<leader>GG", ":vert Git<cr>", a("Git | only"))
map("n", "<leader>GA", ":Git add .<cr>", a("Git add ."))
map("n", "<leader>GM", ":vert Git commit<cr>", a("Git commit vertical"))
map("n", "<leader>GS", ":Neogit stash<cr>", a("Neogit stash"))

-- tabs

map("n", "<leader>tk", f.close_tab_or_buffer, { desc = "Close Tab or Buffer" })
map("n", "<leader><tab><tab>", "<cmd>tabnext<cr>", { desc = "Next Tab" })
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
-- map("n", "<c-h>", ":NavigatorLeft<CR>", opts)
-- map("n", "<c-j>", ":NavigatorDown<CR>", opts)
-- map("n", "<c-k>", ":NavigatorUp<CR>", opts)
-- map("n", "<c-l>", ":NavigatorRight<CR>", opts)
map("n", "<c-h>", ":TmuxNavigateLeft<cr>", opts)
map("n", "<c-l>", ":TmuxNavigateRight<cr>", opts)
map("n", "<c-j>", ":TmuxNavigateDown<cr>", opts)
map("n", "<c-k>", ":TmuxNavigateUp<cr>", opts)
map("n", "<Up>", ":resize -2<cr>", opts)
map("n", "<Down>", ":resize +2<cr>", opts)
map("n", "<Left>", ":vertical resize -2<cr>", opts)
map("n", "<Right>", ":vertical resize +2<cr>", opts)

-- Make 'j' and 'k' move instantly on display lines without triggering timeouts
map({ "n", "v" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, noremap = true })
map({ "n", "v" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, noremap = true })

-- uncomment to disable clipboard for 'c' and 'x'
-- map({ "n", "v" }, "x", '"_x', opts)
-- map({ "n", "v" }, "X", '"_X', opts)
-- map({ "n", "v" }, "c", '"_c', opts)
-- map({ "n", "v" }, "C", '"_C', opts)

-- help

map("n", "q:", ":q<cr>", { desc = "misclick" })
map("n", ".", "/", { desc = "misclick" })
map("n", "<leader>l", ":q<cr><cr>", a("quit"))
map("n", "<leader>a", ":q<cr><cr>", a("quit"))
map("n", "<leader>z", ":ZenMode<cr>", a("toggle zoom mode"))
map("n", "<leader>y", "ggyG", a("copy full file"))
map("n", "<leader>p", "<esc>ggVGp", a("change full file"))
map("n", "<c-s>", ":w<cr>", opts)
map("i", "<c-a>", "<Esc>mpggyG'p:delmarks p<cr>", opts)

map("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "Exit Terminal Mode" })
-- map("t", "jk", "<C-\\><C-n>", opts)

map("n", "<leader>TW", ":Twilight<cr>", opts)
map("n", "Q", ":q<cr>", opts)
map("n", "WW", ":w<cr>", opts)
map("n", "WQ", ":wqa<cr>", opts)
map({ "n", "v" }, "E", "$", opts)
map({ "n", "v" }, "B", "^", opts)
map("n", "<Esc>", ":noh<cr>:NoiceDismiss<cr>", opts)
map("n", "ss", "<cmd>vsplit # | wincmd p<cr>", opts)
map("n", "sv", ":split<cr>", opts)

map("n", "<leader>T", ":TransparentToggle<cr>", a("Toggle transparetn mode"))
map("n", "<leader>df", ":DeleteFile", {})
map("n", "<leader>ra", ":CurlOpen global<CR>", a("curl commands"))

-- notes
map("n", "<leader>mg", f.clean_chatgpt_markdown, { desc = "Clean ChatGPT Markdown Artifacts" })
map("n", "<leader>mb", f.insert_markdown_code_block, { desc = "Insert Markdown Code Block" })
map("n", "<leader>ms", f.google_search_scratchpad, { desc = "Default browser search" })
map("n", "<leader>md", f.cambridge_dictionary_clean, { desc = "Search Dictionary" })
map("n", "<leader>Me", f.browser_search_scratchpad, { desc = "Browser search" })
map("n", "<leader>mz", "bb]s1z=", a("Fix spelling mistake"))
map("n", "<leader>mo", ":set spell!<cr>", a("Toggle spelling"))
map("n", "<leader>nn", ":Dooing<cr>", a("Dooing open"))
map("n", "<leader>mp", ":MarkdownPreview<cr>", a("preview of .md"))
map("n", "<leader>mr", ":RenderMarkdown buf_toggle<cr>", a("toggle rendering .md"))
map("n", "<leader>ma", f.flash_wrap_markdown_bold, a("Wrap text with '**' from cursor to Flash target"))
map("n", "<leader>mc", f.generate_markdown_map, a("Generate .md map"))
map("n", "<leader>me", f.align_markdown_table_columns, { desc = "Align Markdown Table Columns" })
map("n", "<leader>on", f.create_obsidian_note, { desc = "Create and save Obsidian note" })
vim.keymap.del("n", "<leader>n") -- Unmaps '<leader>tn' in Normal mode

-- functions

map("n", "<leader>mj", f.search_json_and_copy_value, { desc = "Json Search and copy value" })
map("n", "SS", f.toggle_split_orientation, { desc = "Toggle Split Orientation Layout" })
map("n", "<leader>mn", f.renumber_markdown_list, { desc = "Renumber list" })
map("v", "<leader>mt", f.translate_visual_selection, { desc = "Translate highlighted text block" })
map("n", "<leader>mt", f.translation_scratchpad, { desc = "Open translation scratchpad" })
map("v", "<leader>nt", f.translate_visual_selection, { desc = "Translate highlighted text block" })
map("n", "<leader>ье", f.translation_scratchpad, { desc = "Open translation scratchpad" })
map("n", "<leader>nt", f.translation_scratchpad, { desc = "Open translation scratchpad" })
map("n", "<leader>oc", f.strip_buffer_comments, { desc = "Strip all comments from buffer" })
map("n", "<leader>cp", f.copy_clean_filepath, { desc = "Copy escaped forward-slash filepath" })
map("n", "<leader>Fa", f.toggle_codeium, { desc = "Toggle Codeium completion" })
map("n", "<leader>fo", ":FzfBigOpen<cr>", a("Find Big File (Raw Mode)"))
map("n", "<leader>sh", ":PickFromZshHistory<cr>", a("Pick from Zsh history"))

map("n", "<F5>", require("dap").step_into)
