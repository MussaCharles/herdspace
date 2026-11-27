# shellcheck shell=bash
# Find and search the files of a project, also with the files that .gitignore names.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# SEARCH_IN holds the folders of --with-ignored. When it has folders, the file
# list and the search read only them, with the files that .gitignore names.
SEARCH_IN=()
# SKIP_DIRS are folders of dependencies and caches. The search with the
# ignored files never reads them.
SKIP_DIRS=(.git node_modules .venv venv __pycache__ .mypy_cache .pytest_cache .ruff_cache .tox .next .gradle Pods DerivedData target)
# add_search_dir FOLDER adds FOLDER to SEARCH_IN. A name that starts with "-"
# gets "./" in front, so that fd, find, and rg never read it as an option.
add_search_dir() {
  local d="${1%/}"
  case "$d" in -*) d="./$d" ;; esac
  SEARCH_IN+=("$d")
}

# fd_cmd prints the name of fd: fd, or fdfind on Debian.
fd_cmd() {
  if command -v fd >/dev/null 2>&1; then echo fd
  elif command -v fdfind >/dev/null 2>&1; then echo fdfind
  else return 1
  fi
}

# skip_args fills the array SKIP with an --exclude option for each folder of
# SKIP_DIRS, for fd. A loop, because bash 3.2 has no mapfile.
skip_args() { local d; SKIP=(); for d in "${SKIP_DIRS[@]}"; do SKIP+=(--exclude "$d"); done; }

# list_files prints the files of the current folder. With SEARCH_IN, it prints
# only the files of those folders, with the files that .gitignore names, but
# not the folders of SKIP_DIRS.
list_files() {
  local fd SKIP
  if [ "${#SEARCH_IN[@]}" -gt 0 ]; then
    fd="$(fd_cmd)" || { find "${SEARCH_IN[@]}" -type f ! -path '*/.git/*'; return; }
    skip_args
    "$fd" --type f --hidden --no-ignore-vcs "${SKIP[@]}" . "${SEARCH_IN[@]}"
    return
  fi
  if fd="$(fd_cmd)"; then "$fd" --type f --hidden --exclude .git
  else find . -type f ! -path '*/.git/*'
  fi
}

# list_folders prints the folders of the current folder, with the folders that
# .gitignore names, but not the folders of SKIP_DIRS.
list_folders() {
  local fd SKIP
  if fd="$(fd_cmd)"; then
    skip_args
    "$fd" --type d --hidden --no-ignore-vcs "${SKIP[@]}" | sed 's|/$||'
  else
    find . -mindepth 1 -type d ! -path '*/.git*' | sed 's|^\./||'
  fi
}

# search_text prints the lines of the files that hold GREP_TEXT, as
# "file:line:text". With SEARCH_IN, it searches only those folders, with the
# files that .gitignore names, but not the folders of SKIP_DIRS.
search_text() {
  local d globs=()
  if [ "${#SEARCH_IN[@]}" -gt 0 ]; then
    for d in "${SKIP_DIRS[@]}"; do globs+=(--glob "!${d}/"); done
    rg --line-number --no-heading --color=always --smart-case --fixed-strings --hidden --no-ignore-vcs "${globs[@]}" -- "$GREP_TEXT" "${SEARCH_IN[@]}"
  else
    rg --line-number --no-heading --color=always --smart-case --fixed-strings -- "$GREP_TEXT"
  fi
}

# find_file lets the person choose a file in the current folder with fzf, and
# opens it. It uses fd, or fdfind on Debian, or find.
find_file() {
  local file preview="cat {}"
  need fzf "hopen --find"
  [ -t 0 ] && [ -t 1 ] || die "hopen --find needs a terminal."
  command -v bat >/dev/null 2>&1 && preview="bat --color=always --style=numbers {}"
  file="$(cd "$DIR" && list_files | sed 's|^\./\([^-]\)|\1|' | dim_folders | ui_fzf "Find a file" --ansi --prompt 'Open file > ' --preview "$preview" --height 80% --reverse)" || true
  [ -n "$file" ] || exit 0
  cd "$DIR" && open_in_editor "$file"
}

# grep_files searches the files of the current folder with ripgrep, lets the
# person choose a result with fzf, and opens the file at that line.
grep_files() {
  local hit preview="sed -n '{2},+20p' {1}"
  need rg "hopen --grep"
  need fzf "hopen --grep"
  [ -t 0 ] && [ -t 1 ] || die "hopen --grep needs a terminal."
  command -v bat >/dev/null 2>&1 && preview="bat --color=always --style=numbers --highlight-line {2} {1}"
  if ! in_popup; then
    hit="$(cd "$DIR" && search_text |
      ui_fzf "Search" --ansi --delimiter : --prompt "Search ${GREP_TEXT} > " --preview "$preview" --preview-window '+{2}-5' --height 80% --reverse)" || true
    [ -n "$hit" ] || exit 0
    cd "$DIR" && open_in_editor "$(cut -d: -f1 <<<"$hit")" "$(cut -d: -f2 <<<"$hit")"
  fi
  # In a Herdr popup, the result opens like quick open, at its line.
  local out key
  PAL_PANE="${HERDR_ACTIVE_PANE_ID:-}"
  PAL_WS="${HERDR_ACTIVE_WORKSPACE_ID:-}"
  PAL_TAB="${HERDR_ACTIVE_TAB_ID:-}"
  out="$(cd "$DIR" && search_text |
    ui_fzf "Search" --ansi --delimiter : --prompt "Search ${GREP_TEXT} > " --header "Enter opens the result. Ctrl+V opens a new editor on the right, Ctrl+S below, Ctrl+T in a new tab." --expect ctrl-v,ctrl-s,ctrl-t --preview "$preview" --preview-window '+{2}-5' --height 100% --reverse)" || true
  key="$(sed -n 1p <<<"$out")"
  hit="$(sed -n 2p <<<"$out")"
  [ -n "$hit" ] || exit 0
  case "$key" in ctrl-v) PAL_PLACE=right ;; ctrl-s) PAL_PLACE=down ;; ctrl-t) PAL_PLACE=tab ;; *) PAL_PLACE="" ;; esac
  open_target "$(cd "$DIR" && pwd)/$(cut -d: -f1 <<<"$hit")" "$DIR" "$(cut -d: -f2 <<<"$hit")"
}
