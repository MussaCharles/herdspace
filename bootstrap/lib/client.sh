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
# The look of Ghostty: "herdspace" (the default) or "terminal". The choice
# stays in LOOK_FILE.
LOOK_FILE="${HOME}/.config/herdspace/look"
LOOK_FLAG=""
GHOSTTY_FILE="${HOME}/.config/ghostty/config.ghostty"
# 1 when this run changed the Ghostty file. common.sh reads it for the next steps.
export GHOSTTY_CHANGED=0

# keys_flag reads one key or look option. It returns 1 if the option is something else.
keys_flag() {
  case "$1" in
    --keep-terminal-keys) KEYS_FLAG="terminal" ;;
    --use-herdspace-keys) KEYS_FLAG="herdspace" ;;
    --keep-terminal-look) LOOK_FLAG="terminal" ;;
    --use-herdspace-look) LOOK_FLAG="herdspace" ;;
    *) return 1 ;;
  esac
}

# keys_tradeoff prints what the herdspace keys change in Ghostty.
keys_tradeoff() {
  if [ "$(uname -s)" = "Darwin" ]; then
    printf '  With the herdspace keys, Cmd+T, Cmd+W, Cmd+K, and Cmd+Shift+P reach Herdr.\n'
    printf '  Outside Herdr, these keys do nothing. Ghostty gets replacement keys:\n'
    printf '    Cmd+Option+T  a new tab           Cmd+Option+W  close the tab\n'
    printf '    Cmd+Option+K  clear the screen    Cmd+Option+Shift+P  the command palette\n'
    printf '  Option sends Alt, so it does not type characters such as é.\n'
    printf '  The Ctrl arrow keys leave Mission Control and move between Herdr tabs.\n'
  else
    printf '  With the herdspace keys, Ctrl+Shift+T, W, F, E, and P reach Herdr and Neovim.\n'
    printf '  Outside Herdr, these keys do nothing. Ghostty gets the same keys with Alt,\n'
    printf '  for example Ctrl+Alt+Shift+T for a new tab.\n'
  fi
}

# ask_keys asks once which keys to use, before the setup changes any key.
ask_keys() {
  local answer
  printf '\n  %s%sThe keys of Ghostty%s\n\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
  keys_tradeoff
  printf '\n'
  while true; do
    ui_key y "Use the herdspace keys" "(Enter)"
    ui_key n "Keep the keys of the terminal"
    printf '\n  Your choice: '
    IFS= read -r answer || answer=""
    case "$answer" in
      y | Y | "") KEYS="herdspace"; return 0 ;;
      n | N) KEYS="terminal"; return 0 ;;
    esac
  done
}

# load_keys sets KEYS and LOOK from the option, then from the saved choice. With
# no saved choice of keys, it asks at a terminal, and it explains the keys.
load_keys() {
  KEYS="${KEYS_FLAG:-$(cat "$KEYS_FILE" 2>/dev/null || true)}"
  case "$KEYS" in
    herdspace | terminal) ;;
    *)
      if [ "$MODE" = "ask" ] && [ -t 0 ]; then
        ask_keys
      else
        KEYS="herdspace"
        [ "$MODE" = "check" ] || keys_tradeoff
      fi
      ;;
  esac
  LOOK="${LOOK_FLAG:-$(cat "$LOOK_FILE" 2>/dev/null || true)}"
  case "$LOOK" in herdspace | terminal) ;; *) LOOK="herdspace" ;; esac
  if [ "$MODE" != "check" ]; then
    mkdir -p "$(dirname "$KEYS_FILE")"
    [ "$(cat "$KEYS_FILE" 2>/dev/null || true)" = "$KEYS" ] || printf '%s\n' "$KEYS" >"$KEYS_FILE"
    [ "$(cat "$LOOK_FILE" 2>/dev/null || true)" = "$LOOK" ] || printf '%s\n' "$LOOK" >"$LOOK_FILE"
  fi
  info "Keys: ${KEYS}. Look: ${LOOK}. See ${HS_DOC_BASE}/docs/keyboard-shortcuts.md"
}

# ghostty_section SRC NAME prints the lines of one section of SRC.
ghostty_section() {
  awk -v start="# herdspace $2: start" -v stop="# herdspace $2: end" '
    index($0, start) == 1 { on = 1; next }
    index($0, stop) == 1 { on = 0 }
    on { print }' "$1"
}

