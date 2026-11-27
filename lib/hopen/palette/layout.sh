# shellcheck shell=bash
# The Layout group of the command palette.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# pal_items_layout DIR adds the Layout actions for DIR and the place.
pal_items_layout() {
  local name
  if [ -n "$PAL_PANE" ]; then
    while read -r name; do
      [ "$name" = plain ] || pal_add "apply:${name}" Layout "Split the current tab with the template ${name}" "hopen --apply ${name}"
    done < <(show_templates | tail -n +2 | cut -d ' ' -f1)
    pal_add split-right Layout "Split right" "Ctrl+B V"
    pal_add split-down Layout "Split down" "Ctrl+B -"
    pal_add zoom Layout "Zoom the pane, or return" "Ctrl+B Z"
  fi
  pal_add templates Layout "Show every template" "hopen --templates"
}

# pal_run_layout ID DIR runs the action ID of the Layout group. For an ID of
# another group, it sets PAL_MISS=1.
pal_run_layout() {
  local choice="$1" dir="$2" self="$PAL_SELF"
  case "$choice" in
    apply:*) then_wait "$self" --apply "${choice#apply:}" ;;
    split-right) split_run right "$dir" ;;
    split-down) split_run down "$dir" ;;
    zoom) herdr pane zoom --pane "$PAL_PANE" --toggle >/dev/null ;;
    templates) then_wait "$self" --templates ;;
    *) PAL_MISS=1 ;;
  esac
}
