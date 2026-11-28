# shellcheck shell=bash
# The look of the popups, and the questions: fzf like a Herdr popup, a choice, a text, and a yes or no.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# choose PROMPT shows a menu of the lines on stdin, one "key<TAB>text" line for
# each item, and prints the key that the person chose. It uses fzf if it is
# installed, else a numbered menu that takes a number or a key. It prints
# nothing if the person cancels, and it exits 1 for an unknown answer.
# lib/hopen/ui.py has the questions.
choose() { hopen_py internal choose "$1"; }

# The colors of the Herdr theme of the setup: Dracula, with the herdspace
# colors of [theme.custom] in config/herdr/config.toml. lib/hopen/ui.py has the
# same values. Change both while the palette is in bash.
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
ask_text() { hopen_py internal ask-text "$1"; }

# pick_folders lets the person mark one or more folders of stdin, and prints
# them, one on each line. With no fzf, it asks for the numbers of the folders.
pick_folders() { hopen_py internal pick-folders; }

# confirm TEXT asks a yes or no question. The default is no.
confirm() { hopen_py internal confirm "$1"; }
