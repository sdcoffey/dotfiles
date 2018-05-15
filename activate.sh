#!/bin/bash

set -e

dotfiles_dir=$(cd "$(dirname "$0")"; pwd)

for name in aliases tmux.conf vim vimrc zshrc vimrc.bundles; do
  rm -rf "${HOME}/.${name}"
  ln -s "${dotfiles_dir}/${name}" "${HOME}/.${name}"
done

vim +PlugInstall +PlugClean! +qall
