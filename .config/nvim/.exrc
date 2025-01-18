let s:cpo_save=&cpo
set cpo&vim
imap <M-Bslash> <Plug>(codeium-complete)
imap <M-[> <Plug>(codeium-previous)
imap <M-]> <Plug>(codeium-next-or-complete)
imap <Plug>(codeium-complete) <Cmd>call codeium#Complete()
imap <Plug>(codeium-previous) <Cmd>call codeium#CycleCompletions(-1)
imap <Plug>(codeium-next-or-complete) <Cmd>call codeium#CycleOrComplete()
imap <Plug>(codeium-next) <Cmd>call codeium#CycleCompletions(1)
imap <Plug>(codeium-dismiss) <Cmd>call codeium#Clear()
imap <C-G>S <Plug>ISurround
imap <C-G>s <Plug>Isurround
imap <C-S> <Plug>Isurround
cnoremap <silent> <Plug>(TelescopeFuzzyCommandSearch) e "lua require('telescope.builtin').command_history { default_text = [=[" . escape(getcmdline(), '"') . "]=] }"
inoremap <C-W> u
inoremap <C-U> u
nnoremap <silent>  :wincmd h
nnoremap <silent> 	 :tabnext
nnoremap <silent> <NL> :wincmd j
nnoremap <silent>  :wincmd k
nnoremap <silent>  :wincmd l
nmap  d
nnoremap <silent>  :noh
nnoremap <silent>  gB :G blame
nnoremap <silent>  gb :Telescope git_branches
nnoremap <silent>  gP :Neogit push
nnoremap <silent>  gp :Neogit pull
nnoremap <silent>  gc :Neogit commit
nnoremap <silent>  xq <Cmd>TroubleToggle quickfix
nnoremap <silent>  xl <Cmd>TroubleToggle loclist
nnoremap <silent>  xd <Cmd>TroubleToggle document_diagnostics
nnoremap <silent>  xw <Cmd>TroubleToggle workspace_diagnostics
nnoremap <silent>  xx <Cmd>TroubleToggle
nnoremap  dr :lua require('dapui').open({reset = true})
nnoremap  dc :DapContinue
nnoremap  db :DapToggleBreakpoint
nnoremap  dt :DapUiToggle
nmap  	 <Cmd>lua require('telescope.builtin').commands()
nnoremap  fn <Cmd>lua require('telescope').extensions.notify.notify()
nnoremap  fR <Cmd>lua require('telescope').extensions.git_worktree.create_git_worktree()
nnoremap  fr <Cmd>lua require('telescope').extensions.git_worktree.git_worktrees()
nnoremap <silent>  w :w
nnoremap <silent>  ee <Cmd>GoIfErr
omap <silent> % <Plug>(MatchitOperationForward)
xmap <silent> % <Plug>(MatchitVisualForward)
nmap <silent> % <Plug>(MatchitNormalForward)
nnoremap & :&&
xnoremap <silent> <expr> @ mode() ==# 'V' ? ':normal! @'.getcharstr().'' : '@'
nmap B ^
nmap E $
xnoremap <silent> <expr> Q mode() ==# 'V' ? ':normal! @=reg_recorded()' : 'Q'
xmap S <Plug>VSurround
nnoremap <silent> TT :TransparentToggle
nnoremap Y y$
omap <silent> [% <Plug>(MatchitOperationMultiBackward)
xmap <silent> [% <Plug>(MatchitVisualMultiBackward)
nmap <silent> [% <Plug>(MatchitNormalMultiBackward)
omap <silent> ]% <Plug>(MatchitOperationMultiForward)
xmap <silent> ]% <Plug>(MatchitVisualMultiForward)
nmap <silent> ]% <Plug>(MatchitNormalMultiForward)
xmap a% <Plug>(MatchitVisualTextObject)
nmap cS <Plug>CSurround
nmap cs <Plug>Csurround
nmap ds <Plug>Dsurround
nnoremap ft :TodoTelescope
xnoremap gb <Plug>(comment_toggle_blockwise_visual)
nnoremap gb <Plug>(comment_toggle_blockwise)
omap <silent> g% <Plug>(MatchitOperationBackward)
xmap <silent> g% <Plug>(MatchitVisualBackward)
nmap <silent> g% <Plug>(MatchitNormalBackward)
xmap gS <Plug>VgSurround
nnoremap <silent> gR <Cmd>TroubleToggle lsp_references
xnoremap gc <Plug>(comment_toggle_linewise_visual)
nnoremap gc <Plug>(comment_toggle_linewise)
nnoremap <silent> sv :split
nnoremap <silent> ss :vsplit
nnoremap <silent> te :tabedit
nmap td :bdelete
nmap tl :bnext
nmap th :bprev
nmap tj :bfirst
nmap tk :blast
nmap tw :Twilight
nnoremap <silent> wt :w:split:terminali
nmap ySS <Plug>YSsurround
nmap ySs <Plug>YSsurround
nmap yss <Plug>Yssurround
nmap yS <Plug>YSurround
nmap ys <Plug>Ysurround
xnoremap <Plug>(comment_toggle_blockwise_visual) <Cmd>lua require("Comment.api").locked("toggle.blockwise")(vim.fn.visualmode())
xnoremap <Plug>(comment_toggle_linewise_visual) <Cmd>lua require("Comment.api").locked("toggle.linewise")(vim.fn.visualmode())
xmap <silent> <Plug>(MatchitVisualTextObject) <Plug>(MatchitVisualMultiBackward)o<Plug>(MatchitVisualMultiForward)
onoremap <silent> <Plug>(MatchitOperationMultiForward) :call matchit#MultiMatch("W",  "o")
onoremap <silent> <Plug>(MatchitOperationMultiBackward) :call matchit#MultiMatch("bW", "o")
xnoremap <silent> <Plug>(MatchitVisualMultiForward) :call matchit#MultiMatch("W",  "n")m'gv``
xnoremap <silent> <Plug>(MatchitVisualMultiBackward) :call matchit#MultiMatch("bW", "n")m'gv``
nnoremap <silent> <Plug>(MatchitNormalMultiForward) :call matchit#MultiMatch("W",  "n")
nnoremap <silent> <Plug>(MatchitNormalMultiBackward) :call matchit#MultiMatch("bW", "n")
onoremap <silent> <Plug>(MatchitOperationBackward) :call matchit#Match_wrapper('',0,'o')
onoremap <silent> <Plug>(MatchitOperationForward) :call matchit#Match_wrapper('',1,'o')
xnoremap <silent> <Plug>(MatchitVisualBackward) :call matchit#Match_wrapper('',0,'v')m'gv``
xnoremap <silent> <Plug>(MatchitVisualForward) :call matchit#Match_wrapper('',1,'v'):if col("''") != col("$") | exe ":normal! m'" | endifgv``
nnoremap <silent> <Plug>(MatchitNormalBackward) :call matchit#Match_wrapper('',0,'n')
nnoremap <silent> <Plug>(MatchitNormalForward) :call matchit#Match_wrapper('',1,'n')
nnoremap <silent> <Plug>SurroundRepeat .
nnoremap <Plug>PlenaryTestFile :lua require('plenary.test_harness').test_file(vim.fn.expand("%:p"))
nnoremap <silent> <S-Tab> :tabprev
nnoremap <silent> <Right> :vertical resize +2
nnoremap <silent> <Left> :vertical resize -2
nnoremap <silent> <Down> :resize +2
nnoremap <silent> <Up> :resize -2
nnoremap <silent> <C-H> :wincmd h
nnoremap <silent> <C-J> :wincmd j
nnoremap <silent> <C-K> :wincmd k
nmap <C-W><C-D> d
nnoremap <silent> <C-L> :wincmd l
imap S <Plug>ISurround
imap s <Plug>Isurround
imap  <Plug>Isurround
inoremap  u
inoremap  u
inoremap <silent> jk 
let &cpo=s:cpo_save
unlet s:cpo_save
set noautoread
set clipboard=unnamedplus
set cmdheight=0
set completeopt=menuone,noselect
set expandtab
set fillchars=eob:\ 
set helplang=en
set ignorecase
set noloadplugins
set packpath=C:\\tools\\neovim\\nvim-win64\\share/nvim/runtime
set runtimepath=~\\AppData\\Local\\nvim,~\\AppData\\Local\\nvim-data\\lazy\\lazy.nvim,~/AppData/Local/nvim-data/lazy/Comment.nvim,~\\AppData\\Local\\nvim-data\\lazy\\codeium.vim,~\\AppData\\Local\\nvim-data\\lazy\\cmp_luasnip,~\\AppData\\Local\\nvim-data\\lazy\\LuaSnip,~\\AppData\\Local\\nvim-data\\lazy\\nvim-cmp,~\\AppData\\Local\\nvim-data\\lazy\\flash.nvim,~\\AppData\\Local\\nvim-data\\lazy\\which-key.nvim,~\\AppData\\Local\\nvim-data\\lazy\\vim-surround,~\\AppData\\Local\\nvim-data\\lazy\\zen-mode.nvim,~\\AppData\\Local\\nvim-data\\lazy\\harpoon,~\\AppData\\Local\\nvim-data\\lazy\\diffview.nvim,~\\AppData\\Local\\nvim-data\\lazy\\neogit,~\\AppData\\Local\\nvim-data\\lazy\\lualine.nvim,~\\AppData\\Local\\nvim-data\\lazy\\vim-sleuth,~\\AppData\\Local\\nvim-data\\lazy\\trouble.nvim,~\\AppData\\Local\\nvim-data\\lazy\\nvim-autopairs,~\\AppData\\Local\\nvim-data\\lazy\\gitsigns.nvim,~\\AppData\\Local\\nvim-data\\lazy\\go.nvim,~\\AppData\\Local\\nvim-data\\lazy\\transparent.nvim,~\\AppData\\Local\\nvim-data\\lazy\\noice.nvim,~\\AppData\\Local\\nvim-data\\lazy\\vim-fugitive,~\\AppData\\Local\\nvim-data\\lazy\\nvim,~\\AppData\\Local\\nvim-data\\lazy\\nui.nvim,~\\AppData\\Local\\nvim-data\\lazy\\neo-tree.nvim,~\\AppData\\Local\\nvim-data\\lazy\\indent-blankline.nvim,~\\AppData\\Local\\nvim-data\\lazy\\nvim-dap-virtual-text,~\\AppData\\Local\\nvim-data\\lazy\\nvim-dap-go,~\\AppData\\Local\\nvim-data\\lazy\\nvim-nio,~\\AppData\\Local\\nvim-data\\lazy\\nvim-dap,~\\AppData\\Local\\nvim-data\\lazy\\nvim-dap-ui,~\\AppData\\Local\\nvim-data\\lazy\\lspkind.nvim,~\\AppData\\Local\\nvim-data\\lazy\\todo-comments.nvim,~\\AppData\\Local\\nvim-data\\lazy\\vim-pencil,~\\AppData\\Local\\nvim-data\\lazy\\cmp-nvim-lsp,~\\AppData\\Local\\nvim-data\\lazy\\fidget.nvim,~\\AppData\\Local\\nvim-data\\lazy\\mason-lspconfig.nvim,~\\AppData\\Local\\nvim-data\\lazy\\mason.nvim,~\\AppData\\Local\\nvim-data\\lazy\\nvim-lspconfig,~\\AppData\\Local\\nvim-data\\lazy\\telescope-symbols.nvim,~\\AppData\\Local\\nvim-data\\lazy\\nvim-web-devicons,~\\AppData\\Local\\nvim-data\\lazy\\render-markdown,~\\AppData\\Local\\nvim-data\\lazy\\nvim-treesitter-textobjects,~\\AppData\\Local\\nvim-data\\lazy\\nvim-treesitter,~\\AppData\\Local\\nvim-data\\lazy\\goto-preview,~\\AppData\\Local\\nvim-data\\lazy\\guihua.lua,~\\AppData\\Local\\nvim-data\\lazy\\vim-obsession,~\\AppData\\Local\\nvim-data\\lazy\\git-worktree.nvim,~\\AppData\\Local\\nvim-data\\lazy\\oil.nvim,~\\AppData\\Local\\nvim-data\\lazy\\telescope-ui-select.nvim,~\\AppData\\Local\\nvim-data\\lazy\\telescope-fzf-native.nvim,~\\AppData\\Local\\nvim-data\\lazy\\plenary.nvim,~\\AppData\\Local\\nvim-data\\lazy\\telescope.nvim,~\\AppData\\Local\\nvim-data\\lazy\\nvim-notify,C:\\tools\\neovim\\nvim-win64\\share\\nvim\\runtime,C:\\tools\\neovim\\nvim-win64\\share\\nvim\\runtime\\pack\\dist\\opt\\matchit,C:\\tools\\neovim\\nvim-win64\\lib\\nvim,~\\AppData\\Local\\nvim-data\\lazy\\readme,~\\AppData\\Local\\nvim-data\\lazy\\cmp_luasnip\\after,~\\AppData\\Local\\nvim-data\\lazy\\go.nvim\\after,~\\AppData\\Local\\nvim-data\\lazy\\nvim\\after,~\\AppData\\Local\\nvim-data\\lazy\\indent-blankline.nvim\\after,~\\AppData\\Local\\nvim-data\\lazy\\cmp-nvim-lsp\\after
set scrolloff=10
set shiftwidth=2
set noshowmode
set smartcase
set smartindent
set softtabstop=2
set splitbelow
set splitright
set statusline=%y
set tabstop=2
set termguicolors
set updatetime=250
set window=55
" vim: set ft=vim :
