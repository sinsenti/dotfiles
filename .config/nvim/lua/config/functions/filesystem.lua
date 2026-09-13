local M = {}

function M.close_tab_or_buffer()
  if #vim.api.nvim_list_tabpages() > 1 then
    vim.cmd("tabclose")
  else
    local has_snacks, snacks = pcall(require, "snacks")
    if has_snacks and snacks.bufdelete then
      snacks.bufdelete()
    else
      vim.cmd("bdelete")
    end
  end
end

function M.toggle_codeium()
  local has_codeium, codeium_config = pcall(require, "codeium.config")
  if not has_codeium then
    vim.notify("Codeium plugin not found", vim.log.levels.WARN, { title = "Plugins" })
    return
  end

  local vt = codeium_config.options.virtual_text
  vt.manual = not vt.manual
  if vt.manual then
    print("Codeium disabled")
  else
    print("Codeium enabled")
  end
end

function M.strip_buffer_comments()
  local ft = vim.bo.filetype
  if vim.tbl_contains({ "python", "yaml" }, ft) then
    vim.cmd([[g/^\s*#/d]])
    vim.cmd([[%s/#.*//]])
  elseif vim.tbl_contains({ "java", "c", "cpp", "cs", "javascript", "go", "sql" }, ft) then
    vim.cmd([[g@^\s*//@d]])
    vim.cmd([[%s@//.*@@e]])
  else
    vim.notify("Comment stripping not supported for filetype: " .. ft, vim.log.levels.WARN)
  end
end

function M.copy_clean_filepath()
  local filepath = vim.fn.expand("%:p"):gsub("\\", "/"):gsub(" ", "\\ ")
  vim.fn.setreg("+", filepath)
  print("Copied file path to clipboard: " .. filepath)
end

function M.create_obsidian_note()
  local filename = vim.fn.input("Enter note name: ")
  if filename == "" then
    return
  end
  vim.cmd("edit ~/git/obsidian/" .. filename .. ".md")
  vim.cmd("write")
end

function M.toggle_split_orientation()
  if #vim.api.nvim_tabpage_list_wins(0) ~= 2 then
    print("Toggle only works with exactly 2 windows")
    return
  end
  vim.cmd(vim.fn.winlayout()[1] == "row" and "wincmd K" or "wincmd H")
end

-- Table Map Generator Configuration
function M.generate_markdown_map()
  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  local old_toc_start, old_toc_end = nil, nil
  for i, line in ipairs(lines) do
    if line:match("^##%s+Table%s+of%s+Contents") then
      old_toc_start = (i > 1 and lines[i - 1] == "") and i - 1 or i
      for j = i + 1, #lines do
        if lines[j]:match("^%-%-%-$") then
          old_toc_end = (j < #lines and lines[j + 1] == "") and j + 1 or j
          break
        end
      end
      break
    end
  end

  if old_toc_start and old_toc_end then
    vim.api.nvim_buf_set_lines(buf, old_toc_start - 1, old_toc_end, false, {})
    lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end

  local map_lines = { "", "## Table of Contents", "" }
  for _, line in ipairs(lines) do
    local hashes, heading_text = line:match("^(#+)%s+(.+)$")
    if hashes and heading_text and #hashes >= 2 and heading_text ~= "Table of Contents" then
      local slug = heading_text:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
      table.insert(map_lines, string.format("[%s](#%s)", heading_text, slug))
    end
  end

  table.insert(map_lines, "")
  table.insert(map_lines, "---")
  table.insert(map_lines, "")

  local target_index = 0
  for i, line in ipairs(lines) do
    if line:match("^#%s+") then
      target_index = i
      break
    end
  end

  vim.api.nvim_buf_set_lines(buf, target_index, target_index, false, map_lines)
end


function M.open_help_splits()
  local left_file = vim.fn.expand("~/git/project/help.md")
  local right_file = vim.fn.expand("~/git/project/help1.md")

  -- Close all other splits in the current tab page
  vim.cmd("only")

  -- Open the left file in the main window
  vim.cmd("edit " .. vim.fn.fnameescape(left_file))
  local left_win = vim.api.nvim_get_current_win()

  -- Create a vertical split on the right for the second file
  vim.cmd("rightbelow vsplit " .. vim.fn.fnameescape(right_file))

  -- Return cursor focus to the left window
  vim.api.nvim_set_current_win(left_win)
end


return M
