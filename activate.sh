#!/bin/bash

set -e

echo "-------------------------"
echo "Custom dotfiles setup"
echo "-------------------------"


go install github.com/asdf-vm/asdf/cmd/asdf@v0.16.0
mkdir -p "${ASDF_DATA_DIR:-$HOME/.asdf}/completions"


dotfiles_dir=$(cd "$(dirname "$0")"; pwd)

for name in aliases tmux.conf vim zshrc gitconfig; do
  rm -rf "${HOME}/.${name}"
  ln -s "${dotfiles_dir}/${name}" "${HOME}/.${name}"
done

# install lvim
LV_BRANCH='release-1.4/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh) -y --install-dependencies

# install lvim config
mkdir -p $HOME/.config/lvim
if [ ! -e "$HOME/.config/lvim/config.lua" ]; then
  ln -s "${dotfiles_dir}/config.lua" "${HOME}/.config/lvim/config.lua"
fi

# curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
#     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim


# vim +PlugInstall +PlugClean! +qall

lvim +LvimSyncCorePlugins +q

source ~/.zshrc
asdf completion zsh > "${ASDF_DATA_DIR:-$HOME/.asdf}/completions/_asdf"

