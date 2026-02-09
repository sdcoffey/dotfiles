DISABLE_AUTO_UPDATE="true"
DISABLE_MAGIC_FUNCTIONS="true"
DISABLE_COMPFIX="true"

# mise completions (if present)
MISE_COMPLETIONS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/mise/completions"
if [ -d "$MISE_COMPLETIONS_DIR" ]; then
  fpath=("$MISE_COMPLETIONS_DIR" $fpath)
fi

autoload -Uz compinit
if [ "$(date +'%j')" != "$(stat -f '%Sm' -t '%j' ~/.zcompdump 2>/dev/null)" ]; then
    compinit
else
    compinit -C
fi


# Prefer Neovim when available
if command -v nvim >/dev/null 2>&1; then
  alias vim='nvim'
fi

source ~/.aliases

autoload -U colors
colors

autoload -U select-word-style
select-word-style bash

git_repo_is_large() {
  local index_path index_size
  index_path=$(git rev-parse --git-path index 2>/dev/null) || return 1
  index_size=$(stat -f %z "$index_path" 2>/dev/null) || return 1
  [[ $index_size -gt 20000000 ]]
}

git_untracked_count() {
  git_repo_is_large && return
  local count
  count=$(gtimeout 0.2s git ls-files --other --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  if [ "$count" -eq 0 ]; then return; fi
  echo "%{$fg_bold[yellow]%}?%{$fg_no_bold[white]%}:%{$reset_color$fg[yellow]%}$count%{$reset_color%}"
}

git_modified_count() {
  git_repo_is_large && return
  local count
  count=$(gtimeout 0.2s git ls-files -md 2>/dev/null | wc -l | tr -d ' ')
  if [ "$count" -eq 0 ]; then return; fi
  echo "%{$fg_bold[red]%}M%{$fg_no_bold[white]%}:%{$reset_color$fg[red]%}$count%{$reset_color%}"
}

git_staged_count() {
  count=`echo $(gtimeout 1s git diff-index --cached --name-only HEAD 2>/dev/null | wc -l)`
  if [ $count -eq 0 ]; then return; fi
  echo "%{$fg_bold[green]%}S%{$fg_no_bold[white]%}:%{$reset_color$fg[green]%}$count%{$reset_color%}"
}

git_branch() {
  git rev-parse --abbrev-ref HEAD
}

git_remote_difference() {
  branch=$(git symbolic-ref HEAD --quiet)
  if [ -z $branch ]; then return; fi

  remote=$(git remote show)
  ahead_by=`echo $(git log --oneline $remote/${branch#refs/heads/}..HEAD 2> /dev/null | wc -l)`
  behind_by=`echo $(git log --oneline HEAD..$remote/${branch#refs/heads/} 2> /dev/null | wc -l)`

  output=""
  if [ $ahead_by -gt 0 ]; then output="$output%{$fg_bold[white]%}↑%{$reset_color%}$ahead_by"; fi
  if [ $behind_by -gt 0 ]; then output="$output%{$fg_bold[white]%}↓%{$reset_color%}$behind_by"; fi

  echo $output
}

git_user() {
  user=$(git config user.name)
  if [ -z $user ]; then
    echo "%{$fg_bold[red]%}no user%{$fg[black]%}@%{$reset_color%}"
  else
    echo "$user%{$fg[black]%}@%{$reset_color%}"
  fi
}

in_git_repo() {
  if [[ -d .git ]]; then
    echo 0
  else
    echo $(git rev-parse --git-dir > /dev/null 2>&1; echo $?)
  fi
}

git_diff_info() {
  if [[ $(in_git_repo) -gt 0 ]]; then return; fi
  if [[ -n $DISABLE_GIT_PROMPT ]]; then return; fi
  print " $(git_staged_count)$(git_modified_count)$(git_untracked_count)"
}

set -o emacs
setopt prompt_subst
setopt HIST_IGNORE_DUPS
export HISTSIZE=200

export LOCALE="en_US.UTF-8"
export LANG="en_US.UTF-8"

export CLICOLOR=1
export LSCOLORS=ExFxCxDxBxegedabagacad

export GREP_OPTIONS='--color'
export EDITOR=vim
export LESS='XFR'


autoload edit-command-line
zle -N edit-command-line
bindkey '^X^e' edit-command-line

stty stop undef
stty start undef

_rake () {
  if [ -f Rakefile ]; then
    compadd `rake --silent --tasks | cut -d " " -f 2`
  fi
}

compdef _rake rake

_cap () {
  if [ -f Capfile ]; then
    compadd `cap -vT | grep '^cap' | cut -d ' ' -f 2`
  fi
}

compdef _cap cap

function tmux-start {
  local session=$1
  [ -z "$session" ] && session="pair"
  tmux -S /tmp/$session new-session -s $session -d
  chmod 777 /tmp/$session
  tmux -S /tmp/$session attach -t $session
}

function tmux-join {
  local session=$1
  [ -z "$session" ] && session="pair"
  tmux -S /tmp/$1 new-session -t $1
}

function tmux-list {
  ps -eo ruser,command | grep '[n]ew-session -s' | ruby -ne '$_ =~ /^(\w+).*-s (\w+)/; puts "#{$1} started #{$2}"'
}

function tmux-watch {
  local session=$1
  [ -z "$session" ] && session="pair"
  tmux -S /tmp/$1 attach -t $1 -r
}

function tag-list {
  git tag --list | sort --version-sort
}

# Fast fuzzy file finder with resilient per-repo caching.
_ff_cache_dir() {
  echo "${XDG_CACHE_HOME:-$HOME/.cache}/ff"
}

_ff_repo_root() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) && {
    echo "$root"
    return
  }
  echo "$PWD"
}

