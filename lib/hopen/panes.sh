# shellcheck shell=bash
# The Herdr panes: wait for one, split, open a tab, find the editor of a tab, and open a file in it.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# in_popup exits 0 in a Herdr popup, which closes when its command ends.
in_popup() { [ -z "${HERDR_PANE_ID:-}" ] && [ -n "${HERDR_ACTIVE_PANE_ID:-}" ]; }

# pane_ready PANE waits until the shell of a new pane draws its prompt, for at
# most 15 seconds. Text that reaches a shell before it starts can get lost.
pane_ready() {
  local _
  for _ in $(seq 1 60); do
    [ -z "$(herdr pane read "$1" 2>/dev/null | tr -d '[:space:]')" ] || return 0
    sleep 0.25
  done
}

# new_tab_run LABEL DIR COMMAND opens a new tab in the current workspace and
# runs COMMAND in it.
new_tab_run() {
  local pane
  pane="$(herdr_json root_pane.pane_id tab create --workspace "$PAL_WS" --cwd "$2" --label "$1" --focus)"
  [ -n "$pane" ] || die "Herdr did not open a new tab."
  pane_ready "$pane"
  herdr pane run "$pane" "$3" >/dev/null
}

# split_run DIRECTION DIR [COMMAND] splits the current pane, and runs COMMAND
# in the new pane.
split_run() {
  local pane
  pane="$(herdr_json pane.pane_id pane split --pane "$PAL_PANE" --direction "$1" --cwd "$2" --focus)"
  [ -n "$pane" ] || die "Herdr did not split the pane."
  [ -z "${3:-}" ] || { pane_ready "$pane"; herdr pane run "$pane" "$3" >/dev/null; }
}

# focus_pane PANE moves the focus to PANE in its tab. Herdr moves the focus
# only from one pane to its neighbor, so this steps from the focused pane
# toward PANE through the layout, at most 8 times.
focus_pane() {
  local dir
  for _ in 1 2 3 4 5 6 7 8; do
    dir="$(herdr pane layout --pane "$1" 2>/dev/null | python3 -c '
import json, sys
target = sys.argv[1]
layout = json.load(sys.stdin).get("result", {}).get("layout", {})
rects = {p["pane_id"]: p["rect"] for p in layout.get("panes", [])}
here = layout.get("focused_pane_id")
if here == target or here not in rects or target not in rects:
    sys.exit(0)
def center(r):
    return (r["x"] + r["width"] / 2, r["y"] + r["height"] / 2)
(hx, hy), (tx, ty) = center(rects[here]), center(rects[target])
if abs(tx - hx) >= abs(ty - hy):
    print(("right" if tx > hx else "left") + " " + here)
else:
    print(("down" if ty > hy else "up") + " " + here)' "$1")"
    [ -n "$dir" ] || return 0
    herdr pane focus --pane "${dir#* }" --direction "${dir%% *}" >/dev/null 2>&1 || return 1
  done
}

# pane_runs PANE KIND is true when the foreground of PANE is Neovim or Vim
# (KIND editor), or only a shell at its prompt (KIND shell).
pane_runs() {
  herdr pane process-info --pane "$1" 2>/dev/null | python3 -c '
import json, sys
procs = json.load(sys.stdin).get("result", {}).get("process_info", {}).get("foreground_processes", [])
names = {p.get("name") for p in procs}
if sys.argv[1] == "editor":
    sys.exit(0 if names & {"nvim", "vim"} else 1)
sys.exit(0 if names and names <= {"zsh", "bash", "sh", "fish", "dash"} else 1)' "$2"
}

# editor_pane TAB prints the first pane of TAB that runs Neovim or Vim.
editor_pane() {
  local pane
  for pane in $(herdr pane list 2>/dev/null | python3 -c '
import json, sys
for p in json.load(sys.stdin).get("result", {}).get("panes", []):
    if p.get("tab_id") == sys.argv[1]:
        print(p["pane_id"])' "$1"); do
    if pane_runs "$pane" editor; then
      printf '%s\n' "$pane"
      return 0
    fi
  done
  return 1
}

# drop_in PANE PATH [LINE] opens PATH in the Neovim of PANE, at LINE, and
# focuses PANE.
drop_in() {
  local go="" line="${3:-}"
  # Only digits: the line comes from a search result, and a file name can
  # hold any text.
  [[ "$line" =~ ^[0-9]+$ ]] || line=""
  [ -z "$line" ] || go=" | call cursor(${line}, 1)"
  herdr pane send-keys "$1" esc >/dev/null
  herdr pane send-text "$1" ":execute 'drop' fnameescape('${2//\'/\'\'}')${go}" >/dev/null
  herdr pane send-keys "$1" enter >/dev/null
  focus_pane "$1" || true
}

# open_target PATH ROOT [LINE] opens a file for quick open and search, in this
# order: the Neovim of the focused pane, the focused shell at its prompt, the
# Neovim pane of the tab, or a new split on the right. PAL_PLACE (right, down,
# or tab) asks for a new editor in that place. A new editor runs with exec, so
# that its pane closes when Neovim quits.
open_target() {
  local path="$1" root="$2" line="${3:-}" pane plus=""
  # Only digits: the line comes from a search result, and a file name can
  # hold any text, also a colon.
  [[ "$line" =~ ^[0-9]+$ ]] || line=""
  [ -z "$line" ] || plus="+${line} "
  if [ -z "${PAL_PLACE:-}" ]; then
    if pane_runs "$PAL_PANE" editor; then
      drop_in "$PAL_PANE" "$path" "$line"
      exit 0
    fi
    if pane_runs "$PAL_PANE" shell; then
      herdr pane run "$PAL_PANE" "$(editor_command) ${plus}$(printf '%q' "$path")" >/dev/null
      exit 0
    fi
    if pane="$(editor_pane "$PAL_TAB")"; then
      drop_in "$pane" "$path" "$line"
      exit 0
    fi
  fi
  run_at right "$(basename "$path")" "$root" "exec env $(editor_command) ${plus}$(printf '%q' "$path")"
}

# run_at DEFAULT LABEL DIR [COMMAND] runs COMMAND in the place that the person
# chose in the palette (PAL_PLACE), or in DEFAULT: here, right, down, or tab.
# "here" replaces the palette with COMMAND. Outside Herdr, only "here" works.
run_at() {
  local place="${PAL_PLACE:-$1}"
  [ -n "$PAL_PANE" ] || place=here
  case "$place" in
    right | down) split_run "$place" "$3" "${4:-}" ;;
    tab)
      if [ -n "${4:-}" ]; then
        new_tab_run "$2" "$3" "$4"
      else
        herdr tab create --workspace "$PAL_WS" --cwd "$3" --label "$2" --focus >/dev/null
      fi
      ;;
    *)
      cd "$3" || die "No folder ${3}."
      if [ -n "${4:-}" ]; then eval "exec $4"; else exec "${SHELL:-sh}"; fi
      ;;
  esac
}
