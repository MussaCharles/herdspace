# shellcheck shell=bash
# The Herdr group of the command palette.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# pal_items_herdr DIR adds the Herdr actions for DIR and the place.
pal_items_herdr() {
  if command -v herdr >/dev/null 2>&1; then
    [ ! -x "$HOME/.local/bin/herdr-update-check" ] || pal_add herdr-update Herdr "Check for a new Herdr version" "herdr-update-check --now"
    pal_add herdr-reload Herdr "Reload the Herdr configuration" "herdr server reload-config"
    pal_add herdr-status Herdr "Show the state of the Herdr server" "herdr status"
  fi
}

# pal_run_herdr ID DIR runs the action ID of the Herdr group. For an ID of
# another group, it sets PAL_MISS=1.
pal_run_herdr() {
  local choice="$1"
  case "$choice" in
    herdr-update) then_wait "$HOME/.local/bin/herdr-update-check" --now ;;
    herdr-reload) then_wait herdr server reload-config ;;
    herdr-status) then_wait herdr status ;;
    *) PAL_MISS=1 ;;
  esac
}
