local cmd = vim.cmd
local fn = vim.fn
local g = vim.g
local o = vim.o

g.mapleader = ' '

o.softtabstop = 2
o.shiftwidth = 2
o.expandtab = true
o.number = true
o.termguicolors = true

o.backup = true
o.backupdir = os.getenv('HOME') .. '/.cache/nvim/backup//'
o.directory = os.getenv('HOME') .. '/.cache/nvim/swap//'
o.undofile = true
o.undodir = os.getenv('HOME') .. '/.cache/nvim/undo//'
o.updatetime = 100

cmd 'filetype plugin on'
cmd 'filetype plugin indent on'

local stl = {
  '%#ColorColumn#%2f',          -- buffer number
  ' ',                          -- separator
  '%<',                         -- truncate here
  '%*»',                        -- separator
  '%*»',                        -- separator
  '%#DiffText#%m',              -- modified flag
  '%r',                         -- readonly flag
  '%*»',                        -- separator
  '%#CursorLine#(%l/%L,%c)%*»', -- line no./no. of lines,col no.
  '%=«',                        -- right align the rest
  '%#Cursor#%02B',              -- value of current char in hex
  '%*«',                        -- separator
  '%#ErrorMsg#%o',              -- byte offset
  '%*«',                        -- separator
  '%#Title#%y',                 -- filetype
  '%*«',                        -- separator
  '%#ModeMsg#%3p%%',            -- % through file in lines
  '%*',                         -- restore normal highlight
}
o.statusline = table.concat(stl)

function prequire(...)
  local status, lib = pcall(require, ...)
  if status then return lib end
  return nil
end

local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({'git', 'clone', '--filter=blob:none', 'https://github.com/folke/lazy.nvim.git', '--branch=stable', lazypath})
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  spec = {
    'folke/tokyonight.nvim',

    'neoclide/coc.nvim',
    'junegunn/fzf',
    'junegunn/fzf.vim',
    'lewis6991/gitsigns.nvim',
    'phaazon/hop.nvim',
    'rluba/jai.vim',
    'kdheepak/lazygit.nvim',
    'ggandor/lightspeed.nvim',
    'alaviss/nim.nvim',
    {'hrsh7th/nvim-cmp', dependencies = {'hrsh7th/cmp-buffer', 'hrsh7th/cmp-nvim-lsp'}},
    'terrortylor/nvim-comment',
    'mfussenegger/nvim-dap',
    'neovim/nvim-lspconfig',
    {'nvim-treesitter/nvim-treesitter', build = ':TSUpdate'},
    {'romgrk/nvim-treesitter-context', config = function() require('treesitter-context').setup() end},
    'nvim-treesitter/nvim-treesitter-textobjects',
    'nvim-treesitter/playground',
    {'nvim-telescope/telescope.nvim', dependencies = {'nvim-lua/plenary.nvim'}},
    'justinmk/vim-dirvish',
    'tpope/vim-fugitive',
    'mhinz/vim-grepper',
    'dstein64/vim-startuptime',
    'preservim/vimux',
    'folke/which-key.nvim',
  },
  performance = {
    rtp = {
      disabled_plugins = {
        'gzip',
        'matchit',
        'matchparen',
        'netrwPlugin',
        'tarPlugin',
        'tohtml',
        'tutor',
        'zipPlugin',
      },
    },
  },
})

pcall(cmd, 'colorscheme tokyonight')

