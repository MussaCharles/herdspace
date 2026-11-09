#!/usr/bin/env bash
# Sets up zsh, Oh My Zsh, Powerlevel10k, and the prompt color.

# setup_shell ROLE. ROLE is "client" or "server". The folder segment of the
# prompt has a different color on each, so a shell shows where it runs.
setup_shell() {
  local role="$1" color omz="${HOME}/.oh-my-zsh" custom zshrc="${HOME}/.zshrc"
  case "$role" in
    client) color="${PROMPT_COLOR_CLIENT:-166}" ;;
    *) color="${PROMPT_COLOR_SERVER:-30}" ;;
  esac
  custom="${omz}/custom"

  step "Shell"
  git_pin https://github.com/ohmyzsh/ohmyzsh.git "$omz" "$OHMYZSH_REF"
  git_pin https://github.com/romkatv/powerlevel10k.git "${custom}/themes/powerlevel10k" "$POWERLEVEL10K_REF"
  git_pin https://github.com/zsh-users/zsh-autosuggestions.git "${custom}/plugins/zsh-autosuggestions" "$ZSH_AUTOSUGGESTIONS_REF"
  git_pin https://github.com/zsh-users/zsh-syntax-highlighting.git "${custom}/plugins/zsh-syntax-highlighting" "$ZSH_SYNTAX_HIGHLIGHTING_REF"

  if [ -f "$zshrc" ] && ! grep -q 'Managed by herdr-bootstrap' "$zshrc"; then
    info "Your old ~/.zshrc goes to a backup. Put your own lines in ~/.zshrc.local."
  fi
  install_file "${REPO_ROOT}/config/shell/zshrc.zsh" "$zshrc"
  install_file "${REPO_ROOT}/config/shell/p10k.zsh" "${HOME}/.p10k.zsh"

  local env_file="${HOME}/.config/herdr-bootstrap/env.zsh" tmp
  tmp="$(mktemp)"
  printf 'export BOOTSTRAP_ROLE=%s\nexport BOOTSTRAP_PROMPT_COLOR=%s\n' "$role" "$color" >"$tmp"
  install_file "$tmp" "$env_file"
  rm -f "$tmp"
  ok "zsh, Oh My Zsh, and Powerlevel10k"
}

# setup_zprofile writes the login block. A server also checks for a new Herdr.
setup_zprofile() {
  local role="$1" text
  # shellcheck disable=SC2016 # These lines are text for zsh.
  text='[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
  if [ "$role" = "server" ]; then
    # shellcheck disable=SC2016
    text="${text}"'
if [[ -n "$SSH_CONNECTION" && -t 1 && -x "$HOME/.local/bin/herdr-update-check" ]]; then
  "$HOME/.local/bin/herdr-update-check"
fi'
  fi
  ensure_block "${HOME}/.zprofile" "herdr-bootstrap" "$text"
}
