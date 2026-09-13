local M = {}
local H = require("config.functions.helpers")

vim.api.nvim_create_user_command("DeleteFile", function()
  vim.cmd("w")
  local file = vim.fn.expand("%:p")
  if vim.fn.filereadable(file) == 1 then
    vim.fn.delete(file)
  end
  vim.cmd("bdelete")
end, { desc = "Delete the current file and buffer" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "fugitive",
  callback = function()
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = true, silent = true })
  end,
})

-- Big File performance buffer picker
vim.api.nvim_create_user_command("FzfBigOpen", function()
  local fzf = require("fzf-lua")
  fzf.files({
    prompt = "⚡ BigOpen> ",
    actions = {
      ["default"] = function(selected, opts)
        local filepath = ""
        local query = opts.last_query or ""

        -- 1. Try matching path from query input (~/ or /)
        if query:match("^/") or query:match("^~") then
          local expanded = vim.fn.expand(query)
          if vim.fn.filereadable(expanded) == 1 then
            filepath = expanded
          end
        end

        -- 2. Try getting file from fzf selection
        if filepath == "" and selected and #selected > 0 then
          filepath = fzf.path.entry_to_file(selected[1]).path or selected[1]
        end

        -- 3. Fallback: If no file selected/typed, use the CURRENT buffer's file path
        if filepath == "" or not filepath then
          filepath = vim.api.nvim_buf_get_name(0)
        end

        -- If current buffer is unnamed / empty buffer, stop here
        if filepath == "" or not filepath then
          return
        end

        vim.g.neovim_loading_bigfile = true
        vim.opt.eventignore:append({ "BufReadPre", "BufReadPost", "FileType" })

        local success, err = pcall(function()
          vim.cmd("edit " .. vim.fn.fnameescape(filepath))
          local buf = vim.api.nvim_get_current_buf()

          vim.opt_local.swapfile = false
          vim.opt_local.undofile = false
          vim.opt_local.foldmethod = "manual"
          vim.opt_local.wrap = false
          vim.opt_local.statuscolumn = ""
          vim.opt_local.relativenumber = false
          vim.opt_local.syntax = "off"

          pcall(vim.treesitter.stop, buf)
          local clients = vim.lsp.get_clients({ bufnr = buf })
          for _, client in ipairs(clients) do
            vim.lsp.buf_detach_client(buf, client.id)
          end
        end)

        vim.opt.eventignore:remove({ "BufReadPre", "BufReadPost", "FileType" })
        vim.g.neovim_loading_bigfile = false

        vim.notify(
          success and "File parsed safely via Fast Raw Mode." or "BigOpen Picker error: " .. tostring(err),
          success and vim.log.levels.INFO or vim.log.levels.ERROR
        )
      end,
    },
  })
end, { desc = "Fuzzy search or open an absolute file path instantly" })

-- Pick command from Zsh History picker
vim.api.nvim_create_user_command("PickFromZshHistory", function()
  local zsh_history_path = vim.fn.expand("~/.zsh_history")
  if vim.fn.filereadable(zsh_history_path) == 0 then
    vim.notify("Could not read .zsh_history file", vim.log.levels.ERROR)
    return
  end

  local lines = vim.fn.readfile(zsh_history_path)
  local processed_commands = {}
  local seen = {}

  for i = #lines, 1, -1 do
    local cmd = lines[i]:gsub("^:%s*%d+:%d+;", ""):match("^%s*(.-)%s*$")
    if cmd and cmd ~= "" and not seen[cmd] then
      table.insert(processed_commands, cmd)
      seen[cmd] = true
    end
  end

  require("fzf-lua").fzf_exec(processed_commands, {
    prompt = "Zsh> ",
    fzf_opts = { ["--no-sort"] = "" },
    actions = {
      ["default"] = function(selected, opts)
        local fzf_lua = require("fzf-lua")
        local query = (opts and opts.last_query) or fzf_lua.get_last_query() or ""
        local cmd_to_run

        if query:sub(1, 1) == "!" then
          cmd_to_run = query:sub(2):match("^%s*(.-)%s*$")
        elseif selected and #selected > 0 then
          cmd_to_run = selected[1]
        end

        if not cmd_to_run or #cmd_to_run == 0 then
          return
        end

        vim.schedule(function()
          -- Calculate floating window dimensions (80% width, 60% height)
          local width = math.floor(vim.o.columns * 0.8)
          local height = math.floor(vim.o.lines * 0.6)
          local row = math.floor((vim.o.lines - height) / 2)
          local col = math.floor((vim.o.columns - width) / 2)

          -- Create scratch buffer and open float
          local buf = vim.api.nvim_create_buf(false, true)
          local win = H.open_float(buf, width, height, row, col)

          -- Open terminal in float and enter insert mode
          local term_cmd = string.format("zsh -i -c %s", vim.fn.shellescape(cmd_to_run))
          vim.fn.termopen(term_cmd)
          vim.cmd("startinsert")
        end)
      end,
    },
  })
end, { desc = "Zsh Command History" })

return M