-- Mappings {{{1
local function map(mode, lhs, rhs, opts)
  local options = {noremap = true}
  if opts then options = vim.tbl_extend('force', options, opts) end
  vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end
local function nmap(lhs, rhs, opts)
  map('n', lhs, rhs, opts)
end
local function nmapp(lhs, rhs, opts)
  local options = {}
  if opts then options = vim.tbl_extend('force', options, opts) end
  vim.api.nvim_set_keymap('n', lhs, rhs, options)
end

local function xnmap(keys, func, desc)
  vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
end

map('n', ':', ';')
map('n', ';', ':')
map('x', ':', ';')
map('x', ';', ':')

-- g
nmap('ga', ':<C-u>CocList -I symbols<cr>')
nmap('gj', ':HopLineAC<cr>')
nmap('gk', ':opLineBC<cr>')
xnmap('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
-- <leader>
xnmap('<leader>?', require('telescope.builtin').oldfiles, { desc = '[?] Find recently opened files' })
xnmap('<leader><space>', require('telescope.builtin').buffers, { desc = '[ ] Find existing buffers' })
nmap('<leader>.', '<cmd>lua require("telescope.builtin").find_files({search_dirs={vim.fn.expand("%:h:p")}})<cr>', {silent=true})
-- <leader>a (app)
nmap('<leader>ag', '<cmd>%!genhdr<cr>')
nmap('<leader>aG', '<cmd>%!genhdr windows<cr>')
-- <leader>b (buffer)
nmap('<leader>bn', '<cmd>bn<cr>')
nmap('<leader>bp', '<cmd>bp<cr>')
nmap('<leader>bN', '<cmd>new<cr>')
nmap('<leader>bR', '<cmd>e<cr>')
-- <leader>d (diff)
nmap('<leader>dt', '<cmd>diffthis<cr>')
nmap('<leader>do', '<cmd>bufdo diffoff<cr>')
-- <leader>e (error)
nmap('<leader>ee', ':e <C-r>=expand("%:p:h") . "/"<cr>')
nmap('<leader>es', ':sp <C-r>=expand("%:p:h") . "/"<cr>')
nmap('<leader>ev', ':vsp <C-r>=expand("%:p:h") . "/"<cr>')
nmapp('<leader>en', '<Plug>(coc-diagnostic-next')
nmapp('<leader>ep', '<Plug>(coc-diagnostic-prev')
-- <leader>f (file)
nmap('<leader>fc', '<cmd>cd %:p:h<cr>')
nmap('<leader>fe', '<cmd>e ~/.config/nvim/init.lua<cr>')
nmap('<leader>ff', '<cmd>Telescope find_files<cr>')
nmap('<leader>fr', '<cmd>Telescope oldfiles<cr>')
-- <leader>g (fugitive)
nmap('<leader>gb', '<cmd>Git blame<cr>')
nmap('<leader>gd', '<cmd>Git diff<cr>')
nmap('<leader>gl', '<cmd>Git log<cr>')
nmap('<leader>gg', '<cmd>Git status<cr>')
-- <leader>l (lsp)
nmap('<leader>le', '<cmd>CocList diagnostics<cr>')
nmapp('<leader>lf', '<Plug>(coc-fix-current)')
nmap('<leader>li', '<cmd>CocList outline<cr>')
nmapp('<leader>lr', '<Plug>(coc-rename)')
-- <leader>q (quit)
nmap('<leader>qq', '<cmd>quit<cr>')
-- <leader>s (search)
nmap('<leader>sd', '<cmd>Telescope live_grep<cr>')
nmap('<leader>ss', '<cmd>lua require("telescope.builtin").grep_string()<cr>')
nmap('<leader>sS', '<cmd>Grepper -noprompt -cword<cr>')
-- <leader>t (toggle)
nmap('<leader>tl', '<cmd>lua require("fn").toggle_loclist()<cr>')
nmap('<leader>tn', '<cmd>set number!<cr>')
nmap('<leader>tq', '<cmd>lua require("fn").toggle_qf()<cr>')
nmap('<leader>ts', '<cmd>set spell!<cr>')
nmap('<leader>tw', '<cmd>set wrap!<cr>')
-- w (window)
nmapp('<leader>wo', '<C-w>o')
nmapp('<leader>ws', '<C-w>s')
nmapp('<leader>wv', '<C-w>v')
--- , (references)
nmap(',f', '<cmd>call CocLocations("ccls","textDocument/references",{"excludeRole":32})<cr>') -- not call
nmap(',m', '<cmd>call CocLocations("ccls","textDocument/references",{"role":64})<cr>') -- macro
nmap(',r', '<cmd>call CocLocations("ccls","textDocument/references",{"role":8})<cr>') -- read
nmap(',w', '<cmd>call CocLocations("ccls","textDocument/references",{"role":16})<cr>') -- write
-- x (xref)
-- bases of up to 3 le