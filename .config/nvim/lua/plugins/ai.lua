return {
    {
        'MeanderingProgrammer/markdown.nvim',
        main = 'render-markdown',
        event = 'BufRead',
        opts = {},
        name = 'render-markdown',                             -- Only needed if you have another plugin named markdown.nvim
        dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons', 'echasnovski/mini.nvim' }, -- if you use the mini.nvim suite
    },
    -- {
    --     'MeanderingProgrammer/render-markdown.nvim',
    --     -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' }, -- if you use the mini.nvim suite
    --     -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.icons' }, -- if you use standalone mini plugins
    --     dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
    --     ---@module 'render-markdown'
    --     ---@type render.md.UserConfig
    --     opts = {},
    -- },
    -- {
    --     "iamcco/markdown-preview.nvim",
    --     cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    --     ft = { "markdown", ".md" },
    --     build = function() vim.fn["mkdp#util#install"]() end,
    -- },
    {
        "christoomey/vim-tmux-navigator",
        lazy = false,
    },
    {
        "akinsho/toggleterm.nvim",
        version = "*",
        config = function()
            require("toggleterm").setup({
                size = 20,
                width = 0.3,
                height = 0.3,
                open_mapping = [[<c-_>]],
                direction = "float",   -- Options: "horizontal", "vertical", "float"
                float_opts = {
                    border = "curved", -- Options: "single", "double", "shadow", etc.
                    -- width = 145,
                    -- height = 35,
                    width = function()
                        return math.floor(vim.o.columns * 0.75) -- 80% of screen width
                    end,
                    height = function()
                        return math.floor(vim.o.lines * 0.65) -- 80% of screen height
                    end,
                },
            })
        end,
    },
    -- {
    --     "Exafunction/codeium.nvim",
    --     dependencies = {
    --         "nvim-lua/plenary.nvim",
    --         "hrsh7th/nvim-cmp",
    --     },
    --     config = function()
    --         require("codeium").setup({
    --         })
    --     end
    -- },

    -- {
    --     "David-Kunz/gen.nvim",
    --     opts = {
    --         model = "mistral",
    --         quit_map = "q",
    --         retry_map = "<c-r>",
    --         accept_map = "<c-cr>",
    --         host = "localhost",
    --         port = "11434",
    --         display_mode = "float",
    --         show_prompt = true,
    --         show_model = true,
    --         no_auto_close = false, -- Never closes the window automatically.
    --         file = false,      -- Write the payload to a temporary file to keep the command short.
    --         hidden = false,    -- Hide the generation window (if true, will implicitly set `prompt.replace = true`), requires Neovim >= 0.10
    --         init = function(options) pcall(io.popen, "ollama serve > /dev/null 2>&1 &") end,
    --         command = function(options)
    --             local body = { model = options.model, stream = true }
    --             return "curl --silent --no-buffer -X POST http://" ..
    --             options.host .. ":" .. options.port .. "/api/chat -d $body"
    --         end,
    --         -- The command for the Ollama service. You can use placeholders $prompt, $model and $body (shellescaped).
    --         -- This can also be a command string.
    --         -- The executed command must return a JSON object with { response, context }
    --         -- (context property is optional).
    --         -- list_models = '<omitted lua function>', -- Retrieves a list of model names
    --         debug = false -- Prints errors and the command which is run.
    --     },
    -- },
    -- Custom Parameters (with defaults)
    -- {
    --     "nvim-neo-tree/neo-tree.nvim",
    --     branch = "v3.x",
    --     dependencies = {
    --         "nvim-lua/plenary.nvim",
    --         "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
    --         "MunifTanjim/nui.nvim",
    --         "3rd/image.nvim",              -- Optional image support in preview window: See `# Preview Mode` for more information
    --     },
    --     config = function()
    --         require('neo-tree').setup({
    --             window = {
    --                 position = "right",
    --             },
    --             mappings = {
    --                 -- ["l"] = ["<cr>"],
    --                 ["h"] = "close_node",
    --             },
    --         })
    --     end,
    -- },
}
