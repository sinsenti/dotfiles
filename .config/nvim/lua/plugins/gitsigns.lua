return {
  {
      'tpope/vim-fugitive',
  },
  {
    'lewis6991/gitsigns.nvim',
    config=function ()
      require('gitsigns').setup {
        signs = {
          add = { text = '+' },
          change = { text = '~' },
          delete = { text = '_' },
          topdelete = { text = '‾' },
          changedelete = { text = '~' },
        },
        current_line_blame = false,
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns

          local function map(mode, l, r, opts)
            opts = opts or {}
            opts.buffer = bufnr
            vim.keymap.set(mode, l, r, opts)
          end

          -- Navigation
          map('n', ']c', function()
            if vim.wo.diff then return ']c' end
            vim.schedule(function() gs.next_hunk() end)
            return '<Ignore>'
          end, {expr=true})

          map('n', '[c', function()
            if vim.wo.diff then return '[c' end
            vim.schedule(function() gs.prev_hunk() end)
            return '<Ignore>'
          end, {expr=true})

          -- Actions
          map({'n', 'v'}, '<leader>hs', ':Gitsigns stage_hunk<CR>')
          map({'n', 'v'}, '<leader>hr', ':Gitsigns reset_hunk<CR>')
          map('n', '<leader>hS', gs.stage_buffer, {desc='stage_buffer'})
          map('n', '<leader>ha', gs.stage_hunk, {desc='stage_hunk'})
          map('n', '<leader>hu', gs.undo_stage_hunk, {desc='undo_stage_hunk'})
          map('n', '<leader>hR', gs.reset_buffer, {desc='reset_buffer'})
          map('n', '<leader>hp', gs.preview_hunk, {desc='preview_hunk'})
          map('n', '<leader>hb', function() gs.blame_line{full=true} end, {desc='Blame line'})
          map('n', '<leader>tB', gs.toggle_current_line_blame, {desc='Toggle current line blame '})
          map('n', '<leader>hd', gs.diffthis, {desc='Diff this'})
          map('n', '<leader>hD', function() gs.diffthis('~') end, {desc='diff thsi (~)'})

          -- Text object
          map({'o', 'x'}, 'ih', ':<C-U>Gitsigns select_hunk<CR>')
        end
      }
    end
  }
}
