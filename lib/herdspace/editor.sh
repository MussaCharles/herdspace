# shellcheck shell=bash
# herdspace editor, the defaults of the herdspace Neovim.
# bin/herdspace loads this file. It defines functions and variables, and runs nothing.

# cmd_editor [reader|normal] shows or changes the defaults of the herdspace
# Neovim. reader, the default, hides the warnings and the spell marks, because
# the agents write the code and the person reads it. normal keeps the defaults
# of LazyVim. Neovim reads the choice in ~/.config/herdspace/editor when it starts.
cmd_editor() {
  local want="${1:-}" file="${HOME}/.config/herdspace/editor" now
  now="$(cat "$file" 2>/dev/null || echo reader)"
  [ "$now" = normal ] || now=reader
  case "$want" in
    "")
      if [ "$now" = normal ]; then
        printf '  The editor: normal. Neovim shows the warnings and the spell marks, as LazyVim does.\n'
        printf '  To hide them, run: herdspace editor reader\n'
      else
        printf '  The editor: reader. Neovim hides the warnings and the spell marks, because you read the files.\n'
        printf '  To show them, as LazyVim does, run: herdspace editor normal\n'
      fi
      return 0
      ;;
    reader | normal) ;;
    *) printf "herdspace: '%s' is not an editor mode. Use 'reader' or 'normal'.\n" "$want" >&2; exit 2 ;;
  esac
  if [ "$want" = "$now" ]; then
    printf '  The editor is already in the %s mode. Nothing to change.\n' "$want"
    return 0
  fi
  if ! { mkdir -p "$(dirname "$file")" && printf '%s\n' "$want" >"$file"; }; then
    die "Could not write ${file}."
  fi
  printf '  The editor: %s. Neovim uses it the next time it starts.\n' "$want"
}
