# shellcheck shell=bash
# The herdspace group of the command palette.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# pal_items_herdspace DIR adds the herdspace actions for DIR and the place.
pal_items_herdspace() {
  local role=""
  if command -v herdspace >/dev/null 2>&1; then
    pal_add hs-version herdspace "Show the installed and the latest version" "herdspace --version"
    pal_add hs-update herdspace "Update herdspace" "herdspace update"
    role="$(sed -n 's/^role=//p' "${XDG_DATA_HOME:-$HOME/.local/share}/herdspace/last-setup" 2>/dev/null)"
    case "$role" in client | both) pal_add hs-keys herdspace "Show or change the Ghostty keys" "herdspace keys" ;; esac
    case "$role" in server | both) pal_add hs-editor herdspace "Show or change the editor mode: reader or normal" "herdspace editor" ;; esac
  fi
}

# pal_run_herdspace ID DIR runs the action ID of the herdspace group. For an ID
# of another group, it sets PAL_MISS=1.
pal_run_herdspace() {
  local choice="$1" pick
  case "$choice" in
    hs-version) then_wait herdspace --version ;;
    hs-update) if [ -n "$PAL_PANE" ]; then new_tab_run update "$HOME" "herdspace update"; else exec herdspace update; fi ;;
    hs-keys)
      herdspace keys
      pick="$(printf 'normal\tnormal: Cmd+T, Cmd+W, and Cmd+K stay with Ghostty\nherdr\therdr: Cmd+T, Cmd+W, and Cmd+K go to Herdr\n' | choose "Keys")" || exit 1
      [ -n "$pick" ] || exit 0
      if [ -n "$PAL_PANE" ]; then new_tab_run keys "$HOME" "herdspace keys ${pick}"; else exec herdspace keys "$pick"; fi
      ;;
    hs-editor)
      herdspace editor
      pick="$(printf 'reader\treader: no warnings and no spell marks\nnormal\tnormal: the defaults of LazyVim\n' | choose "Editor")" || exit 1
      [ -n "$pick" ] || exit 0
      then_wait herdspace editor "$pick"
      ;;
    *) PAL_MISS=1 ;;
  esac
}
