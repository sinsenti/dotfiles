local M = {}

function M.flash_wrap_markdown_bold()
  local start_win = vim.api.nvim_get_current_win()
  local start_buf = vim.api.nvim_get_current_buf()
  local start_row, start_col = unpack(vim.api.nvim_win_get_cursor(start_win))

  local current_line = vim.api.nvim_get_current_line()
  local word_start_col = start_col
  while word_start_col > 0 and current_line:sub(word_start_col, word_start_col):match("%w") do
    word_start_col = word_start_col - 1
  end
  if not current_line:sub(word_start_col + 1, word_start_col + 1):match("%w") then
    word_start_col = word_start_col + 1
  end

  require("flash").jump({
    continue = false,
    action = function(match)
      local end_row = match.pos[1]
      local end_col = match.pos[2] + 1

      local target_line = vim.api.nvim_buf_get_lines(start_buf, end_row - 1, end_row, false)[1]
      local word_end_col = end_col
      while word_end_col <= #target_line and target_line:sub(word_end_col, word_end_col):match("%w") do
        word_end_col = word_end_col + 1
      end

      vim.api.nvim_buf_set_text(start_buf, end_row - 1, word_end_col - 1, end_row - 1, word_end_col - 1, { "**" })
      vim.api.nvim_buf_set_text(start_buf, start_row - 1, word_start_col, start_row - 1, word_start_col, { "**" })

      local final_col = start_col
      if start_row == end_row and word_start_col <= start_col then
        final_col = start_col + 2
      end

      vim.api.nvim_win_set_cursor(start_win, { start_row, final_col })
    end,
  })
end

function M.align_markdown_table_columns()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1]

  local start_row = cursor_row
  while start_row > 1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, start_row - 2, start_row - 1, false)[1]
    if not line or not line:match("^%s*|") then
      break
    end
    start_row = start_row - 1
  end

  local end_row = cursor_row
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  while end_row <= total_lines do
    local line = vim.api.nvim_buf_get_lines(bufnr, end_row - 1, end_row, false)[1]
    if not line or not line:match("^%s*|") then
      break
    end
    end_row = end_row + 1
  end
  end_row = end_row - 1

  if start_row > end_row then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, end_row, false)
  local table_data = {}
  local col_widths = {}

  for _, line in ipairs(lines) do
    local row_cells = {}
    local clean_line = vim.trim(line):gsub("^|", ""):gsub("|$", "")
    clean_line = vim.trim(clean_line)

    for cell in (clean_line .. "|"):gmatch("(.-)|") do
      table.insert(row_cells, vim.trim(cell))
    end

    -- FIXED REDUNDANCY: Determine if separator row using a single clean regex look ahead
    local is_sep_row = line:match("^%s*|[%s%-%:]*|") ~= nil
    table.insert(table_data, { cells = row_cells, is_separator = is_sep_row })

    if not is_sep_row then
      for i, cell in ipairs(row_cells) do
        col_widths[i] = math.max(col_widths[i] or 0, vim.fn.strdisplaywidth(cell))
      end
    end
  end

  local formatted_lines = {}
  for _, row in ipairs(table_data) do
    local formatted_row = {}
    for i, cell in ipairs(row.cells) do
      local target_width = col_widths[i] or 0
      if row.is_separator then
        table.insert(formatted_row, string.rep("-", target_width + 2))
      else
        local padding = target_width - vim.fn.strdisplaywidth(cell)
        table.insert(formatted_row, " " .. cell .. string.rep(" ", padding) .. " ")
      end
    end
    table.insert(formatted_lines, "|" .. table.concat(formatted_row, "|") .. "|")
  end

  vim.api.nvim_buf_set_lines(bufnr, start_row - 1, end_row, false, formatted_lines)
end

-- =============================================================================
-- 2. TRANSLATOR SCRATCHPAD
-- =============================================================================

