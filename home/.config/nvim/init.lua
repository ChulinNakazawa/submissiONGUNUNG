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
local f