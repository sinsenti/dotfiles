local M = {}

-- =============================================================================
-- 1. MARKDOWN UTILITIES
-- =============================================================================

-- Wrap text with '**' from cursor to Flash target
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
function M.translate_visual_selection()
  -- 1. Exit Visual mode to save the CURRENT selection to '< and '> marks
  local mode = vim.api.nvim_get_mode().mode
  if mode:match("[vV\22]") then
    vim.cmd("noautocmd normal! \27")
  end

  -- 2. Extract selected text safely without register pollution
  local full_text
  if vim.fn.getregion then
    -- Modern Neovim 0.10+ native visual region extraction
    local lines = vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>"), { type = vim.fn.visualmode() })
    full_text = table.concat(lines, "\n")
  else
    -- Fallback for older Neovim versions using temporary register 'v'
    local old_v_reg = vim.fn.getreg("v")
    local old_v_type = vim.fn.getregtype("v")
    vim.cmd('noautocmd normal! gv"vy')
    full_text = vim.fn.getreg("v")
    vim.fn.setreg("v", old_v_reg, old_v_type)
  end

  -- Exit silently if text is empty or only whitespace
  if not full_text or full_text:match("^%s*$") then
    return
  end

  -- 3. Language detection: checks if selection contains any Cyrillic characters
  local is_russian = full_text:match("[а-яА-ЯёЁ]") ~= nil
  local target_lang = is_russian and "ru:en" or "en:ru"
  local direction_label = string.format("%s ➔ %s", is_russian and "RU" or "EN", is_russian and "EN" or "RU")

  -- 4. Asynchronous job call out to 'trans'
  vim.fn.jobstart({ "trans", "-brief", "-no-auto", target_lang, full_text }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data and #data > 0 then
        local result = table.concat(data, "\n"):gsub("^%s*(.-)%s*$", "%1")

        if #result > 0 then
          -- Copy translated text to system and unnamed registers
          vim.fn.setreg("+", result)
          vim.fn.setreg('"', result)

          -- Show notification popup
          vim.notify(result, vim.log.levels.INFO, {
            title = "Translation " .. direction_label .. " [Copied]",
            icon = "󰗊",
          })
        end
      end
    end,
    on_stderr = function(_, data)
      if data and data[1] ~= "" then
        local err_msg = table.concat(data, "\n"):gsub("\27%[[0-9;]*m", ""):gsub("^%s*(.-)%s*$", "%1")
        if #err_msg > 0 then
          vim.notify(err_msg, vim.log.levels.ERROR, { title = "Translation Error" })
        end
      end
    end,
  })
end

function M.translation_scratchpad()
  local buf = vim.api.nvim_create_buf(false, true)

  -- FIXED: Modernized deprecated vim.api.nvim_buf_set_option calls to vim.bo

  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
  vim.api.nvim_buf_set_option(buf, "wrap", true)

  local width = math.min(80, math.floor(vim.o.columns * 0.6))
  local height = math.min(10, math.floor(vim.o.lines * 0.3))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Type Text to Translate (Empty uses Clipboard) ",
    title_pos = "center",
  })

  vim.cmd("startinsert")

  local function process_and_translate()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local full_text = table.concat(lines, " "):gsub("^%s*(.-)%s*$", "%1")

    if full_text == "" then
      full_text = vim.fn.getreg("+"):gsub("^%s*(.-)%s*$", "%1")
    end

    -- If clipboard is also entirely empty, exit silently
    if full_text == "" then
      return
    end

    local clean_text = full_text:gsub('[%*%_#%-%[%]%(%)%`%"]', " ")
    local first_word = clean_text:match("(%a+)") or clean_text:match("([а-яА-ЯёЁ]+)") or ""

    local is_russian = first_word:match("[а-яА-ЯёЁ]")
    local target_lang = is_russian and "ru:en" or "en:ru"
    local direction_label = string.format("%s ➔ %s", is_russian and "RU" or "EN", is_russian and "EN" or "RU")

    vim.fn.jobstart({ "trans", "-brief", "-no-auto", target_lang, full_text }, {
      stdout_buffered = true,
      on_stdout = function(_, data)
        if data and #data > 0 and data[1] ~= "" then
          local result = table.concat(data, "\n"):gsub("^%s*(.-)%s*$", "%1")
          vim.fn.setreg("+", result)
          vim.fn.setreg('"', result)

          vim.notify(result, vim.log.levels.INFO, {
            title = "Translation " .. direction_label .. " [Copied]",
            icon = "󰗊",
          })
        end
      end,
      on_stderr = function(_, data)
        if data and data[1] ~= "" then
          local err_msg = table.concat(data, "\n"):gsub("\27%[[0-9;]*m", ""):gsub("^%s*(.-)%s*$", "%1")
          if #err_msg > 0 then
            vim.notify(err_msg, vim.log.levels.ERROR, { title = "Translation Error" })
          end
        end
      end,
    })
  end

  local triggered = false
  local function safe_trigger_and_close()
    if not triggered then
      triggered = true
      process_and_translate()
    end
    vim.cmd("stopinsert")
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      if not triggered then
        triggered = true
        process_and_translate()
      end
    end,
  })

  vim.keymap.set({ "n" }, "<Esc>", safe_trigger_and_close, { buffer = buf, silent = true })
  vim.keymap.set({ "n" }, "<CR>", safe_trigger_and_close, { buffer = buf, silent = true })
  vim.keymap.set("n", "q", safe_trigger_and_close, { buffer = buf, silent = true })
