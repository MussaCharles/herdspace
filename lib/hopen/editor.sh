# shellcheck shell=bash
# The editor: open a file in it, and the command that starts the herdspace Neovim.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# open_in_editor FILE [LINE] opens FILE in $VISUAL or $EDITOR, or else Neovim.
open_in_editor() {
  local editor="${VISUAL:-${EDITOR:-nvim}}"
  # A name that starts with "-" gets "./" in front, so that the editor never
  # reads it as an option.
  case "$1" in -*) set -- "./$1" "${2:-}" ;; esac
  case "$(basename "${editor%% *}")" in
    code | code-insiders | cursor) exec ${editor} --goto "$1${2:+:$2}" ;;
    *) if [ -n "${2:-}" ]; then exec ${editor} "+$2" "$1"; else exec ${editor} "$1"; fi ;;
  esac
}

# editor_command prints the editor to start, with the herdspace Neovim when the
# person has no Neovim files of their own.
editor_command() {
  if [ -n "${EDITOR:-}" ] && [ "$EDITOR" != nvim ]; then
    printf '%s' "$EDITOR"
  elif [ -z "${NVIM_APPNAME:-}" ] && [ ! -d "$HOME/.config/nvim" ] && [ -d "$HOME/.config/herdspace-nvim" ]; then
    printf 'NVIM_APPNAME=herdspace-nvim nvim'
  else
    printf 'nvim'
  fi
}
