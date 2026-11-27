# shellcheck shell=bash
# The Tasks group of the command palette.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# pal_items_tasks DIR adds the Tasks actions for DIR and the place.
pal_items_tasks() {
  local dir="$1" match file label name text
  if match="$(project_for_dir "$dir")"; then
    file="${match%%$'\t'*}"
    label="${match#*$'\t'}"
    while IFS=$'\t' read -r name text; do
      [ -n "$name" ] && pal_add "task:${name}" Tasks "Run the task ${name}: ${text}" "hopen --task ${name}"
    done < <(read_list "$file" items 2>/dev/null | awk -F '\036' -v l="$label" '$1 == "K" && $2 == l { print $3 "\t" $4 }')
  fi
}

# pal_run_tasks ID DIR runs the action ID of the Tasks group. For an ID of
# another group, it sets PAL_MISS=1.
pal_run_tasks() {
  local choice="$1" dir="$2" self="$PAL_SELF"
  case "$choice" in
    task:*) run_at here task "$dir" "$(printf '%q --task %q' "$self" "${choice#task:}")" ;;
    *) PAL_MISS=1 ;;
  esac
}
