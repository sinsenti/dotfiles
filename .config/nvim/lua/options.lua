vim.opt.showtabline = 0


vim.o.hlsearch=true
vim.o.updatetime=250
-- vim.cmd.colorscheme 'catppuccin'
vim.o.completeopt='menuone,noselect'

vim.opt.clipboard = 'unnamedplus'


-- vim.opt.clipboard = ""
-- vim.keymap.set({ "n", "x" }, "y", '"+y')
-- vim.keymap.set("n", "p", '""p')
-- vim.keymap.set('n', '<s-y>', '"+y$',{} )

vim.o.ignorecase = true
vim.o.smartcase = true

vim.opt.statusline = '%y'
vim.opt.fillchars:append { eob = ' ' }
vim.o.autoread = false

--line numbers
vim.wo.number = true
vim.o.relativenumber = true

--split
vim.o.splitbelow = true
vim.o.splitright = true

--wrap
vim.o.wrap = true
vim.o.linebreak = true

--idk why that need
vim.wo.signcolumn = 'yes'

vim.o.numberwidth = 2
vim.o.shiftwidth = 2
vim.o.tabstop = 2
vim.o.softtabstop = 2
vim.o.expandtab = true
vim.o.cursorline = true
vim.o.smartindent = true
vim.o.autoindent = true



vim.o.backup = false
vim.o.writebackup = true

--minimal number of screen lines to keep above and below the cursor
vim.o.scrolloff = 10;

vim.o.showmode = false

vim.o.conceallevel = 1
vim.o.cmdheight = 1
-- vim.cmd.colorscheme 'catppuccin'
