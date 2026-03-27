# Dotfiles

This repo manages your shell, tmux, and Neovim setup.

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

This setup expects Neovim `0.11+`. If you see Lua errors mentioning `vim.fs.joinpath`, your shell is still launching an older system `nvim`; rerun `~/code/dotfiles/activate.sh` and restart the shell so `~/.local/bin/nvim` takes precedence.

5. Authenticate GitHub CLI (needed for `newpr`):
```bash
gh auth login
```

The activation script will back up any existing dotfiles as `*.bak.<timestamp>`.

For remote Linux hosts reached over SSH, `activate.sh` also links `~/.ssh/rc` so forwarded SSH agent sockets are refreshed at `~/.ssh/ssh_auth_sock`. This keeps GitHub SSH auth working inside tmux after reconnects.

## What Gets Linked
- `~/.aliases` -> `~/code/dotfiles/aliases`
- `~/.tmux.conf` -> `~/code/dotfiles/tmux.conf`
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
Suggested Mason packages: `pyright`, `typescript-language-server`, `gopls`, `rust-analyzer`, `lua-language-server`, `json-lsp`, `yaml-language-server`, `bash-language-server`, `ruby-lsp`, `tsp-server`.

## Key Neovim Shortcuts
- Files (tracked + untracked): `<leader>ff`
- Files (repo, tracked + untracked): `<leader>fF`
- Files (refresh cache): `<leader>fu`
- Files (repo, refresh cache): `<leader>fU`
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

The shell `ff` helper and the Neovim file pickers share the same per-repo cache in `~/.cache/ff`, built from `git ls-files --cached --others --exclude-standard`. That means they see untracked, non-gitignored files without paying the full scan cost on every open.
