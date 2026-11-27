# shellcheck shell=bash
# The output of the setup: colors, marks, lines, boxes, and progress.
# bootstrap/lib/common.sh loads this file. It works with the bash 3.2 that macOS ships.

# Colors, marks, and boxes only for a person at a terminal. With no terminal
# (a log, CI, or a coding agent), or with NO_COLOR set (https://no-color.org),
# the output is plain text, with the words [ok], [todo], [warn], and [err].
UI_COLOR=0
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ]; then UI_COLOR=1; fi
UI_UTF8=0
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in *[Uu][Tt][Ff]-8* | *[Uu][Tt][Ff]8*) UI_UTF8=1 ;; esac
C_RESET="" C_BOLD="" C_DIM="" C_RED="" C_GREEN="" C_YELLOW="" C_CYAN=""
if [ "$UI_COLOR" -eq 1 ]; then
  C_RESET=$'\033[0m' C_BOLD=$'\033[1m' C_DIM=$'\033[2m' C_RED=$'\033[31m'
  C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_CYAN=$'\033[36m'
fi
if [ "$UI_UTF8" -eq 1 ]; then
  M_OK="✓" M_BAD="✗" M_WARN="!" M_BULLET="▸" M_FULL="█" M_EMPTY="░"
  B_TL="┌" B_TR="┐" B_BL="└" B_BR="┘" B_H="─" B_V="│"
else
  M_OK="+" M_BAD="x" M_WARN="!" M_BULLET=">" M_FULL="#" M_EMPTY="."
  B_TL="+" B_TR="+" B_BL="+" B_BR="+" B_H="-" B_V="|"
fi
STEP_NUMBER=0

# ui_home TEXT prints TEXT, with ~ for the home folder at a terminal. The plain
# output keeps the full paths, because tests and the silent scan read them.
ui_home() {
  local text="$*"
  if [ "$UI_COLOR" -eq 1 ]; then printf '%s' "${text//${HOME}\//\~/}"; else printf '%s' "$text"; fi
}
info() {
  if [ "$UI_COLOR" -eq 1 ]; then printf '  %s\n' "$(ui_home "$*")"; else printf '  [info] %s\n' "$*"; fi
}
ok() {
  if [ "$UI_COLOR" -eq 1 ]; then printf '  %s%s%s %s\n' "$C_GREEN" "$M_OK" "$C_RESET" "$(ui_home "$*")"; else printf '  [ok]   %s\n' "$*"; fi
}
warn() {
  if [ "$UI_COLOR" -eq 1 ]; then printf '  %s%s %s%s\n' "$C_YELLOW" "$M_WARN" "$(ui_home "$*")" "$C_RESET" >&2; else printf '  [warn] %s\n' "$*" >&2; fi
}
die() {
  if [ "$UI_COLOR" -eq 1 ]; then printf '  %s%s %s%s\n' "$C_RED" "$M_BAD" "$(ui_home "$*")" "$C_RESET" >&2; else printf '  [err]  %s\n' "$*" >&2; fi
  exit 1
}
have() { command -v "$1" >/dev/null 2>&1; }

# ui_width prints the width of a box: the terminal, at most 64 columns.
ui_width() {
  local cols
  cols="$(tput cols 2>/dev/null || echo 80)"
  [ "$cols" -gt 8 ] 2>/dev/null || cols=80
  [ "$cols" -le 66 ] || cols=66
  echo $((cols - 2))
}

# ui_repeat TEXT COUNT prints TEXT COUNT times.
ui_repeat() {
  local i=0 out=""
  while [ "$i" -lt "$2" ]; do out="${out}$1"; i=$((i + 1)); done
  printf '%s' "$out"
}

