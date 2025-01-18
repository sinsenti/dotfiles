local opts = { noremap = true, silent = true }

local function a(desctiption)
  return vim.tbl_deep_extend('force', opts, { desc = desctiption })
end
vim.keymap.set('n', '<c-h>', ':TmuxNavigateLeft<CR>', opts)
vim.keymap.set('n', '<c-l>', ':TmuxNavigateRight<CR>', opts)
vim.keymap.set('n', '<c-j>', ':TmuxNavigateDown<CR>', opts)
vim.keymap.set('n', '<c-k>', ':TmuxNavigateUp<CR>', opts)

vim.keymap.set('n', '<leader>mr', 'zz', a('Place line in the centrer'))
vim.keymap.set('n', '<leader>-', ":Oil<CR>", opts)

vim.api.nvim_create_autocmd('TermOpen', { pattern = '*', command = 'startinsert', })
vim.keymap.set('n', '<leader>WT', ':lua _G.open_floating_terminal()<cr>', opts)
-- vim.keymap.set('n', '<leader>WT', ':lua _G.open_split_terminal()<cr>', opts) vim.keymap.set('t', '<Esc>', '<C-\\><C-n>', opts)
vim.keymap.set('t', 'jk', '<C-\\><C-n>', opts)
vim.keymap.set('n', '<leader>df', ':DeleteFile', {})
vim.keymap.set('n', 'td', ':lua save_and_delete_buffer()<cr>', opts)



vim.keymap.set('i', '<C-h>', '<C-w>', opts)
vim.keymap.set('i', '<c-a>', "<Esc>mpggyG'p:delmarks p<cr>", opts)
vim.keymap.set('n', '<leader>mz', 'bb]s1z=', a("Fix spelling mistake"))
vim.keymap.set('n', '<leader>ms', ':set spell!<cr>', a('Toggle spelling'))
vim.keymap.set('n', '<leader>mc', ':mksession!<cr>', a('[C]reate Session'))
vim.keymap.set('n', '<leader>mt', ':source Session.vim<cr>', a('Toggle Session'))


vim.keymap.set('n', '<leader>gS', ':Neogit<cr>', opts)

vim.keymap.set('n', '<leader>gs', ':Neogit cwd=%:p:h<cr>', opts)
vim.keymap.set('n', '<leader>gc', ':Neogit commit<cr>', opts)
vim.keymap.set('n', '<leader>gp', ':Neogit pull<cr>', opts)
vim.keymap.set('n', '<leader>gP', ':Neogit push<cr>', opts)
vim.keymap.set('n', '<leader>gb', ':Telescope git_branches<cr>', opts)
vim.keymap.set('n', '<leader>gB', ':G blame<cr>', opts)
vim.keymap.set('n', '<leader>gg', ':Git ', { desc = 'Git' })
vim.keymap.set('n', '<leader>ga', ':Git add .<cr>', opts)

vim.keymap.set('n', '<leader>e', ':GoIfErr<cr>', opts)


vim.api.nvim_set_keymap('n', 'tw', ':Twilight<cr>', opts)
vim.api.nvim_set_keymap('n', 'tj', ':bfirst<cr>', opts)
vim.api.nvim_set_keymap('n', 'th', ':bprev<cr>', opts)
vim.api.nvim_set_keymap('n', 'tl', ':bnext<cr>', opts)
vim.api.nvim_set_keymap('n', 'tk', ':blast<cr>', opts)
vim.api.nvim_set_keymap('n', 'QQ', ':q<cr>', opts)
vim.api.nvim_set_keymap('n', 'WW', ':w<cr>', opts)
vim.api.nvim_set_keymap('n', 'WQ', ':wqa<cr>', opts)
vim.api.nvim_set_keymap('n', '<c-s>', ':w<cr>', opts)
vim.api.nvim_set_keymap('n', 'TT', ':TransparentToggle<cr>', opts)
vim.api.nvim_set_keymap('n', 'E', '$', opts)
vim.api.nvim_set_keymap('n', 'B', '^', opts)
vim.keymap.set('n', '<Up>', ':resize -2<cr>', opts)
vim.keymap.set('n', '<Down>', ':resize +2<cr>', opts)
vim.keymap.set('n', '<Left>', ':vertical resize -2<cr>', opts)
vim.keymap.set('n', '<Right>', ':vertical resize +2<cr>', opts)
vim.keymap.set('n', '<Esc>', ':noh<cr>:NoiceDismiss<cr>', opts)
vim.keymap.set('i', 'jk', '<Esc>', opts)
vim.keymap.set('i', 'Jk', '<Esc>', opts)
vim.keymap.set('i', 'JK', '<Esc>', opts)
vim.keymap.set('n', 'ss', ':vsplit<Return>', opts)
vim.keymap.set('n', 'sv', ':split<Return>', opts)
vim.keymap.set('n', 'te', ':tabedit<cr>', opts)
vim.keymap.set('n', '<tab>', ':tabnext<Return>', opts)
vim.keymap.set('n', '<s-tab>', ':tabprev<Return>', opts)

-- vim.keymap.set('i', '<C-h>', 'jkdiwi', opts)
--'<leader>[' - find '('
--'<leader>dd' - terminal for c++
--'<leader>md' - mode for reading
