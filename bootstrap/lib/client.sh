#!/usr/bin/env bash
# Steps that are the same on a macOS client and on a Linux client.

SSH_CHECK=(-o BatchMode=yes -o ConnectTimeout=5)

# terminfo_ready exits 0 if the server has the description. A server that does
# not answer also counts, so that it does not stop the run.
terminfo_ready() {
  local server="$1"
  if ! ssh "${SSH_CHECK[@]}" -- "$server" true 2>/dev/null; then
    warn "Could not connect to ${server}, so this script skips it."
    return 0
  fi
  ssh "${SSH_CHECK[@]}" -- "$server" infocmp -x xterm-ghostty >/dev/null 2>&1
}

# copy_terminfo sends the Ghostty terminal description to one server.
copy_terminfo() {
  local server="$1"
  infocmp -x xterm-ghostty | ssh -- "$server" tic -x - 2>/dev/null || warn "Could not copy the terminal description to ${server}."
}

# The keys. KEYS is "herdspace" (the default) or "terminal". With "herdspace",
# Ghostty lets the editor keys reach Herdr and Neovim, and on a Mac, Option
# sends Alt and the Ctrl arrow keys leave Mission Control. With "terminal",
# Ghostty and macOS keep their own keys. The choice stays in KEYS_FILE, so
# that a later run keeps it. docs/keyboard-shortcuts.md lists each key.
KEYS_FILE="${HOME}/.config/herdspace/keys"
KEYS_FLAG=""

# keys_flag reads one key option. It returns 1 if the option is something else.
keys_flag() {
  case "$1" in
    --keep-terminal-keys) KEYS_FLAG="terminal" ;;
    --use-herdspace-keys) KEYS_FLAG="herdspace" ;;
    *) return 1 ;;
  esac
}

# load_keys sets KEYS from the option, then from KEYS_FILE, then the default.
load_keys() {
  KEYS="${KEYS_FLAG:-$(cat "$KEYS_FILE" 2>/dev/null || true)}"
  case "$KEYS" in
    herdspace | terminal) ;;
    *) KEYS="herdspace" ;;
  esac
  if [ "$MODE" != "check" ] && [ "$(cat "$KEYS_FILE" 2>/dev/null || true)" != "$KEYS" ]; then
    mkdir -p "$(dirname "$KEYS_FILE")"
    printf '%s\n' "$KEYS" >"$KEYS_FILE"
  fi
  info "Keys: ${KEYS}. See docs/keyboard-shortcuts.md."
}

# install_ghostty_config SRC installs the Ghostty configuration for KEYS.
install_ghostty_config() {
  local src="$1" tmp
  if [ "$KEYS" = "herdspace" ]; then
    install_file "$src" "${HOME}/.config/ghostty/config.ghostty"
    return 0
  fi
  tmp="$(mktemp)"
  sed '/^# herdspace keys: start/,/^# herdspace keys: end/d' "$src" >"$tmp"
  install_file "$tmp" "${HOME}/.config/ghostty/config.ghostty"
  rm -f "$tmp"
}