# step NAME starts a section. At a terminal, it draws a box with the number of the step.
step() {
  if [ "$UI_COLOR" -ne 1 ]; then printf '\n== %s\n' "$*"; return 0; fi
  local title="$*" width inner
  if [ "$title" != "Result" ]; then
    STEP_NUMBER=$((STEP_NUMBER + 1))
    title="Step ${STEP_NUMBER}: ${title}"
  else
    title="Summary"
  fi
  width="$(ui_width)"
  inner=$((width - 2))
  [ "${#title}" -le $((inner - 4)) ] || title="${title:0:$((inner - 7))}..."
  printf '\n%s%s%s%s%s\n' "$C_CYAN" "$B_TL" "$(ui_repeat "$B_H" "$inner")" "$B_TR" "$C_RESET"
  printf '%s%s%s  %s%s%s%*s%s%s%s\n' "$C_CYAN" "$B_V" "$C_RESET" "$C_BOLD" "$title" "$C_RESET" $((inner - ${#title} - 2)) "" "$C_CYAN" "$B_V" "$C_RESET"
  printf '%s%s%s%s%s\n\n' "$C_CYAN" "$B_BL" "$(ui_repeat "$B_H" "$inner")" "$B_BR" "$C_RESET"
}

# ui_item NUMBER LABEL STATE prints one numbered item of a list, at a terminal.
# STATE is ok, missing, or optional.
ui_item() {
  local color="$C_GREEN" mark="$M_OK" word="ready"
  case "$3" in
    missing) color="$C_RED" mark="$M_BAD" word="missing (necessary)" ;;
    optional) color="$C_YELLOW" mark="$M_WARN" word="missing (optional)" ;;
  esac
  printf '  %2s. %-40s %s%s %s%s\n' "$1" "$2" "$color" "$mark" "$word" "$C_RESET"
}

# ui_indent shows the output of another tool, such as brew, indented and dim at
# a terminal, so that the lines of the setup stand out.
ui_indent() {
  if [ "$UI_COLOR" -eq 1 ]; then
    while IFS= read -r line; do printf '    %s%s %s%s\n' "$C_DIM" "$M_BULLET" "$line" "$C_RESET"; done
  else
    cat
  fi
}

# ui_count WORD COUNT prints "1 file" or "2 files".
ui_count() {
  if [ "$2" -eq 1 ]; then printf '%s %s' "$2" "$1"; else printf '%s %ss' "$2" "$1"; fi
}

# ui_time SECONDS prints m:ss.
ui_time() { printf '%d:%02d' $(($1 / 60)) $(($1 % 60)); }

# ui_wait PID LABEL TOTAL COUNT_FN shows the progress of a background job until
# it ends, and returns its exit status. At a terminal, it draws a bar with
# COUNT_FN of TOTAL. With no terminal, it prints a line every 30 seconds.
ui_wait() {
  local pid="$1" label="$2" total="$3" count_fn="$4" start="$SECONDS" done_n elapsed bar_w=20 fill last_line=0 status=0
  while kill -0 "$pid" 2>/dev/null; do
    done_n="$("$count_fn" 2>/dev/null || echo 0)"
    [ "$done_n" -le "$total" ] 2>/dev/null || done_n="$total"
    elapsed=$((SECONDS - start))
    if [ "$UI_COLOR" -eq 1 ]; then
      fill=$((total > 0 ? done_n * bar_w / total : 0))
      printf '\r  %-26s %s%s%s%s  %s of %s  %s ' "$label" "$C_GREEN" "$(ui_repeat "$M_FULL" "$fill")" "$C_DIM" "$(ui_repeat "$M_EMPTY" $((bar_w - fill)))$C_RESET" "$done_n" "$total" "$(ui_time "$elapsed")"
    elif [ $((elapsed - last_line)) -ge 30 ]; then
      last_line="$elapsed"
      info "${label}: ${done_n} of ${total}, $(ui_time "$elapsed")"
    fi
    sleep 1
  done
  wait "$pid" || status=$?
  [ "$UI_COLOR" -ne 1 ] || printf '\r%*s\r' 72 ""
  return "$status"
}

# short_home PATH prints PATH with ~ for the home folder.
short_home() {
  local home="$HOME"
  case "$1" in "$home"/*) printf '~%s' "${1#"$home"}" ;; *) printf '%s' "$1" ;; esac
}

note_todo() {
  TODO=$((TODO + 1))
  if [ "$UI_COLOR" -eq 1 ]; then printf '  %s%s%s %s\n' "$C_RED" "$M_BAD" "$C_RESET" "$(ui_home "$*")"; else printf '  [todo] %s\n' "$*"; fi
}