_ff_cache_key() {
  local root="$1"
  printf '%s' "$root" | shasum -a 256 | awk '{print $1}'
}

_ff_mtime() {
  stat -f "%m" "$1" 2>/dev/null || echo 0
}

_ff_cache_needs_rebuild() {
  local cache_file="$1"
  local root="$2"
  local ttl_seconds="${FF_CACHE_TTL_SECONDS:-300}"

  [[ ! -s "$cache_file" ]] && return 0

  local now cache_mtime
  now=$(date +%s)
  cache_mtime=$(_ff_mtime "$cache_file")

  (( now - cache_mtime > ttl_seconds )) && return 0

  local git_dir index_file candidate
  git_dir=$(git -C "$root" rev-parse --git-dir 2>/dev/null) || return 1
  [[ "$git_dir" != /* ]] && git_dir="$root/$git_dir"
  index_file="$git_dir/index"

  (( $(_ff_mtime "$index_file") > cache_mtime )) && return 0

  for candidate in "$root/.gitignore" "$root/.ignore" "$root/.fdignore" "$git_dir/info/exclude"; do
    (( $(_ff_mtime "$candidate") > cache_mtime )) && return 0
  done

  return 1
}

_ff_build_cache() {
  local root="$1"
  local cache_file="$2"
  local tmp_file="${cache_file}.tmp.$$"

  if command -v fd >/dev/null 2>&1; then
    (cd "$root" && fd --type f --hidden --exclude .git . > "$tmp_file")
  else
    (cd "$root" && rg --files --hidden -g '!.git' > "$tmp_file")
  fi

  mv "$tmp_file" "$cache_file"
}

_ff_refresh_cache_async() {
  local root="$1"
  local cache_file="$2"
  local lock_file="${cache_file}.lock"

  ( set -o noclobber; : > "$lock_file" ) 2>/dev/null || return 0

  (
    trap 'rm -f "$lock_file"' EXIT
    _ff_build_cache "$root" "$cache_file" >/dev/null 2>&1
  ) &!
}

ff() {
  if ! command -v fzf >/dev/null 2>&1; then
    echo "ff: fzf is not installed"
    return 1
  fi

  local root cache_dir cache_file selected file
  root=$(_ff_repo_root)
  cache_dir=$(_ff_cache_dir)
  mkdir -p "$cache_dir"

  cache_file="$cache_dir/$(_ff_cache_key "$root").files"

  if [[ ! -s "$cache_file" ]]; then
    _ff_build_cache "$root" "$cache_file" || return 1
  elif _ff_cache_needs_rebuild "$cache_file" "$root"; then
    _ff_refresh_cache_async "$root" "$cache_file"
  fi

  selected=$(cd "$root" && fzf \
    --height "${FF_FZF_HEIGHT:-80%}" \
    --layout reverse \
    --prompt "ff> " \
    --preview 'bat --style=numbers --color=always --line-range :200 {} 2>/dev/null || sed -n "1,200p" {} 2>/dev/null' \
    < "$cache_file") || return 0

  [[ -z "$selected" ]] && return 0
  file="$root/$selected"

  if [[ $# -gt 0 ]]; then
    "$@" "$file"
  else
    "${EDITOR:-vim}" "$file"
  fi
}



git_prompt_info() {
  if [[ $(in_git_repo) -gt 0 ]]; then return; fi
  print " on $(git_branch)$(git_diff_info)"
}

export BASE_PROMPT='%(?.%F{14}⏺.%F{9}⏺)%f %B%F{green}%2~%f%F{blue}$(git_prompt_info)%f %F{red}›%f%b '

precmd() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    PROMPT="($(basename $VIRTUAL_ENV)) $BASE_PROMPT"
  else
    PROMPT="$BASE_PROMPT"
  fi
}

if [ -d "$HOME/.openai/shrc" ]; then
  for file in "/Users/sdcoffey/.openai/shrc"/*; do
      source "$file"
  done
fi

if [ -f "$HOME/.local/bin/env" ]; then
  . "$HOME/.local/bin/env"
fi

# mise activation (version manager)
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

if [[ -f ~/.zshrc_local ]]; then
  source ~/.zshrc_local
fi

# Keep dotslash-gen off the global PATH; allow it only via direnv in the monorepo.
autoload -Uz add-zsh-hook
DOTSLASH_GEN_BIN="$HOME/openai/openai/project/dotslash-gen/bin"
DOTSLASH_DIRENV_DIR="$HOME/openai/openai"
_dotslash_guard() {
  local direnv_dir="${DIRENV_DIR#-}"
  if [[ "$PWD" == "$DOTSLASH_DIRENV_DIR" || "$PWD" == "$DOTSLASH_DIRENV_DIR"/* ]]; then
    return
  fi
  case "$direnv_dir" in
    "$DOTSLASH_DIRENV_DIR"|"$DOTSLASH_DIRENV_DIR"/*)
      return
      ;;
  esac
  path=(${path:#$DOTSLASH_GEN_BIN})
}
_dotslash_guard
add-zsh-hook precmd _dotslash_guard
add-zsh-hook chpwd _dotslash_guard
