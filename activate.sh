#!/bin/bash

set -euo pipefail

echo "-------------------------"
echo "Custom dotfiles setup"
echo "-------------------------"

dotfiles_dir=$(cd "$(dirname "$0")"; pwd)
ts=$(date +%Y%m%d%H%M%S)

NVIM_VERSION="v0.11.5"

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    "$@"
  fi
}

install_via_package_manager() {
  local brew_pkg="${1:-}"
  local apt_pkg="${2:-}"
  local dnf_pkg="${3:-}"
  local yum_pkg="${4:-}"
  local pacman_pkg="${5:-}"
  local zypper_pkg="${6:-}"
  local apk_pkg="${7:-}"

  if command -v brew >/dev/null 2>&1 && [ -n "$brew_pkg" ]; then
    brew install "$brew_pkg"
    return $?
  fi

  if command -v apt-get >/dev/null 2>&1 && [ -n "$apt_pkg" ]; then
    run_as_root apt-get update
    run_as_root apt-get install -y "$apt_pkg"
    return $?
  fi

  if command -v dnf >/dev/null 2>&1 && [ -n "$dnf_pkg" ]; then
    run_as_root dnf install -y "$dnf_pkg"
    return $?
  fi

  if command -v yum >/dev/null 2>&1 && [ -n "$yum_pkg" ]; then
    run_as_root yum install -y "$yum_pkg"
    return $?
  fi

  if command -v pacman >/dev/null 2>&1 && [ -n "$pacman_pkg" ]; then
    run_as_root pacman -Sy --noconfirm "$pacman_pkg"
    return $?
  fi

  if command -v zypper >/dev/null 2>&1 && [ -n "$zypper_pkg" ]; then
    run_as_root zypper --non-interactive install "$zypper_pkg"
    return $?
  fi

  if command -v apk >/dev/null 2>&1 && [ -n "$apk_pkg" ]; then
    run_as_root apk add --no-cache "$apk_pkg"
    return $?
  fi

  return 1
}

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

  local os arch nvim_asset archive_url tmpdir install_root target_dir
  os="$(uname -s)"
  arch="$(uname -m)"

  echo "nvim not found; attempting package manager install"
  if install_via_package_manager "neovim" "neovim" "neovim" "neovim" "neovim" "neovim" "neovim"; then
    if command -v nvim >/dev/null 2>&1; then
      echo "neovim installation complete"
      return
    fi
  else
    echo "package manager install for neovim not available; falling back to github release"
  fi

  case "$os" in
    Linux)
      case "$arch" in
        x86_64|amd64) nvim_asset="nvim-linux-x86_64.tar.gz" ;;
        aarch64|arm64) nvim_asset="nvim-linux-arm64.tar.gz" ;;
        *)
          echo "unsupported Linux architecture for automatic nvim install: $arch"
          return 1
          ;;
      esac
      ;;
    Darwin)
      case "$arch" in
        x86_64|amd64) nvim_asset="nvim-macos-x86_64.tar.gz" ;;
        arm64|aarch64) nvim_asset="nvim-macos-arm64.tar.gz" ;;
        *)
          echo "unsupported macOS architecture for automatic nvim install: $arch"
          return 1
          ;;
      esac
      ;;
    *)
      echo "unsupported OS for automatic nvim install: $os"
      return 1
      ;;
  esac

  archive_url="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${nvim_asset}"
  tmpdir="$(mktemp -d)"
  install_root="${HOME}/.local/opt"
  target_dir="${install_root}/nvim-${NVIM_VERSION}-${os}-${arch}"

  mkdir -p "${install_root}" "${HOME}/.local/bin"
  echo "nvim not found; installing from github release (${nvim_asset})"

  if curl -fsSL "$archive_url" -o "${tmpdir}/${nvim_asset}"; then
    tar xzf "${tmpdir}/${nvim_asset}" -C "${tmpdir}"
    rm -rf "${target_dir}"
    mv "${tmpdir}/$(basename "${nvim_asset}" .tar.gz)" "${target_dir}"
    ln -sf "${target_dir}/bin/nvim" "${HOME}/.local/bin/nvim"
    export PATH="${HOME}/.local/bin:${PATH}"
    echo "neovim installation complete (${HOME}/.local/bin/nvim)"
  else
    echo "failed to install neovim from ${archive_url}"
    rm -rf "${tmpdir}"
    return 1
  fi

  rm -rf "${tmpdir}"
}

ensure_gh() {
  if command -v gh >/dev/null 2>&1; then
    return
  fi

  echo "gh not found; attempting package manager install"
  if install_via_package_manager "gh" "gh" "gh" "gh" "github-cli" "gh" "github-cli"; then
    if command -v gh >/dev/null 2>&1; then
      echo "GitHub CLI installation complete"
      return
    fi
  fi

  echo "GitHub CLI (gh) is required. Install it and rerun: activate.sh"
  return 1
}

ensure_tmux() {
  if command -v tmux >/dev/null 2>&1; then
    return
  fi

  echo "tmux not found; attempting package manager install"
  if install_via_package_manager "tmux" "tmux" "tmux" "tmux" "tmux" "tmux" "tmux"; then
    if command -v tmux >/dev/null 2>&1; then
      echo "tmux installation complete"
      return
    fi
  fi

  echo "tmux is required. Install it and rerun: activate.sh"
  return 1
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
ensure_gh
ensure_tmux

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
  # Install common Tree-sitter parsers used in this setup (best-effort).
  nvim --headless "+lua require('nvim-treesitter.install').install({ 'python', 'rust', 'typescript', 'tsx', 'ruby', 'go' }, { summary = true }):wait()" +qa || true
else
  echo "nvim not found; skipping plugin sync"
fi

if command -v mise >/dev/null 2>&1; then
  mise install
else
  echo "mise not correctly installed; skipping mise install"
fi

echo "Done. Restart your shell with: exec zsh -l"