# old_herdspace_ghostty FILE exits 0 if FILE is the Ghostty file of an older
# herdspace, which owned the whole file.
old_herdspace_ghostty() {
  head -n 1 "$1" 2>/dev/null | grep -Eqx '# Ghostty configuration (for a Linux client, )?from herd(space|r-bootstrap)\.'
}

# ghostty_template SRC OWN prints a new Ghostty file: the blocks for KEYS and
# LOOK, then OWN, the lines of the person.
ghostty_template() {
  local src="$1" own="$2"
  printf '# Ghostty configuration. herdspace changes only its marked blocks, and it\n'
  printf '# never replaces this file. Ghostty uses the last value of each setting, so\n'
  printf '# a line of yours below the blocks wins.\n'
  if [ "$LOOK" = "herdspace" ]; then
    printf '# >>> herdspace appearance >>>\n%s\n# <<< herdspace appearance <<<\n' "$(ghostty_section "$src" appearance)"
  fi
  if [ "$KEYS" = "herdspace" ]; then
    printf '# >>> herdspace keys >>>\n%s\n# <<< herdspace keys <<<\n' "$(ghostty_section "$src" keys)"
  fi
  printf '# >>> herdspace ssh >>>\n%s\n# <<< herdspace ssh <<<\n' "$(ghostty_section "$src" ssh)"
  printf '\n# Put your own lines below.\n'
  [ -z "$own" ] || printf '%s\n' "$own"
}

# remove_block FILE NAME removes a marked block from FILE.
remove_block() {
  local file="$1" begin="# >>> $2 >>>" end="# <<< $2 <<<" tmp
  [ -f "$file" ] && grep -qxF -- "$begin" "$file" || return 0
  if [ "$MODE" = "check" ]; then
    note_todo "${file} has a $2 block to remove"
    return 0
  fi
  tmp="$(mktemp)"
  awk -v begin="$begin" -v end="$end" '$0 == begin { skip = 1; next } skip && $0 == end { skip = 0; next } !skip { print }' "$file" >"$tmp"
  cat "$tmp" >"$file"
  rm -f "$tmp"
  CHANGED=$((CHANGED + 1))
}

# install_ghostty_config SRC writes the herdspace blocks into the Ghostty file
# for KEYS and LOOK. It never replaces a file of the person. The file of an
# older herdspace gets the new layout after a backup, with the own lines.
install_ghostty_config() {
  local src="$1" file="$GHOSTTY_FILE" own="" tmp
  if [ ! -e "$file" ] || old_herdspace_ghostty "$file"; then
    if [ "$MODE" = "check" ]; then
      note_todo "${file} needs the new layout with marked blocks"
      return 0
    fi
    if [ -e "$file" ] && [ "$(manifest_get "$file")" != "$(file_sha "$file")" ]; then
      # Lines that herdspace never wrote. An old unbind line was from herdspace.
      own="$(own_lines "$src" "$file" | grep -v -E '^keybind = [^=]+=unbind$' || true)"
    fi
    tmp="$(mktemp)"
    ghostty_template "$src" "$own" >"$tmp"
    if [ -e "$file" ]; then
      write_file "$tmp" "$file" 644
      info "Your Ghostty file now keeps its own lines. herdspace changes only its marked blocks."
    else
      write_file "$tmp" "$file" 644
    fi
    rm -f "$tmp"
    GHOSTTY_CHANGED=1
    return 0
  fi
  local before
  before="$(file_sha "$file")"
  # Each block goes at the top, so the ssh block, added first, ends up last.
  ensure_block "$file" "herdspace ssh" "$(ghostty_section "$src" ssh)" top
  if [ "$KEYS" = "herdspace" ]; then
    ensure_block "$file" "herdspace keys" "$(ghostty_section "$src" keys)" top
  else
    remove_block "$file" "herdspace keys"
  fi
  if [ "$LOOK" = "herdspace" ]; then
    ensure_block "$file" "herdspace appearance" "$(ghostty_section "$src" appearance)" top
  else
    remove_block "$file" "herdspace appearance"
  fi
  [ "$before" = "$(file_sha "$file")" ] || GHOSTTY_CHANGED=1
}
