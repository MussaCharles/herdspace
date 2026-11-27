# shellcheck shell=bash
# The Help group of the command palette.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# keys_help prints the keys that a person uses most.
keys_help() {
  cat <<'KEYS'
  Herdr (Mac / Linux)
    New tab, close tab           Cmd+T, Cmd+W      / Ctrl+Shift+T, Ctrl+Shift+W
    Go to anything               Cmd+K             / Ctrl+Shift+K
    Command palette              Cmd+Shift+P       / Ctrl+Shift+P
    lazygit over the pane        Cmd+Shift+G       / Ctrl+Shift+G
    Previous or next tab         Ctrl+Left, Ctrl+Right
    Previous or next workspace   Ctrl+Up, Ctrl+Down
    Next or previous pane        Alt+Up, Alt+Down
    Split right, split down      Ctrl+B V, Ctrl+B -
    Zoom the pane                Ctrl+B Z
    Leave, keep everything       Ctrl+B Q
  Shell
    Find a file, search text     ff, fif TEXT
    Jump to a folder             z NAME, zi
  Ghostty (outside Herdr)
    New tab, clear the screen    Cmd+Option+T, Cmd+Option+K / Ctrl+Alt+Shift+T
KEYS
}

# pal_items_help DIR adds the Help actions for DIR and the place.
pal_items_help() {
  pal_add keys-help Help "Show the keys"
  pal_add docs Help "Show the links to the cheat sheet and the docs" "herdspace help"
}

# pal_run_help ID DIR runs the action ID of the Help group. For an ID of another
# group, it sets PAL_MISS=1.
pal_run_help() {
  local choice="$1"
  case "$choice" in
    keys-help) then_wait keys_help ;;
    docs) then_wait printf '  The cheat sheet:  https://github.com/MussaCharles/herdspace/blob/main/docs/cheat-sheet.md\n  The docs:         https://github.com/MussaCharles/herdspace/blob/main/docs/README.md\n' ;;
    *) PAL_MISS=1 ;;
  esac
}
