export PATH="/usr/local/bin:$PATH"
export PATH="$PATH:$SYSTEM_SCRIPTS/bin"


source ~/.aliases

autoload -U compinit
compinit

autoload -U colors
colors

autoload -U select-word-style
select-word-style bash

timeout () {
  perl -e 'use Time::HiRes qw( usleep ualarm gettimeofday tv_interval ); ualarm 100000; exec @ARGV' "$@";
}

git_untracked_count() {
  count=`echo $(timeout git ls-files --other --exclude-standard | wc -l)`
  if [ $count -eq 0 ]; then return; fi
  echo "%{$fg_bold[yellow]%}?%{$fg_no_bold[white]%}:%{$reset_color$fg[yellow]%}$count%{$reset_color%}"
}

git_modified_count() {
  count=`echo $(timeout git ls-files -md | wc -l)`
  if [ $count -eq 0 ]; then return; fi
  echo "%{$fg_bold[red]%}M%{$fg_no_bold[white]%}:%{$reset_color$fg[red]%}$count%{$reset_color%}"
}

git_staged_count() {
  count=`echo $(timeout git diff-index --cached --name-only HEAD 2>/dev/null | wc -l)`
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
export EDITOR=nvim
export LESS='XFR'

alias vim=nvim

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


if [[ -f ~/.zshrc_local ]]; then
  source ~/.zshrc_local
fi


git_prompt_info() {
  if [[ $(in_git_repo) -gt 0 ]]; then return; fi
  print " on $(git_branch)$(git_diff_info)"
}

export PROMPT='%(?.%F{14}⏺.%F{9}⏺)%f %B%F{green}%2~%f%F{blue}$(git_prompt_info)%f %F{red}›%f%b '

# bun completions
[ -s "/Users/sdcoffey/.bun/_bun" ] && source "/Users/sdcoffey/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

. $HOME/.asdf/asdf.sh
. "$HOME/.cargo/env"
