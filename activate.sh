#!/bin/bash

set -euo pipefail

echo "-------------------------"
echo "Custom dotfiles setup"
echo "-------------------------"

dotfiles_dir=$(cd "$(dirname "$0")"; pwd)
ts=$(date +%Y%m%d%H%M%S)

link_item() {
  local src="$1"
  local dest="$2"

  if [ -L "$dest" ]; then
    rm "$dest"
  elif [ -e "$dest" ]; then
    mv "$dest" "${dest}.bak.${ts}"
  fi

  ln -s "$src" "$dest"
  echo "linked $dest -> $src"
}

# Core dotfiles
link_item "${dotfiles_dir}/aliases"   "${HOME}/.aliases"
link_item "${dotfiles_dir}/tmux.conf" "${HOME}/.tmux.conf"
link_item "${dotfiles_dir}/vim"       "${HOME}/.vim"
link_item "${dotfiles_dir}/vimrc"     "${HOME}/.vimrc"
link_item "${dotfiles_dir}/zshrc"     "${HOME}/.zshrc"
link_item "${dotfiles_dir}/zprofile"  "${HOME}/.zprofile"
link_item "${dotfiles_dir}/zshenv"    "${HOME}/.zshenv"
link_item "${dotfiles_dir}/gitconfig" "${HOME}/.gitconfig"

# Neovim config
mkdir -p "${HOME}/.config"
link_item "${dotfiles_dir}/nvim" "${HOME}/.config/nvim"

# mise bootstrap & completions (requires mise + network)
if command -v mise >/dev/null 2>&1; then
  mise use -g usage@latest || true
  mise_completions_dir="${XDG_DATA_HOME:-$HOME/.local/share}/mise/completions"
  mkdir -p "$mise_completions_dir"
  mise completion zsh > "$mise_completions_dir/_mise" || true
else
  echo "mise not found; install with: curl https://mise.run | sh"
fi

# Install/update Neovim plugins (requires network)
if command -v nvim >/dev/null 2>&1; then
  nvim --headless "+Lazy! sync" +qa || true
else
  echo "nvim not found; skipping plugin sync"
fi

echo "Done. Restart your shell with: exec zsh -l"
