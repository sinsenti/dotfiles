local M = {}

function M.search_json_and_copy_value()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local raw_text = table.concat(lines, "\n")

  if raw_text:match("^%s*$") then
    vim.notify("Buffer is empty!", vim.log.levels.WARN)
    return
  end

  local ok, decoded = pcall(vim.json.decode, raw_text)
  if not ok or type(decoded) ~= "table" then
    vim.notify("Failed to parse valid JSON from buffer", vim.log.levels.ERROR)
    return
  end

  local entries = {}
  local lookup = {}

  local function flatten(obj, path)
    if type(obj) == "table" then
      local is_array = (vim.islist and vim.islist(obj)) or vim.tbl_islist(obj)
      if is_array then
        for i, val in ipairs(obj) do
          local new_path = string.format("%s[%d]", path, i)
          if type(val) == "table" then
            flatten(val, new_path)
          else
            local val_str = val == nil and "null" or tostring(val)
            local item_str = string.format("%s: %s", new_path, val_str)
            table.insert(entries, item_str)
            lookup[item_str] = val_str
          end
        end
      else
        for k, v in pairs(obj) do
          local new_path = path == "" and tostring(k) or (path .. "." .. tostring(k))
          if type(v) == "table" then
            flatten(v, new_path)
          else
            local val_str = v == nil and "null" or tostring(v)
            local item_str = string.format("%s: %s", new_path, val_str)
            table.insert(entries, item_str)
            lookup[item_str] = val_str
          end
        end
      end
    end
  end

  flatten(decoded, "")

  if #entries == 0 then
    vim.notify("No JSON key-value pairs found", vim.log.levels.WARN)
    return
  end

  table.sort(entries)

  require("fzf-lua").fzf_exec(entries, {
    prompt = "JSON Keys> ",
    actions = {
      ["default"] = function(selected)
        if not selected or #selected == 0 then
          return
        end
        local choice = selected[1]
        local val_to_copy = lookup[choice]

        if val_to_copy then
          vim.fn.setreg("+", val_to_copy)
          vim.fn.setreg('"', val_to_copy)
          vim.notify("Copied: " .. val_to_copy, vim.log.levels.INFO, { title = "JSON Copy" })
        end
      end,
    },
  })
end


return M