function M.renumber_markdown_list()
  local bufnr = 0
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1] -- 1-indexed row
  local total_lines = vim.api.nvim_buf_line_count(bufnr)

  -- Helper function to match 1-3 digit numbered list items
  -- Returns: indent, number, spacing after dot, rest of text
  local function parse_list_line(line)
    local indent, num, space, rest = line:match("^(%s*)(%d+)%.(%s+)(.*)$")
    if indent and num and #num <= 3 then
      return indent, num, space, rest
    end
    return nil
  end

  local current_line = vim.api.nvim_buf_get_lines(bufnr, cursor_row - 1, cursor_row, false)[1]

  -- Check if cursor is on a valid numbered list line
  if not current_line or not parse_list_line(current_line) then
    vim.notify("Cursor is not on a numbered list item!", vim.log.levels.WARN)
    return
  end

  -- 1. Scan upwards to find the start of the contiguous block
  local start_row = cursor_row
  while start_row > 1 do
    local prev_line = vim.api.nvim_buf_get_lines(bufnr, start_row - 2, start_row - 1, false)[1]
    if prev_line and parse_list_line(prev_line) then
      start_row = start_row - 1
    else
      break
    end
  end

  -- 2. Scan downwards to find the end of the contiguous block
  local end_row = cursor_row
  while end_row < total_lines do
    local next_line = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1]
    if next_line and parse_list_line(next_line) then
      end_row = end_row + 1
    else
      break
    end
  end

  -- 3. Fetch block lines and renumber hierarchically using an indentation stack
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, end_row, false)
  local new_lines = {}
  local stack = {} -- Tracks { indent_width = number, count = number } per level

  for _, line in ipairs(lines) do
    local indent, _, space, rest = parse_list_line(line)
    if indent then
      local indent_width = vim.fn.strdisplaywidth(indent)

      -- Pop levels deeper than the current item's indentation
      while #stack > 0 and stack[#stack].indent_width > indent_width do
        table.remove(stack)
      end

      -- Increment current level counter or initialize a new sublist level
      if #stack > 0 and stack[#stack].indent_width == indent_width then
        stack[#stack].count = stack[#stack].count + 1
      else
        table.insert(stack, { indent_width = indent_width, count = 1 })
      end

      local new_num = stack[#stack].count
      table.insert(new_lines, string.format("%s%d.%s%s", indent, new_num, space, rest))
    else
      table.insert(new_lines, line)
    end
  end

  -- 4. Write updated lines back to buffer
  vim.api.nvim_buf_set_lines(bufnr, start_row - 1, end_row, false, new_lines)
end


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

-- File System Clean targets

function M.insert_markdown_code_block()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local current_line = vim.api.nvim_get_current_line()
  local indent = current_line:match("^(%s*)") or ""

  if current_line:match("^%s*$") then
    vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, {
      indent .. "```",
      indent,
      indent .. "```",
    })
    vim.api.nvim_win_set_cursor(0, { row + 1, #indent })
  else
    vim.api.nvim_buf_set_lines(bufnr, row, row, false, {
      indent .. "```",
      indent,
      indent .. "```",
    })
    vim.api.nvim_win_set_cursor(0, { row + 2, #indent })
  end
end


function M.clean_chatgpt_markdown()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local stage1 = {}
  local in_code_block = false

  -- Pass 1: Clean non-breaking space artifacts, unescape symbols, strip header numbering, and normalize line starts
  for _, line in ipairs(lines) do
    -- Remove non-breaking spaces (U+00A0 / \194\160) and carriage returns
    line = line:gsub("\u{00a0}", " "):gsub("[\194\160]", " "):gsub("\r", "")

    -- Code block toggle
    if line:match("^%s*```") then
      in_code_block = not in_code_block
      line = line:gsub("^%s+```", "```")
      table.insert(stage1, line)
    elseif in_code_block then
      -- Leave exact code block interior lines intact
      table.insert(stage1, line)
    else
      -- Unescape backslashes before markdown characters (e.g. 14\. or \# or \**)
      line = line:gsub("(%d+)\\%s*%.", "%1.")
      line = line:gsub("\\([#%-%*%_%>%[%]%(%)])", "%1")

      -- Strip random leading spaces before headers, quotes, lists, dividers, and text
      line = line:gsub("^%s+(#+)", "%1")
      line = line:gsub("^%s+(>)", "%1")
      line = line:gsub("^%s+([%-%*%+])%s+", "%1 ")
      line = line:gsub("^%s+(%d+%.)%s+", "%1 ")
      line = line:gsub("^%s*(%-%-%-+)", "%1")
      line = line:gsub("^%s+([^%s])", "%1")

      -- Strip numerical prefixes from headers (e.g. '# 1. Title' or '## 2\. Section' -> '# Title')
      line = line:gsub("^(#+)%s*%d+%.%s*", "%1 ")

      -- Trim trailing whitespace
      line = line:gsub("%s+$", "")

      table.insert(stage1, line)
    end
  end

  -- Pass 2: Smart spacing, blank line collapsing, and loose-list tightening
  local stage2 = {}
  local in_code = false
  local i = 1

  while i <= #stage1 do
    local line = stage1[i]

    if line:match("^```") then
      in_code = not in_code
      table.insert(stage2, line)
      i = i + 1
    elseif in_code then
      -- Remove blank lines at opening or closing boundaries of code blocks
      local prev = stage2[#stage2]
      local next_line = stage1[i + 1]
      if line == "" and (prev:match("^```") or (next_line and next_line:match("^```"))) then
        -- Skip empty boundary line inside code block
      else
        table.insert(stage2, line)
      end
      i = i + 1
    else
      -- Tighten loose lists (remove empty lines between consecutive list bullets)
      local is_list_item = line:match("^%s*[%-%*%+]%s+") or line:match("^%s*%d+%.%s+")
      local next_1 = stage1[i + 1]
      local next_2 = stage1[i + 2]
      local is_next_list_item = next_2 and (next_2:match("^%s*[%-%*%+]%s+") or next_2:match("^%s*%d+%.%s+"))

      if is_list_item and next_1 == "" and is_next_list_item then
        table.insert(stage2, line)
        i = i + 2 -- Skip intermediate empty line between list items
      else
        -- Collapse multiple consecutive empty lines to maximum 1
        if line == "" and #stage2 > 0 and stage2[#stage2] == "" then
          -- Skip extra blank line
        else
          table.insert(stage2, line)
        end
        i = i + 1
      end
    end
  end

  -- Pass 3: Strip leading & trailing empty lines from the buffer
  while #stage2 > 0 and stage2[1] == "" do
    table.remove(stage2, 1)
  end
  while #stage2 > 0 and stage2[#stage2] == "" do
    table.remove(stage2, #stage2)
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, stage2)
  vim.notify("ChatGPT Markdown cleaned!", vim.log.levels.INFO)
end


return M
