return {
  {
    'ThePrimeagen/git-worktree.nvim',
  },
  -- {
  --   'ray-x/go.nvim',
  -- },
  {
    'ray-x/guihua.lua',
  },
  --   {
  --   'lukas-reineke/indent-blankline.nvim',
  --   main = 'ibl',
  --   opts = {},
  --   },
    {
    'folke/zen-mode.nvim',
    event='BufRead',
    config=function()
      require('zen-mode').setup({
    window = {
      backdrop = 1,
      -- width = 120, -- width of the Zen window
      -- height = 1, -- height of the Zen window
      options = {
        signcolumn = 'no', -- disable signcolumn
        number = false, -- disable number column
        relativenumber = false, -- disable relative numbers
        -- cursorline = false, -- disable cursorline
        -- cursorcolumn = false, -- disable cursor column
        -- foldcolumn = '0', -- disable fold column
        -- list = false, -- disable whitespace characters
      },
    },
    plugins = {
      -- disable some global vim options (vim.o...)
      options = {
        enabled = true,
        ruler = true, -- disables the ruler text in the cmd line area
        showcmd = false, -- disables the command in the last line of the screen
        -- you may turn on/off statusline in zen mode by setting 'laststatus'
        -- statusline will be shown only if 'laststatus' == 3
        laststatus = 0, -- turn off the statusline in zen mode
      },
      twilight = { enabled = true }, -- enable to start Twilight when zen mode opens
      gitsigns = { enabled = false }, -- disables git signs
    },
  })
    end,
    },




  {
    'rmagatti/goto-preview',
    event = 'BufRead',
    config = function()
      require('goto-preview').setup {
        width = 120, -- Width of the floating window
        height = 15, -- Height of the floating window
        border = { '↖', '─', '┐', '│', '┘', '─', '└', '│' }, -- Border characters of the floating window
        default_mappings = true,
        debug = false, -- Print debug information
        opacity = nil, -- 0-100 opacity level of the floating window where 100 is fully transparent.
        resizing_mappings = false, -- Binds arrow keys to resizing the floating window.
        post_open_hook = nil, -- A function taking two arguments, a buffer and a window to be ran as a hook.
        references = { -- Configure the telescope UI for slowing the references cycling window.
          telescope = require('telescope.themes').get_dropdown({ hide_preview = false })
        },
        -- These two configs can also be passed down to the goto-preview definition and implementation calls for one off 'peak' functionality.
        focus_on_open = true,                                        -- Focus the floating window when opening it.
        dismiss_on_move = false,                                     -- Dismiss the floating window when moving the cursor.
        force_close = true,                                          -- passed into vim.api.nvim_win_close's second argument. See :h nvim_win_close
        bufhidden = 'wipe',                                          -- the bufhidden option to set on the floating window. See :h bufhidden
        stack_floating_preview_windows = true,                       -- Whether to nest floating windows
        preview_window_title = { enable = true, position = 'left' }, -- Whether
      }
    end
  },
  {
    'ray-x/go.nvim'
  },
  {
    'ray-x/guihua.lua'
  },
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    build = function()
      pcall(require('nvim-treesitter.install').update { with_sync = true })
    end,
    dependencies = {
      'nvim-treesitter/nvim-treesitter-textobjects',
    }
  },
  -- {
  --   'theHamsta/nvim-dap-virtual-text',
  -- },
  -- {
  --   'leoluz/nvim-dap-go',
  -- },
  -- {
  --   'lukas-reineke/indent-blankline.nvim', main = 'ibl', opts = {}
  -- },
  {
    'tpope/vim-sleuth', -- Detect tabstop and shiftwidth automatically
  },
  -- {
  --   'rcarriga/nvim-dap-ui',
  --   dependencies = { 'mfussenegger/nvim-dap', 'nvim-neotest/nvim-nio' },
  --   config = function()
  --     local dap = require('dap')
  --     dap.adapters.python = {
  --       type = 'executable',
  --       command = 'python', -- Change to 'python3' if needed
  --       args = { '-m', 'debugpy.adapter' },
  --     }
  --     dap.configurations.python = {
  --       {
  --         type = 'python',
  --         request = 'launch',
  --         name = 'Launch file',
  --         program = '${file}', -- This will run the current file
  --         pythonPath = function()
  --           -- Use the configured Python path or virtual environment
  --           return '/usr/bin/python' -- Update to match your setup
  --         end,
  --       },
  --     }
  --     require('dapui').setup()
  --     require('dap-go').setup()
  --     require('nvim-dap-virtual-text').setup()
  --     vim.fn.sign_define('DapBreakpoint',
  --       { text = '🔴', texthl = 'DapBreakpoint', linehl = 'DapBreakpoint', numhl = 'DapBreakpoint' })
  --
  --     -- Debugger
  --     vim.api.nvim_set_keymap('n', '<leader>dt', ':DapUiToggle<CR>', { noremap = true })
  --     vim.api.nvim_set_keymap('n', '<leader>db', ':DapToggleBreakpoint<CR>', { noremap = true })
  --     vim.api.nvim_set_keymap('n', '<leader>dc', ':DapContinue<CR>', { noremap = true })
  --     vim.api.nvim_set_keymap('n', '<leader>dr', ':lua require('dapui').open({reset = true})<CR>', { noremap = true })
  --     vim.api.nvim_set_keymap('n', '<leader>ht', ':lua require('harpoon.ui').toggle_quick_menu()<CR>', { noremap = true })
  --   end
  -- },


  {
    'folke/twilight.nvim',
    -- ft = 'markdown',
    opts = {
    },
  },
  -- {
  --   'ThePrimeagen/harpoon',
  --   branch = 'harpoon2',
  --   dependencies = { 'nvim-lua/plenary.nvim' },
  --   config = function()
  --     local harpoon = require('harpoon')
  --
  --     harpoon:setup({})
  --
  --     vim.keymap.set('n', '<leader>p', function() harpoon:list():add() end, { desc = 'Add to harpoon' })
  --     vim.keymap.set('n', '<leader>ht', function() harpoon.ui:toggle_quick_menu(harpoon:list()) end)
  --
  --     -- basic telescope configuration
  --     local conf = require('telescope.config').values
  --     local function toggle_telescope(harpoon_files)
  --       local file_paths = {}
  --       for _, item in ipairs(harpoon_files.items) do
  --         table.insert(file_paths, item.value)
  --       end
  --
  --       require('telescope.pickers').new({}, {
  --         prompt_title = 'Harpoon',
  --         finder = require('telescope.finders').new_table({
  --           results = file_paths,
  --         }),
  --         previewer = conf.file_previewer({}),
  --         sorter = conf.generic_sorter({}),
  --       }):find()
  --     end
  --
  --     vim.keymap.set('n', '<leader>hh', function() toggle_telescope(harpoon:list()) end,
  --       { desc = 'Open harpoon window' })
  --   end
  --
  -- },
  --
  -- 'kevinhwang91/nvim-ufo',
  -- dependencies = 'kevinhwang91/promise-async',
  -- config = function()
  --   vim.o.foldcolumn = '1' -- '0' is not bad
  --   vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
  --   vim.o.foldlevelstart = 99
  --   -- vim.o.foldenable = true
  --
  --   vim.keymap.set('n', 'zR', require('ufo').openAllFolds, { desc = 'Open all folds' })
  --   vim.keymap.set('n', 'zM', require('ufo').closeAllFolds, { desc = 'Close all folds' })
  --   vim.keymap.set('n', 'zK', function()
  --     local winid = require('ufo').peekFoldedLinesUnderCursor()
  --     if not winid then
  --       vim.lsp.buf.hover()
  --     end
  --   end, { desc = 'Peek Fold' })
  --
  --   require('ufo').setup({
  --     provider_selector = function(bufnr, filetype, buftype)
  --       return { 'lsp', 'indent' }
  --     end,
  --   })
  -- end,
  --
  -- {
  --   'mistricky/codesnap.nvim',
  --   build = 'make',
  -- },
  -- {
  --   'yetone/avante.nvim',
  --   event = 'VeryLazy',
  --   lazy = false,
  --   version = false, -- set this if you want to always pull the latest change
  --   opts = {
  --     -- add any opts here
  --   },
  --   -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
  --   build = 'make',
  --   -- build = 'powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false' -- for windows
  --   dependencies = {
  --     'nvim-treesitter/nvim-treesitter',
  --     'stevearc/dressing.nvim',
  --     'nvim-lua/plenary.nvim',
  --     'MunifTanjim/nui.nvim',
  --     --- The below dependencies are optional,
  --     'nvim-tree/nvim-web-devicons', -- or echasnovski/mini.icons
  --     'zbirenbaum/copilot.lua',    -- for providers='copilot'
  --     {
  --       -- support for image pasting
  --       'HakonHarnes/img-clip.nvim',
  --       event = 'VeryLazy',
  --       opts = {
  --         -- recommended settings
  --         default = {
  --           embed_image_as_base64 = false,
  --           prompt_for_file_name = false,
  --           drag_and_drop = {
  --             insert_mode = true,
  --           },
  --           -- required for Windows users
  --           use_absolute_path = true,
  --         },
  --       },
  --     },
  --   },
  --   config = function()
  --     require('avante').setup({
  --       api_key = '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',                        -- Replace with your API key
  --       endpoint = 'https://api-inference.huggingface.co/models/llama-3.2', -- Replace with your model's endpoint
  --       max_tokens = 512,
  --       temperature = 0.7,
  --       top_p = 0.9,
  --       frequency_penalty = 0.0,
  --       presence_penalty = 0.0,
  --     })
  --   end,
  -- },
  -- {
  -- 'AckslD/nvim-neoclip.lua',
  --   event='BufRead',
  -- dependencies = {
  --   { 'nvim-telescope/telescope.nvim' },
  -- },
  -- config = function()
  --   require('neoclip').setup({
  --     history = 1000,
  --     enable_persistent_history = false,
  --     length_limit = 1048576,
  --     continuous_sync = false,
  --     db_path = vim.fn.stdpath('data') .. '/databases/neoclip.sqlite3',
  --     filter = nil,
  --     preview = true,
  --     prompt = nil,
  --     default_register = ''',
  --     default_register_macros = 'q',
  --     enable_macro_history = true,
  --     content_spec_column = false,
  --     disable_keycodes_parsing = false,
  --     on_select = {
  --       move_to_front = false,
  --       close_telescope = true,
  --     },
  --     on_paste = {
  --       set_reg = false,
  --       move_to_front = false,
  --       close_telescope = true,
  --     },
  --     on_replay = {
  --       set_reg = false,
  --       move_to_front = false,
  --       close_telescope = true,
  --     },
  --     on_custom_action = {
  --       close_telescope = true,
  --     },
  --     keys = {
  --       telescope = {
  --         i = {
  --           select = '<cr>',
  --           paste = '<c-j>',
  --           paste_behind = '<c-k>',
  --           replay = '<c-q>', -- replay a macro
  --           delete = '<c-d>', -- delete an entry
  --           edit = '<c-e>', -- edit an entry
  --           custom = {},
  --         },
  --         n = {
  --           select = '<cr>',
  --           paste = 'p',
  --           --- It is possible to map to more than one key.
  --           -- paste = { 'p', '<c-p>' },
  --           paste_behind = 'P',
  --           replay = 'q',
  --           delete = 'd',
  --           edit = 'e',
  --           custom = {},
  --         },
  --       },
  --     },
  --   })
  --
  --   vim.keymap.set('n', '<leader>o', '<cmd>Telescope neoclip<CR>', { desc = 'Telescope Neoclip' })
  -- end,
  --}
  --   -- {
  --     'ThePrimeagen/git-worktree.nvim',
  --   config=function()
  -- require('git-worktree').setup()
  --   end,
  --
  -- },
  -- {
  --   'nvim-neo-tree/neo-tree.nvim',
  --   branch = 'v3.x',
  --   -- event='BufRead',
  --   dependencies = {
  --     'nvim-lua/plenary.nvim',
  --     'nvim-tree/nvim-web-devicons',
  --     'MunifTanjim/nui.nvim',
  --   },
  --   config = function()
  --     require('neo-tree').setup({
  --       window = {
  --         mappings = {
  --           ['l'] = 'open',
  --           ['h'] = 'close_node',
  --         },
  --       },
  --     })
  --   end,
  --   vim.keymap.set('n', '<leader>-', ':Neotree toggle right<CR>', { noremap = true, silent = true })
  -- },


}