end

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

  -- 1. Scan upwards to find the start of the block
  local start_row = cursor_row
  while start_row > 1 do
    local prev_line = vim.api.nvim_buf_get_lines(bufnr, start_row - 2, start_row - 1, false)[1]
    if prev_line and parse_list_line(prev_line) then
      start_row = start_row - 1
    else
      break
    end
  end

  -- 2. Scan downwards to find the end of the block
  local end_row = cursor_row
  while end_row < total_lines do
    local next_line = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1]
    if next_line and parse_list_line(next_line) then
      end_row = end_row + 1
    else
      break
    end
  end

  -- 3. Fetch block lines and renumber sequentially
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, end_row, false)
  local new_lines = {}

  for i, line in ipairs(lines) do
    local indent, _, space, rest = parse_list_line(line)
    if indent then
      table.insert(new_lines, string.format("%s%d.%s%s", indent, i, space, rest))
    else
      table.insert(new_lines, line)
    end
  end

  -- 4. Write updated lines back to buffer
  vim.api.nvim_buf_set_lines(bufnr, start_row - 1, end_row, false, new_lines)
end

function M.google_search_scratchpad()
  -- Detect if invoked from Visual mode vs Normal mode
  local mode = vim.api.nvim_get_mode().mode
  local initial_text = ""

  if mode:match("[vV\22]") then
    -- Yank selected text into temporary 'v' register without touching system clipboard
    vim.cmd('noautocmd normal! "vy')
    initial_text = vim.fn.getreg("v")
  else
    -- Fallback to system clipboard in Normal mode
    initial_text = vim.fn.getreg("+") or ""
  end

  -- Create floating buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"

  -- Format initial text lines
  local lines_to_set = {}
  for line in initial_text:gmatch("[^\r\n]+") do
    table.insert(lines_to_set, line)
  end
  if #lines_to_set == 0 then
    lines_to_set = { "" }
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines_to_set)

  -- Window dimensions (70% width, 25% height)
  local width = math.floor(vim.o.columns * 0.70)
  local height = math.floor(vim.o.lines * 0.25)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Google Search (<CR> to Open Browser) ",
    title_pos = "center",
  })

  vim.wo[win].wrap = true

  -- NOTE: startinsert is intentionally omitted so window opens in Normal mode

  -- Search execution function
  local function perform_search()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local query = table.concat(lines, " "):gsub("^%s*(.-)%s*$", "%1")

    if query ~= "" then
      local url = "https://www.google.com/search?q=" .. vim.uri_encode(query)
      vim.ui.open(url) -- Opens query in system default web browser
    end

    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function close_window()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  -- Keymaps for the scratchpad
  vim.keymap.set("n", "<CR>", perform_search, { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", close_window, { buffer = buf, silent = true })
  vim.keymap.set("n", "q", close_window, { buffer = buf, silent = true })
end

function M.cambridge_dictionary_clean()
  local buf = vim.api.nvim_create_buf(false, true)

  -- Floating window dimensions (85% width, 80% height)
  local width = math.floor(vim.o.columns * 0.85)
  local height = math.floor(vim.o.lines * 0.80)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Cambridge Dictionary ",
    title_pos = "center",
  })

  -- Set buffer options
  vim.wo[win].wrap = true
  vim.bo[buf].bufhidden = "wipe"

  vim.cmd("startinsert")

  -- Clean and parse dictionary text into structured state
  local function clean_cambridge_text(raw_text, target_word)
    local lines = {}
    local last_line = ""
    local seen_first_sense = false
    local skipping_section = false

    local awaiting_definition = false
    local awaiting_examples = false
    local in_examples = false

    local uk_ipa = ""
    local us_ipa = ""
    local current_region = nil

    for line in raw_text:gmatch("[^\r\n]+") do
      local trimmed = line:gsub("^%s*(.-)%s*$", "%1")

      -- 1. Strip mustache templates and SVG placeholders
      if trimmed:find("{{") or trimmed:find("}}") or trimmed:find("%[svg%]") then
        goto continue
      end

      -- 2. Filter out noisy UI elements
      if
        trimmed:find("Add to word list")
        or trimmed:find("More examples")
        or trimmed:find("Fewer examples")
        or trimmed:find("Your browser doesn't support")
        or trimmed:find("Meaning of .* in English")
        or trimmed:find("See more results")
        or trimmed:find("© Cambridge")
      then
        goto continue
      end

      -- 3. Filter out unwanted section blocks (SMART Vocabulary, Thesaurus, etc.)
      if trimmed:find("SMART Vocabulary") or trimmed:find("Thesaurus:") then
        skipping_section = true
        goto continue
      end

      -- 4. Phonetics Extractor (UK / US)
      if trimmed:lower() == "uk" then
        current_region = "UK"
        goto continue
      elseif trimmed:lower() == "us" then
        current_region = "US"
        goto continue
      end

      local has_ipa = false
      for ipa in trimmed:gmatch("(/[^/]+/)") do
        has_ipa = true
        if current_region == "UK" and uk_ipa == "" then
          uk_ipa = ipa
        elseif current_region == "US" and us_ipa == "" then
          us_ipa = ipa
        elseif uk_ipa == "" then
          uk_ipa = ipa
        elseif us_ipa == "" then
          us_ipa = ipa
        end
      end
      if has_ipa then
        current_region = nil
        goto continue
      end

      -- 5. Sense Header & Level Detectors
      local is_sense_header = trimmed:lower():find("^" .. target_word:lower())
        and (
          trimmed:find("%(")
          or trimmed:find("adjective")
          or trimmed:find("verb")
          or trimmed:find("noun")
          or trimmed:find("adverb")
          or trimmed:find("preposition")
        )

      local cefr_level = trimmed:match("^([A-C][1-2])$") or trimmed:match("^([A-C][1-2])%s*%[")

      -- Resume processing if a new section header or level appears
      if skipping_section then
        if is_sense_header or cefr_level then
          skipping_section = false
        else
          goto continue
        end
      end

      -- Skip redundant raw lines prior to the first sense header
      if not seen_first_sense then
        if is_sense_header then
          seen_first_sense = true
        else
          goto continue
        end
      end

      -- 6. End Gate: Stop at footer links
      if trimmed:find("^Translations of ") or trimmed:find("^Browse") or trimmed:find("^About this") then
        if #lines > 3 then
          break
        end
      end

      -- 7. State Machine Formatter

      -- Sense Header
      if is_sense_header then
        table.insert(lines, "")
        table.insert(lines, "## " .. trimmed)
        awaiting_definition = true
        awaiting_examples = false
        in_examples = false
        goto continue
      end

      -- CEFR Level Tag (e.g. ### A1)
      if cefr_level then
        table.insert(lines, "")
        table.insert(lines, "### " .. cefr_level)
        awaiting_definition = true
        awaiting_examples = false
        in_examples = false
        goto continue
      end

      -- Definition Block
      if awaiting_definition then
        table.insert(lines, "")
        table.insert(lines, "**Definition:**")
        table.insert(lines, trimmed)
        awaiting_definition = false
        awaiting_examples = true
        in_examples = false
        goto continue
      end

      -- Examples Block Start (FIXED: No blank line between **Examples**: and actual examples)
      if awaiting_examples then
        table.insert(lines, "")
        table.insert(lines, "**Examples**:")
        if trimmed:sub(1, 2) == "• " then
          trimmed = trimmed:sub(3)
        end
        table.insert(lines, trimmed)
        awaiting_examples = false
        in_examples = true
        goto continue
      end

      -- Subsequent Examples / Lines
      if in_examples then
        if trimmed:sub(1, 2) == "• " then
          trimmed = trimmed:sub(3)
        end
        if trimmed ~= last_line then
          table.insert(lines, trimmed)
          last_line = trimmed
        end
      end

      ::continue::
    end

    -- Construct Header with UK/US Pronunciations on separate lines
    local header = { "# " .. target_word:lower(), "" }
    if uk_ipa ~= "" then
      table.insert(header, "UK:")
      table.insert(header, "`" .. uk_ipa .. "`")
    end
    if us_ipa ~= "" then
      table.insert(header, "US:")
      table.insert(header, "`" .. us_ipa .. "`")
    end

    -- Prepend header to output
    for i = #header, 1, -1 do
      table.insert(lines, 1, header[i])
    end

    if #lines == 0 then
      return { "# No entry found for '" .. target_word .. "'" }
    end

    return lines
  end

  local function process_and_search()
    local input_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local input_text = table.concat(input_lines, " "):gsub("^%s*(.-)%s*$", "%1")

    -- 1. Extract first word typed
    local word = input_text:match("(%S+)")

    -- 2. Fallback to word under cursor
    if not word or word == "" then
      word = vim.fn.expand("<cword>"):gsub("^%s*(.-)%s*$", "%1")
    end

    -- 3. Fallback to clipboard
    if not word or word == "" then
      local clip = vim.fn.getreg("+")
      word = clip and clip:match("(%S+)") or ""
    end

    if not word or word == "" then
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      return
    end

    word = word:lower()
    local url = "https://dictionary.cambridge.org/dictionary/english/" .. vim.uri_encode(word)

    vim.api.nvim_win_set_config(win, {
      title = " Cambridge: " .. word .. " ",
      title_pos = "center",
    })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Loading definition for '" .. word .. "'..." })

    local stdout_data = {}
    vim.fn.jobstart({ "w3m", "-dump", url }, {
      stdout_buffered = true,
      on_stdout = function(_, data)
        if data then
          for _, line in ipairs(data) do
            table.insert(stdout_data, line)
          end
        end
      end,
      on_exit = function()
        -- FIX: Use vim.schedule and check buffer/window validity to prevent Treesitter / mdmath.nvim invalid handle errors
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then
            return
          end

          local raw_output = table.concat(stdout_data, "\n")
          local cleaned_lines = clean_cambridge_text(raw_output, word)

          vim.api.nvim_buf_set_lines(buf, 0, -1, false, cleaned_lines)
          vim.bo[buf].filetype = "markdown"
          vim.cmd("stopinsert")

          -- Close shortcuts
          vim.keymap.set("n", "q", function()
            if vim.api.nvim_win_is_valid(win) then
              vim.api.nvim_win_close(win, true)
            end
          end, { buffer = buf, silent = true })

          vim.keymap.set("n", "<Esc>", function()
            if vim.api.nvim_win_is_valid(win) then
              vim.api.nvim_win_close(win, true)
            end
          end, { buffer = buf, silent = true })
        end)
      end,
    })
  end

  local triggered = false
  local function safe_trigger()
    if not triggered then
      triggered = true
      vim.cmd("stopinsert")
      process_and_search()
    end
  end

  local function cancel_and_close()
    triggered = true
    vim.cmd("stopinsert")
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  -- Scratchpad keymaps
  vim.keymap.set("n", "<CR>", safe_trigger, { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", cancel_and_close, { buffer = buf, silent = true })
  vim.keymap.set("n", "q", cancel_and_close, { buffer = buf, silent = true })
end

function M.browser_search_scratchpad()
  local buf = vim.api.nvim_create_buf(false, true)

  -- Buffer-local options (vim.bo)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"

  -- Larger floating window dimensions (85% width, 80% height)
  local width = math.floor(vim.o.columns * 0.85)
  local height = math.floor(vim.o.lines * 0.80)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Type Query to Search DuckDuckGo (Empty uses Clipboard) ",
    title_pos = "center",
  })

  -- Window-local options (vim.wo) - MUST be set AFTER window creation
  vim.wo[win].wrap = true

  vim.cmd("startinsert")

  local function process_and_search()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local full_text = table.concat(lines, " "):gsub("^%s*(.-)%s*$", "%1")

    -- Fallback to clipboard if scratchpad is empty
    if full_text == "" then
      full_text = vim.fn.getreg("+"):gsub("^%s*(.-)%s*$", "%1")
    end

    -- If clipboard is also empty, close window and exit
    if full_text == "" then
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      return
    end

    local url = "https://html.duckduckgo.com/html/?q=" .. vim.uri_encode(full_text)

    -- Transition the floating window buffer directly into w3m terminal mode
    if vim.api.nvim_win_is_valid(win) then
      local term_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(win, term_buf)
      vim.api.nvim_win_set_config(win, {
        title = " DuckDuckGo: " .. full_text .. " ",
        title_pos = "center",
      })

      vim.api.nvim_buf_call(term_buf, function()
        vim.fn.termopen("w3m " .. vim.fn.shellescape(url))
      end)
      vim.cmd("startinsert")
    end
  end

  local triggered = false
  local function safe_trigger()
    if not triggered then
      triggered = true
      vim.cmd("stopinsert")
      process_and_search()
    end
  end

  local function cancel_and_close()
    triggered = true
    vim.cmd("stopinsert")
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  -- Keymaps for scratchpad interaction
  vim.keymap.set("n", "<CR>", safe_trigger, { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", cancel_and_close, { buffer = buf, silent = true })
  vim.keymap.set("n", "q", cancel_and_close, { buffer = buf, silent = true })
end

-- =============================================================================
-- 4. GIT UTILITIES
-- =============================================================================

function M.open_neogit_in_current_dir()
  require("neogit").open({
    cwd = vim.fn.expand("%:p:h"),
    kind = "replace",
  })
end

local function run_git(dir, args)
  local cmd = string.format("git -C %s %s", vim.fn.shellescape(dir), args)
  return vim.fn.system(cmd)
end

function M.show_git_status_noice()
  local current_file_dir = vim.fn.expand("%:p:h")
  if current_file_dir == "" then
    current_file_dir = vim.fn.getcwd()
  end

  local branch = run_git(current_file_dir, "branch --show-current"):gsub("%s+", "")
  if branch == "" or vim.v.shell_error ~= 0 then
    vim.notify("Current file is not inside a git repository", vim.log.levels.WARN, { title = "Git Status" })
    return
  end

  local status_output = run_git(current_file_dir, "status --porcelain=v1")
  if status_output == "" then
    vim.notify(
      "Working directory completely clean\nRepository: " .. branch,
      vim.log.levels.INFO,
      { title = "Git Status" }
    )
    return
  end

  local lines = vim.split(status_output, "\n")
  local staged, unstaged, untracked = {}, {}, {}
  local total_count = 0

  for _, line in ipairs(lines) do
    if line ~= "" then
      total_count = total_count + 1
      local stage_char = line:sub(1, 1)
      local work_char = line:sub(2, 2)
      local file_path = line:sub(4):gsub("^%.%.%/+", "")
      local clean_line = string.format("%s%s %s", stage_char, work_char, file_path)

      if stage_char == "?" and work_char == "?" then
        table.insert(untracked, clean_line)
      elseif stage_char ~= " " and stage_char ~= "?" then
        table.insert(staged, clean_line)
      else
        table.insert(unstaged, clean_line)
      end
    end
  end

  local msg_sections = { string.format(" Branch: %s\nTotal Changes: %d", branch, total_count) }
  if #staged > 0 then
    table.insert(msg_sections, "● Staged Changes:\n" .. table.concat(staged, "\n"))
  end
  if #unstaged > 0 then
    table.insert(msg_sections, "○ Unstaged Changes:\n" .. table.concat(unstaged, "\n"))
  end
  if #untracked > 0 then
    table.insert(msg_sections, "  Untracked Files:\n" .. table.concat(untracked, "\n"))
  end

  vim.notify(table.concat(msg_sections, "\n\n"), vim.log.levels.INFO, { title = "Git Status", timeout = 4000 })
end

function M.git_stash_with_prompt()
  if vim.fn.system("git status --porcelain") == "" then
    vim.notify("Nothing to stash! Working directory is clean.", vim.log.levels.WARN, { title = "Git Stash" })
    return
  end

  vim.ui.input({ prompt = "Stash Message: " }, function(input)
    if not input or input == "" then
      vim.notify("Stash aborted: Empty message", vim.log.levels.INFO, { title = "Git Stash" })
      return
    end

    local output = vim.fn.system(string.format("git stash push -u -m %s", vim.fn.shellescape(input)))
    if vim.v.shell_error == 0 then
      vim.notify("Stashed successfully:\n" .. input, vim.log.levels.INFO, { title = "Git Stash" })
      vim.api.nvim_exec_autocmds("User", { pattern = "NeogitStatusRefreshed" })
    else
      vim.notify("Stash failed:\n" .. output, vim.log.levels.ERROR, { title = "Git Stash" })
    end
  end)
end

function M.git_commit_with_prompt()
  vim.fn.system("git diff --cached --quiet")
  if vim.v.shell_error == 0 then
    vim.notify("No staged changes to commit!", vim.log.levels.WARN, { title = "Git" })
    return
  end

  vim.ui.input({ prompt = "Commit Message: " }, function(input)
    if not input or input == "" then
      vim.notify("Commit aborted: Empty message", vim.log.levels.INFO, { title = "Git" })
      return
    end

    local output = vim.fn.system(string.format("git commit -m %s", vim.fn.shellescape(input)))
    if vim.v.shell_error == 0 then
      vim.notify("Committed successfully:\n" .. input, vim.log.levels.INFO, { title = "Git" })
      vim.api.nvim_exec_autocmds("User", { pattern = "NeogitStatusRefreshed" })
    else
      vim.notify("Commit failed:\n" .. output, vim.log.levels.ERROR, { title = "Git" })
    end
  end)
end

function M.toggle_diffview_commit()
  local has_diffview, diffview_lib = pcall(require, "diffview.lib")
  if has_diffview and next(diffview_lib.views) ~= nil then
    vim.cmd("DiffviewClose")
    return
  end

  require("snacks").picker.git_log({
    confirm = function(picker, item)
      picker:close()

      if not item then
        return
      end

      local commit = item.commit
        or item.hash
        or (item.data and (item.data.commit or item.data.hash))
        or (item.data and item.data.oid)

      if not commit then
        vim.notify("No commit hash found: " .. vim.inspect(item), vim.log.levels.ERROR)
        return
      end

      vim.cmd("DiffviewOpen " .. commit)
    end,
  })
end

function M.toggle_diffview_branch()
  local has_diffview, diffview_lib = pcall(require, "diffview.lib")
  if has_diffview and next(diffview_lib.views) ~= nil then
    vim.cmd("DiffviewClose")
  else
    require("snacks").picker.git_branches({
      confirm = function(picker, item)
        picker:close()
        if item and item.branch then
          vim.cmd("DiffviewOpen " .. item.branch)
        end
      end,
    })
  end
end

function M.toggle_diffview()
  local has_diffview, diffview_lib = pcall(require, "diffview.lib")
  if has_diffview and next(diffview_lib.views) == nil then
    vim.cmd("DiffviewOpen")
  else
    vim.cmd("DiffviewClose")
  end
end

-- =============================================================================
-- 5. OTHER MISCELLANEOUS SYSTEM UTILITIES
-- =============================================================================

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

function M.compile_and_run_cpp()
  vim.cmd("w")
  local path = vim.fn.expand("%:p:r"):gsub("\\", "/")
  local fileDir = vim.fn.expand("%:p:h")
  local command = string.format("cd %s && clang++ --debug -o %s %s.cpp && %s", fileDir, path, path, path)

  vim.api.nvim_input("<C-/>")
  vim.defer_fn(function()
    vim.api.nvim_put({ command }, "l", true, true)
  end, 100)
end

function M.open_tab_terminal()
  vim.cmd("tabnew | terminal")
  vim.cmd("startinsert")
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

-- File System Clean targets
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
          local win = vim.api.nvim_open_win(buf, true, {
            relative = "editor",
            width = width,
            height = height,
            row = row,
            col = col,
            style = "minimal",
            border = "rounded",
          })

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
