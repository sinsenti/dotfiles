local opts = { noremap = true, silent = true }

-- vim.keymap.set('n', '<leader>cp', function()
--     local filepath = vim.fn.expand('%:p')
--     filepath = filepath:gsub('\\', '/')
--     vim.fn.setreg('+', filepath)
--     print("Copied file path to clipboard: " .. filepath)
-- end, { desc = "Copy file path to clipboard with forward slashes" })

vim.keymap.set('n', '<leader>cp', function()
    local filepath = vim.fn.expand('%:p')
    filepath = filepath:gsub('\\', '/')  -- Replace backslashes with forward slashes
    filepath = filepath:gsub(' ', '\\ ') -- Escape spaces by adding a backslash before each
    vim.fn.setreg('+', filepath)
    print("Copied file path to clipboard: " .. filepath)
end, { desc = "Copy file path to clipboard with forward slashes and escaped spaces" })

vim.keymap.set('n', '<leader>dd', function()
    vim.cmd('Format')
    vim.cmd('w')
    local path = vim.fn.expand('%:p:r')
    -- local path = vim.fn.expand('%:p')
    -- local file_name = vim.fn.expand('%:t:r')
    path = vim.fn.substitute(path, '\\', '/', 'g')
    -- vim.fn.setreg('+', path)
    -- local clipboard_content = vim.fn.getreg('+')
    -- local command = 'clang++ -o ' .. file_name .. ' ' .. path .. ' && ./' .. file_name ..
    local command = 'clang++ -o ' .. path .. ' ' .. path .. '.cpp && ' .. path ..
        vim.cmd('lua open_floating_terminal()')
    vim.api.nvim_put({ command }, 'l', true, true)
end, opts)

vim.keymap.set('n', '<leader>md', function()
    vim.cmd('ZenMode')
    -- vim.cmd('set spell!')
    vim.cmd('PencilSoft')
    vim.cmd('Twilight')
end, { desc = 'Toggle Zenmode and pensil' })

vim.keymap.set('n', '<leader>[', function()
    vim.api.nvim_command('normal! 2l')
    vim.fn.search('[')
end, { noremap = true, silent = true, desc = 'Find square Bracket' })
vim.keymap.set('n', 'gl', ":lua vim.fn.search('(')<CR>", { noremap = true, silent = true, desc = 'Find Bracket' })
function _G.save_and_delete_buffer()
    local buftype = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t')
    if vim.api.nvim_buf_get_name(0) == '' then
        vim.cmd('bdelete')
    elseif buftype == 'bash.exe' then
        vim.api.nvim_feedkeys("iexit\n", "n", false)
    else
        vim.cmd('w')
        vim.cmd('bdelete')
    end
end

function _G.open_floating_terminal()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = 120,
        height = 30,
        col = math.floor((vim.o.columns - 120) / 2),
        row = math.floor((vim.o.lines - 30) / 2),
        style = 'minimal',
        border = 'single',
    })
    vim.cmd('terminal')
end

function _G.open_split_terminal()
    vim.cmd('vsplit')
    local win = vim.api.nvim_get_current_win()
    -- vim.wo[win].wrap = false  -- Disable line wrapping
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    -- vim.wo[win].cursorline = false   -- Disable cursorline
    vim.wo[win].cursorcolumn = false -- Disable cursorcolumn
    local command = 'ollama run llama3.2'

    vim.cmd('terminal')
    vim.api.nvim_put({ command }, 'l', true, true)
end

vim.api.nvim_create_user_command('DeleteFile', function()
    vim.cmd('w')
    local file = vim.fn.expand('%:p')
    if vim.fn.filereadable(file) == 1 then
        vim.fn.delete(file)
    else
    end
    vim.cmd('bdelete')
end, { desc = 'Delete the current file and buffer' })
