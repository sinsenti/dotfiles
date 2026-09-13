local M = {}
local H = require("config.functions.helpers")

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

  local win = H.open_float(buf, width, height, row, col, {
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

  local win = H.open_float(buf, width, height, row, col, {
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

  local win = H.open_float(buf, width, height, row, col, {
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

  local win = H.open_float(buf, width, height, row, col, {
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


return M
