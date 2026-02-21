# Dotfiles

This repo manages your shell, Vim, and Neovim setup.

## New Machine Setup
1. Clone this repo to `~/code/dotfiles`.
2. Install core tools:
```bash
brew install neovim ripgrep mise gh tmux
```
If you don’t use Homebrew, you can install mise with:
```bash
curl https://mise.run | sh
```
3. Activate the dotfiles:
```bash
~/code/dotfiles/activate.sh
```
4. Restart your shell:
```bash
exec zsh -l
```

5. Authenticate GitHub CLI (needed for `newpr`):
```bash
gh auth login
```

The activation script will back up any existing dotfiles as `*.bak.<timestamp>`.

## What Gets Linked
- `~/.aliases` -> `~/code/dotfiles/aliases`
- `~/.tmux.conf` -> `~/code/dotfiles/tmux.conf`
- `~/.vim` -> `~/code/dotfiles/vim`
- `~/.vimrc` -> `~/code/dotfiles/vimrc`
- `~/.zshrc` -> `~/code/dotfiles/zshrc`
- `~/.zprofile` -> `~/code/dotfiles/zprofile`
- `~/.zshenv` -> `~/code/dotfiles/zshenv`
- `~/.gitconfig` -> `~/code/dotfiles/gitconfig`
- `~/.config/nvim` -> `~/code/dotfiles/nvim`

## Neovim Setup
Plugins are managed with `lazy.nvim` and synced automatically by `activate.sh`.

After opening Neovim, install language servers:
```vim
:Mason
```
Suggested servers: `pyright`, `tsserver`, `gopls`, `rust_analyzer`, `lua_ls`, `jsonls`, `yamlls`, `bashls`.

## Key Neovim Shortcuts
- Files: `<leader>ff`
- Files (repo): `<leader>fF`
- Files (with untracked): `<leader>fu`
- Files (repo + untracked): `<leader>fU`
- Grep: `<leader>fg` (advanced mode: `<C-r>` root, `<C-f>` mask, `<C-p>` parent, `<C-b>` clear)
- Grep (custom root/extensions): `<leader>fC` or `:LiveGrepCustom`
- Buffers: `<leader>fb`
- Document symbols: `<leader>fs`
- Workspace symbols: `<leader>fS`
- Copy formatted snippet (visual): `<leader>ys` or `:CopySnippet`
- GitHub permalink (line or visual range): `<leader>gh` or `:OpenGithub`
- Copy GitHub permalink (line or visual range): `<leader>cg` or `:CopyGithub`
- Go to definition: `gd`
- References: `gr`
- Hover: `K`
- Rename: `<leader>rn`
- Code action: `<leader>ca`
- Diagnostics: `<leader>fd`, `[d`, `]d`

## Repo-Specific Notes (OpenAI Monorepo)
In large repos, prompt performance is protected by a size check in `~/.zshrc`.

If `git status` is slow in a large repo, run these inside the repo:
```bash
git config core.fsmonitor false
git config core.untrackedCache true
git update-index --untracked-cache
```
