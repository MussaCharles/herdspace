# shellcheck shell=bash
# The Files group of the command palette.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# pal_items_files DIR adds the Files actions for DIR and the place.
pal_items_files() {
  # In Herdr, quick open replaces this action.
  [ -n "$PAL_PANE" ] || ! command -v fzf >/dev/null 2>&1 || pal_add find Files "Find a file, and open it" "ff"
  [ -z "$PAL_PANE" ] || ! command -v fzf >/dev/null 2>&1 || pal_add quick Files "Quick open: a file in the editor of this tab" "Cmd+P, Ctrl+B F"
  command -v rg >/dev/null 2>&1 && pal_add grep Files "Search in the files, and open a result" "fif TEXT"
  command -v rg >/dev/null 2>&1 && pal_add ignored Files "Choose folders, and search them with the ignored files" "hopen --with-ignored"
  if command -v nvim >/dev/null 2>&1 || [ -n "${EDITOR:-}" ]; then
    pal_add edit Files "Open this folder in the editor" "nvim ."
    pal_add read-md Files "Read a Markdown file, rendered" "nvim -R FILE.md"
  fi
}

# pal_run_files ID DIR runs the action ID of the Files group. For an ID of
# another group, it sets PAL_MISS=1.
pal_run_files() {
  local choice="$1" dir="$2" self="$PAL_SELF" text pick name
  case "$choice" in
    find) run_at here find "$dir" "$(printf '%q --find' "$self")" ;;
    quick) DIR="$dir"; quick_open ;;
    ignored)
      # Only the chosen folders are read, so the search stays fast.
      dir="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$dir")"
      text="$(cd "$dir" && list_folders | sort)" || true
      [ -n "$text" ] || { then_wait printf '  No folder in %s.\n' "$dir"; exit 0; }
      pick="$(pick_folders <<<"$text")" || exit 1
      [ -n "$pick" ] || exit 0
      while IFS= read -r name; do [ -z "$name" ] || add_search_dir "$name"; done <<<"$pick"
      choice="$(printf 'open\tOpen a file of these folders\ntext\tSearch the text in these folders\n' | choose "Search")" || exit 1
      DIR="$dir"
      case "$choice" in
        open) quick_open ;;
        text)
          GREP_TEXT="$(ask_text 'Search for')"
          [ -n "$GREP_TEXT" ] || exit 0
          grep_files
          ;;
      esac
      ;;
    grep)
      text="$(ask_text 'Search for')"
      [ -n "$text" ] || exit 0
      run_at here search "$dir" "$(printf '%q --grep %q' "$self" "$text")"
      ;;
    edit) run_at tab edit "$dir" "$(editor_command) ." ;;
    read-md)
      text="$(list_files 2>/dev/null | sed 's|^\./\([^-]\)|\1|' | grep -iE '\.(md|markdown)$' | sort)" || true
      [ -n "$text" ] || { then_wait printf '  No Markdown file in %s.\n' "$dir"; exit 0; }
      pick="$(awk '{ print $0 "\t" $0 }' <<<"$text" | choose "Markdown file")" || exit 1
      [ -n "$pick" ] || exit 0
      run_at tab "$(basename "$pick")" "$dir" "$(editor_command) -R $(printf '%q' "$pick")"
      ;;
    *) PAL_MISS=1 ;;
  esac
}
