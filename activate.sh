#!/bin/bash

set -euo pipefail

echo "-------------------------"
echo "Custom dotfiles setup"
echo "-------------------------"

dotfiles_dir=$(cd "$(dirname "$0")"; pwd)
ts=$(date +%Y%m%d%H%M%S)

NVIM_VERSION="v0.11.5"

ensure_mise() {
  if command -v mise >/dev/null 2>&1; then
    return
  fi

  echo "mise not found; installing via https://mise.run"
  if curl -fsSL https://mise.run | sh; then
    if [ -x "${HOME}/.local/bin/mise" ] && ! command -v mise >/dev/null 2>&1; then
      export PATH="${HOME}/.local/bin:${PATH}"
    fi

    if command -v mise >/dev/null 2>&1; then
      echo "mise installation complete"
    else
      echo "mise installed but not on PATH yet; restart your shell with: exec zsh -l"
    fi
  else
    echo "failed to install mise automatically; install with: curl https://mise.run | sh"
  fi
}

ensure_nvim() {
  if command -v nvim >/dev/null 2>&1; then
    return
  fi

  os="$(uname -s)"

  run_pm_install() {
    local pm="$1"
    shift

    if [ "$(id -u)" -eq 0 ]; then
      "$pm" "$@"
    elif command -v sudo >/dev/null 2>&1; then
      sudo "$pm" "$@"
    else
      "$pm" "$@"
    fi
  }

  if command -v brew >/dev/null 2>&1; then
    echo "nvim not found; installing via Homebrew"
    if brew install neovim; then
      echo "neovim installation complete"
    else
      echo "failed to install neovim via Homebrew; run: brew install neovim"
    fi
  else
    echo "nvim not found; installing from github"

    curl "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz" -o $HOME/nvim-linux-x86_64.tar.gz
    tar xzvf $HOME/nvim-linux-x86_64.tar.gz
    sudo ln -s $HOME/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
  fi
}

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
link_item "${dotfiles_dir}/aliases"       "${HOME}/.aliases"
link_item "${dotfiles_dir}/tmux.conf"     "${HOME}/.tmux.conf"
link_item "${dotfiles_dir}/vim"           "${HOME}/.vim"
link_item "${dotfiles_dir}/vimrc"         "${HOME}/.vimrc"
link_item "${dotfiles_dir}/zshrc"         "${HOME}/.zshrc"
link_item "${dotfiles_dir}/zprofile"      "${HOME}/.zprofile"
link_item "${dotfiles_dir}/zshenv"        "${HOME}/.zshenv"
link_item "${dotfiles_dir}/gitconfig"     "${HOME}/.gitconfig"
link_item "${dotfiles_dir}/tool-versions" "${HOME}/.tool-versions"

# Neovim config
mkdir -p "${HOME}/.config"
link_item "${dotfiles_dir}/nvim" "${HOME}/.config/nvim"

# Ensure required tools are installed
ensure_mise

mise install

ensure_nvim

# mise bootstrap & completions (requires mise + network)
if command -v mise >/dev/null 2>&1; then
  mise use -g usage@latest || true
  mise_completions_dir="${XDG_DATA_HOME:-$HOME/.local/share}/mise/completions"
  mkdir -p "$mise_completions_dir"
  mise completion zsh > "$mise_completions_dir/_mise" || true
fi

# Install/update Neovim plugins (requires network)
if command -v nvim >/dev/null 2>&1; then
  nvim --headless "+Lazy! sync" +qa || true
else
  echo "nvim not found; skipping plugin sync"
fi

if command -v mise >/dev/null 2>&1; then
  mise install
else
  echo "mise not correctly installed; skipping mise install"
fi

echo "Done. Restart your shell with: exec zsh -l"
