" Minimal Vim config. Neovim uses ~/.config/nvim/init.lua.

set nocompatible

let mapleader = "\\"
let maplocalleader = "\\"

syntax on
filetype plugin indent on
set number
set autoread
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

" Autoload language-specific mappings on filetype detection.
augroup dotfiles_filetype_mappings
  autocmd!
  autocmd FileType python,python3 if filereadable(expand('~/.vim/python_mappings.vim')) | source ~/.vim/python_mappings.vim | endif
  autocmd FileType ruby,eruby,rake,rspec if filereadable(expand('~/.vim/ruby_mappings.vim')) | source ~/.vim/ruby_mappings.vim | endif
augroup END

" Refresh buffers when files change on disk.
augroup dotfiles_autoread
  autocmd!
  autocmd FocusGained,BufEnter,CursorHold,CursorHoldI * if mode() !=# 'c' | checktime | endif
  autocmd FileChangedShellPost * echo "File changed on disk. Buffer reloaded."
augroup END

" Keep local overrides
if filereadable(expand('~/.vimrc_local'))
  source ~/.vimrc_local
endif
