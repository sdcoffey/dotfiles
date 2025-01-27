#!/bin/bash

set -e

echo "-------------------------"
echo "Custom dotfiles setup"
echo "-------------------------"


if [ ! -d "$HOME/.asdf" ]; then
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf
fi

dotfiles_dir=$(cd "$(dirname "$0")"; pwd)

for name in aliases tmux.conf vim vimrc zshrc vimrc.bundles gitconfig; do
  rm -rf "${HOME}/.${name}"
  ln -s "${dotfiles_dir}/${name}" "${HOME}/.${name}"
done

curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim


vim +PlugInstall +PlugClean! +qall
