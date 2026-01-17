return {
  "stevearc/oil.nvim",
  event = "VeryLazy",
  config = function()
    local actions = require("oil.actions")

    require("oil").setup({
      skip_confirm_for_simple_edits = true,
      prompt_save_on_select_new_entry = false,
      view_options = {
        show_hidden = true,
        is_hidden_file = function(name, bufnr)
          local m = name:match("^%.")
          return m ~= nil
        end,
        is_always_hidden = function(name, bufnr)
          return false
        end,
      },
      float = {
        padding = 7,
      },
      preview = {
        always_show = true,
      },
      keymaps = {
        ["h"] = actions.parent,
        ["l"] = actions.select,
        ["-"] = false,
        ["gt"] = "actions.toggle_trash",
      },
      actions = {
        delete = { confirm = false },
        create = { confirm = false },
      },
    })

    vim.keymap.set("n", "-", require("oil").toggle_float, {})
  end,
}
