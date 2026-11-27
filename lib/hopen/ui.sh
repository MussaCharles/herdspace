# shellcheck shell=bash
# The look of the popups, and the questions: fzf like a Herdr popup, a choice, a text, and a yes or no.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# choose PROMPT shows a menu of the lines on stdin, one "key<TAB>text" line for
# each item, and prints the key that the person chose. It uses fzf if it is
# installed, else a numbered menu that takes a number or a key. It prints
# nothing if the person cancels, and it exits 1 for an unknown answer.
choose() {
  local prompt="$1" items answer="" name text i=0
  items="$(cat)"
  # fzf draws nothing with no TERM, or with TERM=dumb.
  if command -v fzf >/dev/null 2>&1 && [ -n "${TERM:-}" ] && [ "${TERM}" != dumb ]; then
    ui_fzf "$prompt" --delimiter '\t' --with-nth 2.. --prompt "${prompt} > " --header 'Esc cancels.' --height 40% --reverse --no-multi <<<"$items" | cut -f1 || true
    return 0
  fi
  while IFS=$'\t' read -r name text; do
    i=$((i + 1))
    printf '  %2d) %s\n' "$i" "$text" >&2
  done <<<"$items"
  printf '  %s? Type a number or a name: ' "$prompt" >&2
  # The items came on stdin, so the answer comes from the terminal.
  IFS= read -r answer </dev/tty || answer=""
  case "$answer" in
    "") return 0 ;;
    *[!0-9]*) name="$(awk -F '\t' -v n="$answer" '$1 == n {print $1; exit}' <<<"$items")" ;;
    *) name="$(awk -F '\t' -v n="$answer" 'NR == n {print $1; exit}' <<<"$items")" ;;
  esac
  [ -n "$name" ] || { printf '  [err]  No item %s.\n' "$answer" >&2; return 1; }
  printf '%s\n' "$name"
}

# The colors of the Herdr theme of the setup: Dracula, with the herdspace
# colors of [theme.custom] in config/herdr/config.toml. Change them here only.
UI_BG="#282a36"
UI_ROW="#45475a"
UI_FG="#f8f8f2"
UI_DIM="#6272a4"
UI_ACCENT="#bd93f9"
UI_MATCH="#ff79c6"
UI_MARK="#50fa7b"

# ui_color prints yes when the popups can use color: not with NO_COLOR.
ui_color() { [ -z "${NO_COLOR:-}" ]; }

# sgr HEX prints the terminal code for the text color HEX, for example #ff79c6.
sgr() {
  local h="${1#\#}"
  printf '\033[38;2;%d;%d;%dm' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

# group_color GROUP prints the color of a group of the palette, so that each
# group is easy to find.
group_color() {
  case "$1" in
    Projects) echo "#50fa7b" ;;
    "Workspace and tabs") echo "#8be9fd" ;;
    Layout) echo "#f1fa8c" ;;
    Agents) echo "#ff79c6" ;;
    Files) echo "#ffb86c" ;;
    Git) echo "#ff5555" ;;
    Sessions) echo "#bd93f9" ;;
    Herdr) echo "#4e82ef" ;;
    herdspace) echo "#a78bfa" ;;
    Network) echo "#a4ffff" ;;
    *) echo "$UI_FG" ;;
  esac
}

# ui_fzf LABEL ARGS... runs fzf like a Herdr popup: the colors of the theme,
# and a rounded frame with LABEL at the top. With NO_COLOR, fzf has no color.
ui_fzf() {
  local label="$1"
  shift
  if ui_color; then
    fzf --border rounded --border-label " ${label} " --padding 0,1 \
      --color "bg:${UI_BG},bg+:${UI_ROW},fg:${UI_FG},fg+:${UI_FG},hl:${UI_MATCH},hl+:${UI_MATCH},prompt:${UI_ACCENT},pointer:${UI_MATCH},marker:${UI_MARK},header:${UI_DIM},info:${UI_DIM},border:${UI_DIM},label:${UI_ACCENT},spinner:${UI_ACCENT},gutter:${UI_BG},preview-bg:${UI_BG},preview-border:${UI_DIM}" \
      "$@"
  else
    fzf --no-color --border rounded --border-label " ${label} " --padding 0,1 "$@"
  fi
}

# dim_folders shows the folder of each path of stdin dim and the file name
# bright, as VS Code does. With NO_COLOR, it changes nothing.
dim_folders() {
  if ui_color; then
    sed -E "s|^(.*/)([^/]*)\$|$(sgr "$UI_DIM")\\1$(printf '\033[0m')\\2|"
  else
    cat
  fi
}

# then_wait runs a command that prints a result. In a popup, it waits for
# Enter, so that the person can read the result.
then_wait() {
  "$@" || true
  if in_popup; then
    printf '\n  Press Enter to close.'
    IFS= read -r _ || true
  fi
}

# ask_text PROMPT reads one line from the terminal.
ask_text() {
  local text=""
  printf '  %s: ' "$1" >&2
  IFS= read -r text </dev/tty || text=""
  printf '%s' "$text"
}

# pick_folders lets the person mark one or more folders of stdin, and prints
# them, one on each line. With no fzf, it asks for the numbers of the folders.
pick_folders() {
  local items answer n
  items="$(cat)"
  if command -v fzf >/dev/null 2>&1 && [ -n "${TERM:-}" ] && [ "${TERM}" != dumb ]; then
    ui_fzf "Folders with the ignored files" --multi --prompt 'Folders > ' --header 'Tab marks a folder. Enter searches the marked folders, with the ignored files. Esc cancels.' --height 60% --reverse <<<"$items" || true
    return 0
  fi
  awk '{ printf "  %2d) %s\n", NR, $0 }' <<<"$items" >&2
  printf '  Folders? Type the numbers, with a space between them: ' >&2
  IFS= read -r answer </dev/tty || answer=""
  for n in $answer; do
    case "$n" in *[!0-9]*) printf '  [err]  No folder %s.\n' "$n" >&2; return 1 ;; esac
    awk -v n="$n" 'NR == n' <<<"$items"
  done
}

# confirm TEXT asks a yes or no question. The default is no.
confirm() {
  local answer=""
  printf '  %s [y/N] ' "$1" >&2
  IFS= read -r answer </dev/tty || answer=""
  case "$answer" in y | Y | yes) return 0 ;; *) return 1 ;; esac
}
