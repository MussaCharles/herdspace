# shellcheck shell=bash
# Quick open, like Ctrl+P in VS Code.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# quick_open lets the person choose a file of the project, as Cmd+P does in VS
# Code, and opens it with the focus on it. In Herdr, Enter opens the file in
# the focused pane when it runs Neovim or is a shell at its prompt, else in the
# Neovim pane of the tab, else in a new split on the right. Ctrl+V, Ctrl+S, and
# Ctrl+T open a new editor on the right, below, or in a new tab. A new editor
# runs with exec, so that its pane closes when Neovim quits.
quick_open() {
  local root out key file path pane preview="cat {}" header
  need fzf "hopen --quick-open"
  [ -t 0 ] && [ -t 1 ] || die "hopen --quick-open needs a terminal."
  root="$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$DIR")"
  command -v bat >/dev/null 2>&1 && preview="bat --color=always --style=numbers {}"
  PAL_PANE="${HERDR_ACTIVE_PANE_ID:-${HERDR_PANE_ID:-}}"
  PAL_WS="${HERDR_ACTIVE_WORKSPACE_ID:-${HERDR_WORKSPACE_ID:-}}"
  PAL_TAB="${HERDR_ACTIVE_TAB_ID:-${HERDR_TAB_ID:-}}"
  header="Type to filter. Enter opens the file. Esc closes. In Neovim, Ctrl+Q closes the file."
  [ -z "$PAL_PANE" ] || header="${header}"$'\n''Ctrl+V opens a new editor on the right, Ctrl+S below, Ctrl+T in a new tab.'
  out="$(cd "$root" && list_files | sed 's|^\./\([^-]\)|\1|' | dim_folders | ui_fzf "Quick open" --ansi --prompt 'Open file > ' --header "$header" --expect ctrl-v,ctrl-s,ctrl-t --preview "$preview" --height 100% --reverse)" || true
  key="$(sed -n 1p <<<"$out")"
  file="$(sed -n 2p <<<"$out")"
  [ -n "$file" ] || exit 0
  path="${root}/${file}"
  if [ -z "$PAL_PANE" ]; then
    cd "$root" && open_in_editor "$file"
  fi
  case "$key" in ctrl-v) PAL_PLACE=right ;; ctrl-s) PAL_PLACE=down ;; ctrl-t) PAL_PLACE=tab ;; *) PAL_PLACE="" ;; esac
  open_target "$path" "$root"
}
