# shellcheck shell=bash
# The Network group of the command palette.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# pal_items_network DIR adds the Network actions for DIR and the place.
pal_items_network() {
  pal_add ports Network "Show the ports that your programs listen on" "hopen --ports"
}

# pal_run_network ID DIR runs the action ID of the Network group. For an ID of
# another group, it sets PAL_MISS=1.
pal_run_network() {
  local choice="$1" self="$PAL_SELF"
  case "$choice" in
    ports) then_wait "$self" --ports ;;
    *) PAL_MISS=1 ;;
  esac
}
