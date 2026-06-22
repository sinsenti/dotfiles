local M = {
  "harpoon-local", -- A dummy name for lazy.nvim tracking purposes
  dir = vim.fn.stdpath("config"), -- Point it somewhere safe so lazy doesn't try to clone from GitHub
  lazy = false, -- Load on startup so shortcuts are always active
}

local data_path = vim.fn.stdpath("data") .. "/global_harpoon.json"
local harpoon_list = {}

local function load_list()
  if vim.fn.filereadable(data_path) == 1 then
    local lines = vim.fn.readfile(data_path)
    local data = table.concat(lines, "")
    local ok, decoded = pcall(vim.json.decode, data)
    if ok and type(decoded) == "table" then
      return decoded
    end
  end
  return {}
end

local function save_list(list)
  local ok, encoded = pcall(vim.json.encode, list)
  if ok then
    vim.fn.writefile({ encoded }, data_path)
  end
end

-- Initialize local state tracking
harpoon_list = load_list()

local function add_to_global_list()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return
  end
  file = vim.uv.fs_realpath(file) or file

  for _, v in ipairs(harpoon_list) do
    if v == file then
      vim.notify("Already in Global List", vim.log.levels.WARN)
      return
    end
  end

  table.insert(harpoon_list, file)
  save_list(harpoon_list)
  vim.notify("Added to Global List: " .. vim.fn.fnamemodify(file, ":t"))
end

local function toggle_global_menu()
  local buf = vim.api.nvim_create_buf(false, true)
  harpoon_list = load_list()

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, harpoon_list)
  vim.bo[buf].modifiable = true

  local width = math.min(90, vim.o.columns - 10)
  local height = math.max(4, math.min(15, #harpoon_list + 2))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    border = "rounded",
    title = " Edit Global Marks (Press Esc/q to save) ",
    title_pos = "center",
  })

  local function sync_buffer_changes_to_disk()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local new_list = {}
    for _, line in ipairs(lines) do
      local clean = line:gsub("^%s*(.-)%s*$", "%1")
      if clean ~= "" then
        table.insert(new_list, clean)
      end
    end
    harpoon_list = new_list
    save_list(new_list)
  end

  local opts = { buffer = buf, silent = true }

  vim.keymap.set("n", "<CR>", function()
    local line = vim.api.nvim_get_current_line():gsub("^%s*(.-)%s*$", "%1")
    sync_buffer_changes_to_disk()
    vim.api.nvim_win_close(win, true)
    if line ~= "" then
      vim.cmd("edit " .. vim.fn.fnameescape(line))
    end
  end, opts)

  local function close_and_save()
    sync_buffer_changes_to_disk()
    vim.cmd("stopinsert")
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.keymap.set("n", "q", close_and_save, opts)
  vim.keymap.set({ "n", "i" }, "<Esc>", close_and_save, opts)
end

local function select_global_index(i)
  harpoon_list = load_list()
  local target = harpoon_list[i]
  if target then
    vim.cmd("edit " .. vim.fn.fnameescape(target))
  else
    vim.notify("No global mark at slot " .. i, vim.log.levels.WARN)
  end
end

-- This config() block runs automatically when Neovim sources your plugins directory
function M.config()
  vim.keymap.set("n", "<leader>HH", add_to_global_list, { desc = "Add File to Global List" })
  vim.keymap.set("n", "<leader>hh", toggle_global_menu, { desc = "Toggle Modifiable Global Menu" })

  for i = 1, 9 do
    vim.keymap.set("n", "<leader>" .. i, function()
      select_global_index(i)
    end, { desc = "Jump to Global " .. i })
  end
end

return M
