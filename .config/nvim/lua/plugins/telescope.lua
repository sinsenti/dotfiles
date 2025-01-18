return {
  {
    'nvim-telescope/telescope.nvim',
    branch = '0.1.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope-fzf-native.nvim',
      'nvim-telescope/telescope-symbols.nvim',
      'nvim-telescope/telescope-ui-select.nvim',
    },
    config = function()
      local actions = require('telescope.actions')
      require('telescope').setup({
        defaults = {
          file_ignore_patterns = {
            '%.git',
            '%.mypy_cache',
            'venv',
            '%.visualprojects'
          },
          layout_config = {
            -- preview_width = 0.65,
            horizontal = {
              size = {
                width = '95%',
                height = '95%',
              },
            },
          },
          mappings = {
            i = {
              ['<C-j>'] = actions.move_selection_next,
              ['<C-k>'] = actions.move_selection_previous,
              ['<C-d>'] = actions.delete_buffer,
              ['<C-q>'] = actions.close,
            },
            n = {
              ['q'] = actions.close,
              ['d'] = actions.delete_buffer,
            },
          },
          pickers = {
            find_files = {
              hidden = true,
            },
            buffers = {
              initial_mode = 'normal',
              mappings = {
                n = {
                  ['d'] = actions.delete_buffer,
                },
              },
            },
          },
        },
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown({})
          },
        },
      })


      pcall(require('telescope').load_extension, 'fzf')
      local builtin = require('telescope.builtin')
      -- local keymap = vim.keymap.set

      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to telescope to change theme, layout, etc.
        require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          preview = true,
          layout_config = {
            width = 0.5,
            height = 0.5,
          }
        })
      end, { desc = '[/] Fuzzily search in current buffer]' })

      vim.keymap.set('n', '<leader>fF', builtin.find_files, { desc = 'Find files' })

      vim.keymap.set('n', '<leader>ff',
        ':lua require("telescope.builtin").find_files({ cwd = vim.fn.expand("%:p:h") })<CR>',
        { noremap = true, silent = true })
      vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Find Buffers' })

      vim.keymap.set('n', '<leader><leader>', builtin.oldfiles, { desc = 'Find Old files ' })

      vim.keymap.set('n', '<leader>fg',
        ':lua require("telescope.builtin").live_grep({ cwd = vim.fn.expand("%:p:h") })<CR>',
        { noremap = true, silent = true })
      vim.keymap.set('n', '<leader>fG', require('telescope.builtin').live_grep, { desc = '[S]earch by [G]rep' })

      vim.keymap.set('n', '<leader>fS', require('telescope.builtin').git_status, { desc = 'Git status' })

      vim.keymap.set("n", "<Leader>fr", "<CMD>lua require('telescope').extensions.git_worktree.git_worktrees()<CR>",
        { noremap = true })

      vim.keymap.set("n", "<Leader>fR", "<CMD>lua require('telescope').extensions.git_worktree.create_git_worktree()<CR>",
        { noremap = true })

      vim.keymap.set("n", "<Leader>fn", "<CMD>lua require('telescope').extensions.notify.notify()<CR>",
        { noremap = true })

      vim.api.nvim_set_keymap("n", "<leader>ft", ":TodoTelescope<CR>", { noremap = true, desc = 'Find TODO' })


      vim.api.nvim_set_keymap("n", "<Leader><tab>", "<Cmd>lua require('telescope.builtin').commands()<CR>",
        { noremap = false })

      require('telescope').load_extension('ui-select')
    end,
  },
}
