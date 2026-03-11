if [ "$(uname -s)" = "Darwin" ]; then
  secretive_socket="/Users/sdcoffey/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh"
  if [ -S "$secretive_socket" ]; then
    export SSH_AUTH_SOCK="$secretive_socket"
  fi
fi

if [ -n "${SSH_AUTH_SOCK:-}" ] && [ ! -S "$SSH_AUTH_SOCK" ]; then
  unset SSH_AUTH_SOCK
fi

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# Added by Toolbox App
export PATH="$PATH:/Users/sdcoffey/Library/Application Support/JetBrains/Toolbox/scripts"

# OpenAI shprofile (if customising, comment out to prevent it getting readded)
# Skip the managed venv auto-activation snippet to avoid a global default venv.
if [ -d "$HOME/.openai/shprofile" ]; then
  for file in "$HOME/.openai/shprofile"/*; do
    [[ "$file" == */venv ]] && continue
    [[ "$file" == */dotslash ]] && continue
    source "$file"
  done
fi
