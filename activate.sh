#!/bin/bash

set -e

if [ ! -d "$HOME/.asdf" ]; then
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf
fi

dotfiles_dir=$(cd "$(dirname "$0")"; pwd)

for name in aliases tmux.conf vim vimrc zshrc vimrc.bundles gitconfig; do
  rm -rf "${HOME}/.${name}"
  ln -s "${dotfiles_dir}/${name}" "${HOME}/.${name}"
done

vim +PlugInstall +PlugClean! +qall
