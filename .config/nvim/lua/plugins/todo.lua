return {
  {
    "phrmendes/todotxt.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    init = function()
      vim.filetype.add({
        filename = {
          ["todo.txt"] = "todotxt",
          ["done.txt"] = "todotxt",
        },
      })
    end,
    cmd = { "TodoTxt", "DoneTxt" },
    keys = {
      { "<leader>nl", "<cmd>TodoTxt<cr>", desc = "Toggle todo.txt Window" },
      { "<leader>na", "<cmd>TodoTxt new<cr>", desc = "New todo entry" },
      { "<leader>nd", "<cmd>DoneTxt<cr>", desc = "Toggle done.txt Window" },
      { "<leader>ng", "<cmd>TodoTxt ghost<cr>", desc = "Toggle ghost text" },

      -- Interaction mappings
      { "<cr>", "<Plug>(TodoTxtToggleState)", desc = "Toggle task state" },
      { "<leader>nc", "<Plug>(TodoTxtCyclePriority)", desc = "Cycle priority" },
      { "<leader>nm", "<Plug>(TodoTxtMoveDone)", desc = "Move done tasks" },

      -- Sorting arrays
      { "<leader>nss", "<Plug>(TodoTxtSortTasks)", desc = "Sort tasks (default)" },
      { "<leader>nsp", "<Plug>(TodoTxtSortByPriority)", desc = "Sort by priority" },
      { "<leader>nsc", "<Plug>(TodoTxtSortByContext)", desc = "Sort by context" },
      { "<leader>nsP", "<Plug>(TodoTxtSortByProject)", desc = "Sort by project" },
      { "<leader>nsd", "<Plug>(TodoTxtSortByDueDate)", desc = "Sort by due date" },
    },
    config = function()
      require("todotxt").setup({
        todotxt = vim.env.HOME .. "/Documents/todo.txt",
        donetxt = vim.env.HOME .. "/Documents/done.txt",
        max_priority = "C",
        metadata = {
          tag = { sort = "asc" },
          due = { sort = "asc" },
        },
        ghost_text = {
          enable = false,
          mappings = {
            ["(A)"] = "today",
            ["(B)"] = "tomorrow",
            ["(C)"] = "this week",
          },
        },
      })

      -- State tracker for the sub-note window context layer
      local active_note_win = nil

      -- Create a clear visual namespace for priority section headers
      local todo_decorations_ns = vim.api.nvim_create_namespace("todotxt_decorations")

      -- ─── PRIORITY SECTIONS VIRTUAL TEXT GENERATOR ───
      local function render_todo_decorations()
        local buf = vim.api.nvim_get_current_buf()
        if not vim.api.nvim_buf_is_valid(buf) then
          return
        end

        -- Clear old markers to prevent screen ghosting or duplicating
        vim.api.nvim_buf_clear_namespace(buf, todo_decorations_ns, 0, -1)

        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local seen_priorities = {}
        local last_priority = nil

        for i, line in ipairs(lines) do
          local current_priority = line:match("^%(([A-Z]%)%)") or "NONE"
          if current_priority ~= last_priority then
            if not seen_priorities[current_priority] then
              seen_priorities[current_priority] = true

              local virt_lines = {}
              -- Add an empty space row above sections (except for the very first line of the file)
              if i > 1 then
                table.insert(virt_lines, { { "", "" } })
              end

              -- Only render a title if it has an actual priority rating (A, B, or C)
              if current_priority ~= "NONE" then
                local header_text = "PRIORITY (" .. current_priority .. ")"
                table.insert(virt_lines, { { header_text, "DiagnosticOk" } })
                table.insert(virt_lines, { { "", "" } }) -- Small gap right below the title row
              end

              pcall(vim.api.nvim_buf_set_extmark, buf, todo_decorations_ns, i - 1, 0, {
                virt_lines = virt_lines,
                virt_lines_above = true,
              })
            end
          end
          last_priority = current_priority
        end
      end

      -- ─── ISOLATED TODO BUFFER MANAGEMENT ───
      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = { "term://*", "*.txt" },
        callback = function()
          local buf_name = vim.api.nvim_buf_get_name(0)

          if
            vim.bo.filetype == "todotxt"
            or string.match(buf_name, "todo%.txt")
            or string.match(buf_name, "done%.txt")
          then
            local current_todo_buf = vim.api.nvim_get_current_buf()

            -- Evaluate decoration layout right away
            vim.schedule(render_todo_decorations)

            -- Refresh priority headers automatically when changes occur
            vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "CursorMoved" }, {
              buffer = current_todo_buf,
              callback = function()
                vim.schedule(render_todo_decorations)
              end,
            })

            -- 1. AUTO-SAVE AND INSTANT CLOSURE ON 'q' FOR MASTER TODO LIST
            vim.keymap.set("n", "q", function()
              if vim.bo.modified then
                pcall(vim.cmd, "silent write")
              end

              -- If a sub-note pane was left open, clean it up first
              if active_note_win and vim.api.nvim_win_is_valid(active_note_win) then
                local note_buf = vim.api.nvim_win_get_buf(active_note_win)
                pcall(vim.api.nvim_buf_call, note_buf, function()
                  vim.cmd("silent write")
                end)
                pcall(vim.api.nvim_win_close, active_note_win, true)
                active_note_win = nil
              end

              vim.cmd("TodoTxt")

              vim.schedule(function()
                if vim.api.nvim_buf_is_valid(current_todo_buf) then
                  local chan_id = vim.b[current_todo_buf].terminal_job_id
                  if chan_id then
                    pcall(vim.fn.jobstop, chan_id)
                  end
                  pcall(vim.cmd, "bwipeout! " .. current_todo_buf)
                end
              end)
            end, { buffer = true, silent = true, nowait = true })

            -- 2. DYNAMIC TOGGLE SWITCH FOR SUB-NOTES (<leader>p)
            vim.keymap.set("n", "<leader>p", function()
              -- IF OPENED: Save changes and close it up immediately
              if active_note_win and vim.api.nvim_win_is_valid(active_note_win) then
                local note_buf = vim.api.nvim_win_get_buf(active_note_win)
                pcall(vim.api.nvim_buf_call, note_buf, function()
                  vim.cmd("silent write")
                end)
                vim.api.nvim_win_close(active_note_win, true)
                active_note_win = nil
                return
              end

              -- IF NOT OPENED: Initialize new note frame layer
              local line = vim.api.nvim_get_current_line()
              if line == "" then
                return
              end

              -- Generate sanitized name for markdown files
              local raw_task = line:gsub("^x%s+", ""):gsub("^%([A-Z]%)%s+", ""):gsub("^%d%d%d%d-%d%d-%d%d%s+", "")
              local task_slug =
                raw_task:gsub("[%s@+]", "_"):gsub("[^%w_]", ""):sub(1, 30):gsub("^_+", ""):gsub("_+$", "")
              if task_slug == "" then
                return
              end

              local notes_dir = vim.fn.expand("~/Documents/todo_details/")
              if vim.fn.isdirectory(notes_dir) == 0 then
                vim.fn.mkdir(notes_dir, "p")
              end
              local note_path = notes_dir .. task_slug .. ".md"

              -- ─── SAFE FILE BACKGROUND WRITER ───
              local note_tag = "note:" .. task_slug
              if not line:find(note_tag) then
                local todo_file_path = vim.env.HOME .. "/Documents/todo.txt"
                local f = io.open(todo_file_path, "r")
                if f then
                  local content = f:read("*all")
                  f:close()

                  -- Safely swap out the plain text block inside the raw file
                  local escaped_line = line:gsub("([^%w])", "%%%1")
                  local updated_content, count = content:gsub(escaped_line, line .. " " .. note_tag)

                  if count > 0 then
                    local wf = io.open(todo_file_path, "w")
                    if wf then
                      wf:write(updated_content)
                      wf:close()

                      -- Signal todotxt.nvim to cleanly re-read from disk state
                      local current_line_num = vim.fn.line(".")
                      vim.cmd("TodoTxt") -- Close
                      vim.cmd("TodoTxt") -- Re-open cleanly
                      pcall(vim.fn.cursor, current_line_num, 1)
                    end
                  end
                end
              end

              local note_buf = vim.api.nvim_create_buf(false, true)
              local width = math.floor(vim.o.columns * 0.6)
              local height = math.floor(vim.o.lines * 0.6)

              active_note_win = vim.api.nvim_open_win(note_buf, true, {
                relative = "editor",
                width = width,
                height = height,
                row = math.floor((vim.o.lines - height) / 2),
                col = math.floor((vim.o.columns - width) / 2),
                style = "minimal",
                border = "rounded",
                title = " Task Notes (Press q or <leader>p to Toggle Exit) ",
                title_pos = "center",
              })

              vim.cmd("edit " .. vim.fn.fnameescape(note_path))
              vim.bo.filetype = "markdown"

              vim.keymap.set("n", "q", function()
                vim.cmd("silent write")
                vim.cmd("bwipeout!")
                active_note_win = nil
              end, { buffer = true, silent = true })

              vim.keymap.set("n", "<leader>p", function()
                vim.cmd("silent write")
                vim.cmd("bwipeout!")
                active_note_win = nil
              end, { buffer = true, silent = true })
            end, { buffer = true, silent = true, desc = "TodoTxt: Toggle Task Note Details" })
          end
        end,
      })
    end,
  },
  {
    "atiladefreitas/dooing",
    event = "VeryLazy",
    config = function()
      require("dooing").setup({
        window = {
          width = 80, -- Width of the floating window
          height = 20, -- Height of the floating window
          border = "rounded", -- Border style: 'single', 'double', 'rounded', 'solid'
          zindex = 50, -- Base z-index for floating windows (uses zindex to zindex+5)
          position = "center", -- Window position: 'right', 'left', 'top', 'bottom', 'center',
        },

        -- Due date notifications
        due_notifications = {
          enabled = true, -- Enable due date notifications
          on_startup = false, -- Show notification on Neovim startup
          on_open = true, -- Show notification when opening todos
        },
        calendar = {
          start_day = "monday", -- or "monday"
        },
        eymaps = {
          toggle_window = "<leader>td", -- Toggle global todos
          open_project_todo = "<leader>tD", -- Toggle project-specific todos
          show_due_notification = "<leader>tN", -- Show due items window
          new_todo = "i",
          create_nested_task = "<leader>tn", -- Create nested subtask under current todo
          toggle_todo = "x",
          delete_todo = "d",
          delete_completed = "D",
          close_window = "q",
          undo_delete = "u",
          add_due_date = "H",
          remove_due_date = "r",
          toggle_help = "?",
          toggle_tags = "t",
          toggle_priority = "<Space>",
          clear_filter = "c",
          edit_todo = "e",
          edit_tag = "e",
          edit_priorities = "p",
          delete_tag = "d",
          search_todos = "/",
          add_time_estimation = "T",
          remove_time_estimation = "R",
          import_todos = "I",
          export_todos = "E",
          remove_duplicates = "<leader>D",
          open_todo_scratchpad = "<leader>p",
          refresh_todos = "f",
        },
      })
    end,
  },
}
