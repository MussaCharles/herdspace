# shellcheck shell=bash
# The Projects group of the command palette.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# session_command prints the command that attaches to the current session.
session_command() {
  case "${HERDR_SESSION:-default}" in
    default | "") printf 'herdr' ;;
    *) printf 'herdr --session %s' "$HERDR_SESSION" ;;
  esac
}

# pal_items_projects DIR adds the Projects actions for DIR and the place.
pal_items_projects() {
  local name file
  if [ -n "$PAL_PANE" ]; then
    pal_add here Projects "Open this folder as its own workspace" "herdr workspace create"
    pal_add window Projects "Open this session in a new window" "$(session_command)"
  else
    pal_add folder Projects "Open this folder in Herdr" "hopen ."
    while IFS=$'\t' read -r name file; do
      pal_add "open:${name}" Projects "Open the list ${name}" "hopen ${name}"
    done < <(find_lists 2>/dev/null)
  fi
  pal_add all Projects "Open every list in the background" "hopen --all"
  pal_add lists Projects "Show every list and its state" "hopen --list"
  pal_add convert Projects "Write a herdspace.toml from a VS Code list" "hopen --convert"
}

# pal_run_projects ID DIR runs the action ID of the Projects group. For an ID of
# another group, it sets PAL_MISS=1.
pal_run_projects() {
  local choice="$1" dir="$2" self="$PAL_SELF" name
  case "$choice" in
    here) herdr workspace create --cwd "$dir" --label "$(basename "$dir")" --focus >/dev/null ;;
    window)
      then_wait printf '  Open a new terminal window, connect to this machine, and run:\n\n    %s\n\n  Each window keeps its own workspace and tab. Keep the two windows on\n  different tabs while an agent runs: https://github.com/herdrdev/herdr/issues/5749\n' "$(session_command)"
      ;;
    folder) exec "$self" . ;;
    open:*) exec "$self" "${choice#open:}" ;;
    all) then_wait "$self" --all --no-attach ;;
    lists) then_wait "$self" --list ;;
    convert)
      name="$(ask_text 'The name of the VS Code list')"
      [ -z "$name" ] || then_wait "$self" --convert "$name"
      ;;
    *) PAL_MISS=1 ;;
  esac
}
