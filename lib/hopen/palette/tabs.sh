# shellcheck shell=bash
# The Workspace and tabs group of the command palette.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# pal_items_tabs DIR adds the Workspace and tabs actions for DIR and the place.
pal_items_tabs() {
  if [ -n "$PAL_PANE" ]; then
    pal_add new-tab "Workspace and tabs" "New tab" "Cmd+T, Ctrl+B C"
    pal_add new-ws "Workspace and tabs" "New workspace in this folder" "Ctrl+B Shift+N"
    pal_add rename-ws "Workspace and tabs" "Rename the workspace" "Ctrl+B Shift+W"
    pal_add rename-tab "Workspace and tabs" "Rename the tab" "Ctrl+B Shift+T"
    pal_add rename-pane "Workspace and tabs" "Rename the pane" "Ctrl+B Shift+P"
    pal_add close-tab "Workspace and tabs" "Close the tab" "Cmd+W, Ctrl+B Shift+X"
  fi
}

# pal_run_tabs ID DIR runs the action ID of the Workspace and tabs group. For an
# ID of another group, it sets PAL_MISS=1.
pal_run_tabs() {
  local choice="$1" dir="$2" name
  case "$choice" in
    new-tab) herdr tab create --workspace "$PAL_WS" --cwd "$dir" --focus >/dev/null ;;
    new-ws) herdr workspace create --cwd "$dir" --focus >/dev/null ;;
    rename-ws | rename-tab | rename-pane)
      name="$(ask_text 'The new name')"
      [ -n "$name" ] || exit 0
      case "$choice" in
        rename-ws) herdr workspace rename "$PAL_WS" "$name" >/dev/null ;;
        rename-tab) herdr tab rename "$PAL_TAB" "$name" >/dev/null ;;
        rename-pane) herdr pane rename "$PAL_PANE" "$name" >/dev/null ;;
      esac
      ;;
    close-tab) confirm "Close this tab and end the programs in it?" && herdr tab close "$PAL_TAB" >/dev/null ;;
    *) PAL_MISS=1 ;;
  esac
}
