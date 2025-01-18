return {
  'nvim-lualine/lualine.nvim',
  config = function()
    require('lualine').setup({
      options = {
        icons_enabled = true,
        component_separators = '|',
        section_separators = '',
        always_divide_middle = false, -- When set to true, left sections i.e. 'a','b' and 'c'
        globalstatus = true,          -- enable global statusline (have a single statusline
      },


      -- with buffer in upper part
      sections = {

        lualine_a = { 'mode' },
        -- lualine_b = { 'filename', 'branch' },
        lualine_b = { 'filename', 'branch' },
        lualine_c = {
          -- 'diff',
          -- 'diagnostics',
          {
            'buffers',
          },
        },
        lualine_x = {
          {
            require('noice').api.statusline.mode.get,
            cond = require('noice').api.statusline.mode.has,
            -- color = { fg = '#ff9e64' },
          },
          {
            require('noice').api.status.command.get,
            cond = require('noice').api.status.command.has,
            -- color = { fg = '#ff9e64' },
          },
        },
        -- lualine_y = { 'progress' },
        -- lualine_z = { 'location' },
        -- lualine_x = { 'encoding', 'fileformat', 'filetype' },
        -- lualine_x = {},
        lualine_y = {},
        lualine_z = {},
      },
    })
  end
}
