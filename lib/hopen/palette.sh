# shellcheck shell=bash
# The command palette, like Ctrl+Shift+P in VS Code.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# The command palette lists each action as "Group: Action", with its key or
# command at the right, as in VS Code. It shows only the actions that fit the
# place: in Herdr or not, in a project with tasks, in a git folder, on a client,
# and with the tools that are installed. PALETTE_RECENT keeps the ids of the
# last actions, with no paths and no text that the person typed.
PALETTE_RECENT="${XDG_CACHE_HOME:-$HOME/.cache}/herdspace/palette-recent"
PALETTE_ITEMS=""

# pal_add ID GROUP TEXT [HINT] adds one action, as "ID<TAB>GROUP<TAB>line<TAB>
# colored line". The colored line has the group in its color and the hint dim.
pal_add() {
  local line color pad=""
  line="$(printf '%s: %s' "$2" "$3")"
  color="$(sgr "$(group_color "$2")")$2"$'\033[0m'": $3"
  if [ -n "${4:-}" ]; then
    [ "${#line}" -ge 58 ] || pad="$(printf '%*s' $((58 - ${#line})) '')"
    line="$(printf '%-58s %s' "$line" "$4")"
    color="${color}${pad} $(sgr "$UI_DIM")$4"$'\033[0m'
  fi
  PALETTE_ITEMS="${PALETTE_ITEMS}$1"$'\t'"$2"$'\t'"${line}"$'\t'"${color}"$'\n'
}

# PAL_GROUPS names the groups of the palette, in the order of the menu. Each
# group has a file in lib/hopen/palette/ with pal_items_GROUP and pal_run_GROUP.
PAL_GROUPS="projects tasks files git agents layout tabs sessions network herdspace herdr help"

# palette_items DIR fills PALETTE_ITEMS with the actions for DIR and the place.
palette_items() {
  local group
  PALETTE_ITEMS=""
  for group in $PAL_GROUPS; do
    "pal_items_${group}" "$1"
  done
}

# palette_menu prints the chosen id, a tab, and the chosen place: right, down,
# tab, or nothing for the default place of the action. In fzf, Ctrl+V, Ctrl+S,
# and Ctrl+T choose the place. In the numbered menu, a word after the name or
# the number does: "edit right", "3 down", "git tab". The recent actions come
# first. With no fzf, the numbered menu has a heading for each group.
palette_menu() {
  local items recent="" id head text i=0 last="" answer name out key place="" header field
  if [ -f "$PALETTE_RECENT" ]; then
    while IFS= read -r id; do
      [ -n "$id" ] || continue
      recent="${recent}$(awk -F '\t' -v id="$id" '$1 == id { print $1 "\tRecently used\t" $3 "\t" $4; exit }' <<<"$PALETTE_ITEMS")"$'\n'
    done <"$PALETTE_RECENT"
  fi
  items="$(printf '%s%s' "$(grep -v '^$' <<<"$recent")${recent:+$'\n'}" "$PALETTE_ITEMS" | grep -v '^$')"
  if command -v fzf >/dev/null 2>&1 && [ -n "${TERM:-}" ] && [ "${TERM}" != dumb ]; then
    header='Type to filter. Enter runs. Esc closes. At the right: the key or the command of each action.'
    [ -z "$PAL_PANE" ] || header="${header}"$'\n''This palette: Cmd+Shift+P, or Ctrl+B, then A. On Linux, Cmd keys are Ctrl+Shift (Cmd+P is Ctrl+B, then F).'
    [ -z "$PAL_PANE" ] || header="${header}"$'\n''A program opens: Ctrl+V on the right, Ctrl+S below, Ctrl+T in a new tab.'
    field=3
    ! ui_color || field=4
    out="$(ui_fzf "Command palette" --ansi --delimiter '\t' --with-nth "$field" --prompt '> ' --header "$header" --expect ctrl-v,ctrl-s,ctrl-t --height 100% --reverse --no-multi --tiebreak=index <<<"$items")" || true
    key="$(sed -n 1p <<<"$out")"
    id="$(sed -n 2p <<<"$out" | cut -f1)"
    [ -n "$id" ] || return 0
    case "$key" in ctrl-v) place=right ;; ctrl-s) place=down ;; ctrl-t) place=tab ;; esac
    printf '%s\t%s\n' "$id" "$place"
    return 0
  fi
  while IFS=$'\t' read -r id head text _; do
    i=$((i + 1))
    if [ "$head" != "$last" ]; then
      printf '\n  %s\n' "$head" >&2
      last="$head"
    fi
    printf '  %3d) %s\n' "$i" "$text" >&2
  done <<<"$items"
  [ -z "$PAL_PANE" ] || printf '\n  A word after the action opens a program in another place: right, down, or tab.' >&2
  printf '\n  Action? Type a number or a name: ' >&2
  IFS= read -r answer </dev/tty || answer=""
  case "$answer" in
    *" right" | *" down" | *" tab")
      place="${answer##* }"
      answer="${answer% *}"
      ;;
  esac
  case "$answer" in
    "") return 0 ;;
    *[!0-9]*) name="$(awk -F '\t' -v n="$answer" '$1 == n {print $1; exit}' <<<"$items")" ;;
    *) name="$(awk -F '\t' -v n="$answer" 'NR == n {print $1; exit}' <<<"$items")" ;;
  esac
  [ -n "$name" ] || { printf '  [err]  No action %s.\n' "$answer" >&2; return 1; }
  printf '%s\t%s\n' "$name" "$place"
}

# remember ID puts ID first in the recent list. Agent ids change, so they stay out.
remember() {
  case "$1" in agent:*) return 0 ;; esac
  mkdir -p "$(dirname "$PALETTE_RECENT")" 2>/dev/null || return 0
  {
    printf '%s\n' "$1"
    [ ! -f "$PALETTE_RECENT" ] || grep -vxF -- "$1" "$PALETTE_RECENT" | head -n 4 || true
  } >"${PALETTE_RECENT}.new" 2>/dev/null && mv "${PALETTE_RECENT}.new" "$PALETTE_RECENT"
}

# palette shows the actions that fit the current folder and place, and runs
# the one that the person chooses. With --print, it prints the actions only.
palette() {
  local dir="${HERDR_ACTIVE_PANE_CWD:-$PWD}" choice group status
  PAL_SELF="$0"
  PAL_PANE="${HERDR_ACTIVE_PANE_ID:-${HERDR_PANE_ID:-}}"
  PAL_WS="${HERDR_ACTIVE_WORKSPACE_ID:-${HERDR_WORKSPACE_ID:-}}"
  PAL_TAB="${HERDR_ACTIVE_TAB_ID:-${HERDR_TAB_ID:-}}"
  palette_items "$dir"
  if [ "${PALETTE_PRINT:-0}" -eq 1 ]; then
    awk -F '\t' '{ print $1 "\t" $3 }' <<<"$PALETTE_ITEMS" | grep -v '^$'
    return 0
  fi
  [ -t 0 ] && [ -t 1 ] || die "hopen --palette needs a terminal."
  choice="$(palette_menu)" || exit 1
  [ -n "$choice" ] || exit 0
  PAL_PLACE="${choice#*$'\t'}"
  choice="${choice%%$'\t'*}"
  [ -n "$choice" ] || exit 0
  remember "$choice"
  cd "$dir" || die "No folder ${dir}."
  # Each group runs its own actions. The first group that knows the id runs it.
  for group in $PAL_GROUPS; do
    PAL_MISS=0
    "pal_run_${group}" "$choice" "$dir"
    status=$?
    [ "$PAL_MISS" -eq 1 ] || return "$status"
  done
  return 0
}
