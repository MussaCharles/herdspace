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
# HS_ROLE=both (from bootstrap.sh both) replaces ROLE: one machine is both.
setup_shell() {
  local role="${HS_ROLE:-$1}" color tmp
  case "$role" in
    client | both) color="${PROMPT_COLOR_CLIENT:-166}" ;;
    *) color="${PROMPT_COLOR_SERVER:-30}" ;;
  esac
  run_part "Oh My Zsh and Powerlevel10k" shell_pins_ready install_shell_pins
  install_file "${REPO_ROOT}/config/shell/zshrc.zsh" "${HOME}/.config/herdspace/zshrc.zsh"
  install_file "${REPO_ROOT}/config/shell/p10k.zsh" "${HOME}/.p10k.zsh"
  install_file "${REPO_ROOT}/config/shell/extras.zsh" "${HOME}/.config/herdspace/extras.zsh"
  tmp="$(mktemp)"
  printf 'export BOOTSTRAP_ROLE=%s\nexport BOOTSTRAP_PROMPT_COLOR=%s\n' "$role" "$color" >"$tmp"
  install_file "$tmp" "${HOME}/.config/herdspace/env.zsh"
  rm -f "$tmp"
  setup_zshrc
}

# The block that loads the herdspace shell from ~/.zshrc.
# shellcheck disable=SC2016 # The lines are text for zsh.
ZSHRC_BLOCK='if [[ -r "$HOME/.config/herdspace/zshrc.zsh" ]]; then
  source "$HOME/.config/herdspace/zshrc.zsh"
fi'

# zshrc_template prints a new ~/.zshrc: the block, then room for your own lines.
zshrc_template() {
  printf '# Your zsh configuration. herdspace changes only the marked block, and it\n'
  printf '# never replaces this file.\n'
  printf '# >>> herdspace >>>\n%s\n# <<< herdspace <<<\n\n' "$ZSHRC_BLOCK"
  printf '# Put your own lines below. They load after herdspace, so they can change\n'
  printf '# what it sets.\n'
}

# old_herdspace_zshrc FILE exits 0 if FILE is the ~/.zshrc of an older herdspace,
# which owned the whole file.
old_herdspace_zshrc() {
  head -n 1 "$1" 2>/dev/null | grep -Eqx '# Managed by herd(space|r-bootstrap)\. A new run replaces this file\.'
}

# move_to_template FILE OWN writes the new ~/.zshrc in place of the file of an
# older herdspace, after a backup. OWN, your own lines, go below the block,
# each one behind "# ", so that nothing runs before you look at it.
move_to_template() {
  local file="$1" own="$2" tmp
  tmp="$(mktemp)"
  zshrc_template >"$tmp"
  if [ -n "$own" ]; then
    {
      printf '\n# Your own lines from the old file, copied by the herdspace setup on %s.\n' "$(date +%Y-%m-%d)"
      printf '# The full old file is %s.bak-%s. Each line starts with "# ".\n' "$(short_home "$file")" "$STAMP"
      printf '# Remove it from each line that you want, and keep if/fi blocks complete.\n'
      printf '%s\n' "$own" | sed 's/^/# /'
    } >>"$tmp"
  fi
  write_file "$tmp" "$file" 644
  rm -f "$tmp"
}

