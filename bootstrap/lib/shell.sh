#!/usr/bin/env bash
# Sets up zsh, Oh My Zsh, Powerlevel10k, and the prompt color.

OMZ_DIR="${HOME}/.oh-my-zsh"
OMZ_CUSTOM="${OMZ_DIR}/custom"

pin_ready() { [ -d "$1/.git" ] && [ "$(git -C "$1" rev-parse HEAD 2>/dev/null)" = "$2" ]; }

shell_pins_ready() {
  have git || return 1
  pin_ready "$OMZ_DIR" "$OHMYZSH_REF" &&
    pin_ready "${OMZ_CUSTOM}/themes/powerlevel10k" "$POWERLEVEL10K_REF" &&
    pin_ready "${OMZ_CUSTOM}/plugins/zsh-autosuggestions" "$ZSH_AUTOSUGGESTIONS_REF" &&
    pin_ready "${OMZ_CUSTOM}/plugins/zsh-syntax-highlighting" "$ZSH_SYNTAX_HIGHLIGHTING_REF"
}

install_shell_pins() {
  git_pin https://github.com/ohmyzsh/ohmyzsh.git "$OMZ_DIR" "$OHMYZSH_REF"
  git_pin https://github.com/romkatv/powerlevel10k.git "${OMZ_CUSTOM}/themes/powerlevel10k" "$POWERLEVEL10K_REF"
  git_pin https://github.com/zsh-users/zsh-autosuggestions.git "${OMZ_CUSTOM}/plugins/zsh-autosuggestions" "$ZSH_AUTOSUGGESTIONS_REF"
  git_pin https://github.com/zsh-users/zsh-syntax-highlighting.git "${OMZ_CUSTOM}/plugins/zsh-syntax-highlighting" "$ZSH_SYNTAX_HIGHLIGHTING_REF"
  # Oh My Zsh warns at each start if another account can write to its folders.
  chmod -R go-w "$OMZ_DIR"
}

# setup_shell ROLE. ROLE is "client" or "server". The folder segment of the
# prompt has a different color on each, so a shell shows where it runs.
setup_shell() {
  local role="$1" color tmp
  case "$role" in
    client) color="${PROMPT_COLOR_CLIENT:-166}" ;;
    *) color="${PROMPT_COLOR_SERVER:-30}" ;;
  esac
  run_part "Oh My Zsh and Powerlevel10k" shell_pins_ready install_shell_pins
  install_file "${REPO_ROOT}/config/shell/zshrc.zsh" "${HOME}/.zshrc"
  install_file "${REPO_ROOT}/config/shell/p10k.zsh" "${HOME}/.p10k.zsh"
  tmp="$(mktemp)"
  printf 'export BOOTSTRAP_ROLE=%s\nexport BOOTSTRAP_PROMPT_COLOR=%s\n' "$role" "$color" >"$tmp"
  install_file "$tmp" "${HOME}/.config/herdspace/env.zsh"
  rm -f "$tmp"
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
  ensure_block "${HOME}/.zprofile" "herdspace" "$text"
}
