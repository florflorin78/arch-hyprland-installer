-- ~/.config/nvim/init.lua — Neovim >= 0.11 (LSP nativ)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local o = vim.opt
o.number = true
o.relativenumber = true
o.termguicolors = true
o.signcolumn = "yes"
o.cursorline = true
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.smartindent = true
o.ignorecase = true
o.smartcase = true
o.undofile = true
o.updatetime = 250
o.timeoutlen = 300
o.splitright = true
o.splitbelow = true
o.scrolloff = 8
o.wrap = false
o.clipboard = "unnamedplus"
o.completeopt = "menu,menuone,noselect,popup"

-- plugin manager (lazy.nvim) — se instalează singur la prima pornire
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable",
        "https://github.com/folke/lazy.nvim.git", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    {
        "folke/tokyonight.nvim",
        priority = 1000,
        config = function()
            require("tokyonight").setup({
                style = "night",
                on_colors = function(c) c.bg = "#0b0b12"; c.bg_dark = "#07070c" end,
            })
            vim.cmd.colorscheme("tokyonight")
        end,
    },
    { "nvim-lualine/lualine.nvim", opts = { options = { theme = "tokyonight", globalstatus = true } } },
    { "lewis6991/gitsigns.nvim", opts = {} },
    { "folke/which-key.nvim", event = "VeryLazy", opts = {} },
    { "numToStr/Comment.nvim", opts = {} },
    { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },
    { "stevearc/oil.nvim", opts = {}, config = function()
        require("oil").setup()
        vim.keymap.set("n", "-", "<cmd>Oil<cr>", { desc = "File explorer (oil)" })
    end },
    {
        "nvim-telescope/telescope.nvim",
        branch = "0.1.x",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            local b = require("telescope.builtin")
            vim.keymap.set("n", "<leader>ff", b.find_files, { desc = "Caută fișiere" })
            vim.keymap.set("n", "<leader>fg", b.live_grep, { desc = "Caută în conținut" })
            vim.keymap.set("n", "<leader>fb", b.buffers, { desc = "Buffere" })
            vim.keymap.set("n", "<leader>fh", b.help_tags, { desc = "Help" })
        end,
    },
    { "neovim/nvim-lspconfig" },   -- oferă definițiile serverelor pentru vim.lsp.enable()
}, { rocks = { enabled = false }, checker = { enabled = false } })

-- LSP (serverele sunt instalate din pacman: vezi packages/30-dev.txt)
local servers = {
    pyright = {}, ruff = {}, ts_ls = {}, rust_analyzer = {}, gopls = {}, bashls = {}, clangd = {},
    lua_ls = { settings = { Lua = { diagnostics = { globals = { "vim" } } } } },
}
for name, cfg in pairs(servers) do vim.lsp.config(name, cfg) end
vim.lsp.enable(vim.tbl_keys(servers))

vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if client and client:supports_method("textDocument/completion") then
            vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
        end
        local m = function(keys, fn, desc) vim.keymap.set("n", keys, fn, { buffer = ev.buf, desc = desc }) end
        m("gd", vim.lsp.buf.definition, "Definiție")
        m("gr", vim.lsp.buf.references, "Referințe")
        m("<leader>rn", vim.lsp.buf.rename, "Redenumește")
        m("<leader>ca", vim.lsp.buf.code_action, "Code action")
        m("<leader>f", function() vim.lsp.buf.format({ async = true }) end, "Formatează")
    end,
})

vim.diagnostic.config({ virtual_text = true, severity_sort = true })

-- taste utile
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>")
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-l>", "<C-w>l")
vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", { desc = "Salvează" })
vim.keymap.set("n", "<leader>q", "<cmd>q<cr>", { desc = "Ieși" })
