" Minimal Vim config. Neovim uses ~/.config/nvim/init.lua.

set nocompatible

let mapleader = "\\"
let maplocalleader = "\\"

syntax on
set number
set hidden
set ignorecase
set smartcase
set incsearch
set hlsearch
set signcolumn=yes
set scrolloff=5
set wrap
set expandtab
set shiftwidth=2
set tabstop=2
set softtabstop=2
set undofile
set undodir=~/.vim/undodir
set backupcopy=yes

set wildignore+=*.pyc,*.o,*.class,*.lo,.git,vendor/*,node_modules/**,bower_components/**,*/build_gradle/*,*/build_intellij/*,*/build/*,*/cassandra_data/*

" Map jk to escape
inoremap jk <Esc>
inoremap jK <Esc>
inoremap JK <Esc>
inoremap Jk <Esc>

" Keep local overrides
if filereadable(expand('~/.vimrc_local'))
  source ~/.vimrc_local
endif
