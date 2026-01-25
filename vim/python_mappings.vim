if exists("b:dotfiles_python_mappings_loaded") | finish | endif
let b:dotfiles_python_mappings_loaded = 1

map <silent> <LocalLeader>rb :wa<CR> :TestFile<CR>
map <silent> <LocalLeader>rf :wa<CR> :TestNearest<CR>
