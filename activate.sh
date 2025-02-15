#!/bin/bash

set -e

echo "-------------------------"
echo "Custom dotfiles setup"
echo "-------------------------"


if [ ! -d "$HOME/.asdf" ]; then
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf
fi

dotfiles_dir=$(cd "$(dirname "$0")"; pwd)

for name in aliases tmux.conf vim zshrc gitconfig; do
  rm -rf "${HOME}/.${name}"
  ln -s "${dotfiles_dir}/${name}" "${HOME}/.${name}"
done

# install lvim
LV_BRANCH='release-1.4/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh)

# install lvim config
mkdir -p ~/.config/lvim
ln -s "${dotfiles_dir}/config.lua" "${HOME}/.config/lvim/config.lua"

# curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
#     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim


# vim +PlugInstall +PlugClean! +qall

lvim +LvimSyncCorePlugins +q
