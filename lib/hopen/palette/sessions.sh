# shellcheck shell=bash
# The Sessions group of the command palette.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# pal_items_sessions DIR adds the Sessions actions for DIR and the place.
pal_items_sessions() {
  if command -v herdr >/dev/null 2>&1; then
    pal_add sessions Sessions "Show the sessions" "herdr session list"
    pal_add stop-session Sessions "Stop a session" "herdr session stop"
  fi
}

# pal_run_sessions ID DIR runs the action ID of the Sessions group. For an ID of
# another group, it sets PAL_MISS=1.
pal_run_sessions() {
  local choice="$1" pick text
  case "$choice" in
    sessions) then_wait herdr session list ;;
    stop-session)
      pick="$(herdr session list 2>/dev/null | awk 'NR > 1 && $2 == "running" { print $1 "\t" $1 }' | choose "Session")" || exit 1
      [ -n "$pick" ] || exit 0
      text="Stop the session ${pick}, and end every program in it?"
      [ "$pick" != "${HERDR_SESSION:-default}" ] || text="Stop the session ${pick}, the one that you use now, and end every program in it?"
      confirm "$text" || exit 0
      if [ "$pick" = default ]; then then_wait herdr server stop; else then_wait herdr session stop "$pick"; fi
      ;;
    *) PAL_MISS=1 ;;
  esac
}