# ask_zshrc FILE asks what to do with your own ~/.zshrc. It sets ZSHRC_ANSWER to
# full, extras, or keep. The default is full, unless the file loads Oh My Zsh.
ask_zshrc() {
  local file="$1" answer default=f
  ! grep -q 'oh-my-zsh\.sh' "$file" || default=e
  while true; do
    printf '\n  %s%s~/.zshrc is your own file. herdspace never replaces it.%s\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
    printf '  It can add a marked block. Your own lines stay as they are.\n\n'
    ui_key f "Add a block at the top that loads the full herdspace shell" "$([ "$default" = f ] && echo '(Enter)')"
    ui_key e "Add a block at the end that loads only the shell extras" "$([ "$default" = e ] && echo '(Enter)')"
    ui_key k "Keep your file with no change"
    ui_key d "Show what each block does"
    printf '\n  Your choice: '
    IFS= read -r answer || answer="k"
    [ -n "$answer" ] || answer="$default"
    case "$answer" in
      f) ZSHRC_ANSWER="full"; return 0 ;;
      e) ZSHRC_ANSWER="extras"; return 0 ;;
      k) ZSHRC_ANSWER="keep"; return 0 ;;
      d)
        printf '\n  f: the block loads ~/.config/herdspace/zshrc.zsh: the prompt, Oh My Zsh, and the\n'
        printf '     extras. Your lines come after it, so they can change what it sets. Do not\n'
        printf '     choose f if your file loads Oh My Zsh or another prompt already.\n'
        printf '  e: the block loads ~/.config/herdspace/extras.zsh: the fzf keys, zoxide, ff, fif,\n'
        printf '     the completion of hopen, and eza and bat for ls and cat. The extras add and\n'
        printf '     never replace: an alias, a variable, or a key that you set stays yours.\n'
        ;;
    esac
  done
}

# setup_zshrc makes ~/.zshrc load the herdspace shell from a marked block.
# herdspace never replaces a ~/.zshrc of yours. It replaces only the file of
# an older herdspace, after a backup, and it keeps your own lines in it.
setup_zshrc() {
  local file="${HOME}/.zshrc" own tmp
  if [ ! -e "$file" ]; then
    if [ "$MODE" = "check" ]; then
      note_todo "${file} is missing"
    else
      tmp="$(mktemp)"
      zshrc_template >"$tmp"
      write_file "$tmp" "$file" 644
      rm -f "$tmp"
    fi
    return 0
  fi
  if grep -qxF '# >>> herdspace >>>' "$file"; then
    ensure_block "$file" "herdspace" "$ZSHRC_BLOCK"
    return 0
  fi
  if old_herdspace_zshrc "$file"; then
    own="$(own_lines "${REPO_ROOT}/config/shell/zshrc.zsh" "$file")"
    if [ "$MODE" = "check" ]; then
      note_todo "${file} is the file of an older herdspace. A run gives it the new layout."
      return 0
    fi
    move_to_template "$file" "$own"
    info "Your ~/.zshrc was the file of an older herdspace. It is now your file, with a marked block that loads the herdspace shell."
    [ -z "$own" ] || info "Your own lines from the old file are at its end, each behind \"# \". Review them there."
    return 0
  fi
  if grep -qxF '# >>> herdspace extras >>>' "$file"; then
    extras_block "$file"
    return 0
  fi
  ZSHRC_ANSWER="keep"
  case "$MODE" in
    check) info "${file} is your own file, with no block that loads herdspace."; return 0 ;;
    replace) ZSHRC_ANSWER="extras" ;;
    ask) [ ! -t 0 ] || ask_zshrc "$file" ;;
  esac
  # shellcheck disable=SC2034 # common.sh reads ZSHRC_KEPT_NO_EXTRAS at the end of the run.
  case "$ZSHRC_ANSWER" in
    full) ensure_block "$file" "herdspace" "$ZSHRC_BLOCK" top; ok "Added a block that loads the herdspace shell at the top of your ~/.zshrc." ;;
    extras) extras_block "$file"; ok "Added a block that loads the herdspace shell extras at the end of your ~/.zshrc." ;;
    *) ZSHRC_KEPT_NO_EXTRAS=1 ;;
  esac
}

# setup_zprofile writes the login block. A server also checks for a new Herdr.
setup_zprofile() {
  local role="${HS_ROLE:-$1}" text
  # shellcheck disable=SC2016 # These lines are text for zsh.
  text='[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
  if [ "$role" != "client" ]; then
    # shellcheck disable=SC2016
    text="${text}"'
if [[ -n "$SSH_CONNECTION" && -t 1 && -x "$HOME/.local/bin/herdr-update-check" ]]; then
  "$HOME/.local/bin/herdr-update-check"
fi'
  fi
  ensure_block "${HOME}/.zprofile" "herdspace" "$text"
}
