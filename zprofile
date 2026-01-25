export SSH_AUTH_SOCK=/Users/sdcoffey/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh

# Added by Toolbox App
export PATH="$PATH:/Users/sdcoffey/Library/Application Support/JetBrains/Toolbox/scripts"

# OpenAI shprofile (if customising, comment out to prevent it getting readded)
# Skip the managed venv auto-activation snippet to avoid a global default venv.
if [ -d "$HOME/.openai/shprofile" ]; then
  for file in "$HOME/.openai/shprofile"/*; do
    [[ "$file" == */venv ]] && continue
    source "$file"
  done
fi
