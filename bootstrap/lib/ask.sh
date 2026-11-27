# shellcheck shell=bash
# The questions about a file that a person changed.
# bootstrap/lib/common.sh loads this file. It works with the bash 3.2 that macOS ships.

# own_lines SRC DEST prints the lines of DEST that SRC does not have: no empty
# lines, no comments, and no lines that the herdspace version takes care of.
own_lines() {
  awk 'NR == FNR { t = $0; gsub(/^[ \t]+|[ \t]+$/, "", t); have[t] = 1; next }
    { t = $0; gsub(/^[ \t]+|[ \t]+$/, "", t)
      if (t == "" || t ~ /^#/ || (t in have)) next
      if (t ~ /^export ZSH=|^source \$ZSH\/oh-my-zsh\.sh|^ZSH_THEME=|p10k-instant-prompt|\.p10k\.zsh/) next
      print }' "$1" "$2"
}

# show_diff SRC DEST shows a summary, the lines of the person, and the difference.
show_diff() {
  local src="$1" dest="$2" mine theirs own
  mine="$(diff "$dest" "$src" | grep -c '^<' || true)"
  theirs="$(diff "$dest" "$src" | grep -c '^>' || true)"
  printf '\n  %s only in your file, %s only in the herdspace version.\n' "$(ui_count line "$mine")" "$(ui_count line "$theirs")"
  own="$(own_lines "$src" "$dest")"
  if [ -n "$own" ]; then
    printf '  Your own lines that the herdspace version does not have:\n'
    printf '%s\n' "$own" | sed 's/^/    /'
  fi
  printf '\n'
  if have delta || have git; then
    printf '  The difference of %s opens in a pager. Press q to come back to the question.\n' "$(short_home "$dest")"
    sleep 1
  fi
  if have delta; then
    delta --paging=always "$dest" "$src" || true
  elif have git; then
    git --no-pager diff --no-index --color=always -- "$dest" "$src" | ${PAGER:-less -R} || true
  else
    diff -u "$dest" "$src" | ${PAGER:-cat} || true
  fi
}

# ui_key KEY TEXT [NOTE] prints one answer of a question.
ui_key() {
  printf '    %s%s%s  %-58s %s%s%s\n' "$C_BOLD$C_CYAN" "$1" "$C_RESET" "$2" "$C_DIM" "${3:-}" "$C_RESET"
}

# ask_all_files TOTAL asks one question for all the changed files of the run:
# review one at a time, keep all, or replace all. It sets ASK_ALL.
ask_all_files() {
  local total="$1" answer i=0 f
  printf '\n  %s%s differ from the herdspace version:%s\n' "$C_BOLD" "$(ui_count file "$total")" "$C_RESET"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    i=$((i + 1))
    printf '    %s. %s\n' "$i" "$(short_home "$f")"
  done <<<"$CHANGED_FILES"
  printf '\n'
  while true; do
    ui_key v "Review one file at a time, with its difference" "(Enter)"
    ui_key K "Keep all ${total} files"
    ui_key R "Replace all ${total} files with the herdspace version (backups first)"
    printf '\n  Your choice: '
    IFS= read -r answer || answer="K"
    case "$answer" in
      v | "") ASK_ALL="review"; return 0 ;;
      K) ASK_ALL="keep"; return 0 ;;
      R) ASK_ALL="replace"; return 0 ;;
    esac
    printf '\n'
  done
}

# decide_edit SRC DEST sets DECISION to keep or replace for a file that a person
# changed. With more than one changed file, it first asks about all of them.
# shellcheck disable=SC2034 # install_file in files.sh reads DECISION.
decide_edit() {
  local src="$1" dest="$2" answer total=0 index=0 f i=0
  case "$MODE" in
    replace) DECISION="replace"; return 0 ;;
    keep) DECISION="keep"; return 0 ;;
  esac
  if [ "$ASK_ALL" = "keep" ] || [ "$ASK_ALL" = "replace" ]; then
    DECISION="$ASK_ALL"
    return 0
  fi
  if [ ! -t 0 ]; then
    DECISION="keep"
    return 0
  fi
  scan_changed_files
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    i=$((i + 1))
    [ "$f" != "$dest" ] || index="$i"
  done <<<"$CHANGED_FILES"
  total="$i"
  [ "$index" -gt 0 ] || total=0
  if [ -z "$ASK_ALL" ] && [ "$total" -gt 1 ]; then
    ask_all_files "$total"
    if [ "$ASK_ALL" != "review" ]; then
      DECISION="$ASK_ALL"
      return 0
    fi
  fi
  while true; do
    if [ "$total" -gt 1 ]; then
      printf '\n  %s%sFile %s of %s: %s%s\n\n' "$C_BOLD" "$C_CYAN" "$index" "$total" "$(short_home "$dest")" "$C_RESET"
    else
      printf '\n  %s%s%s differs from the herdspace version.%s\n\n' "$C_BOLD" "$C_CYAN" "$(short_home "$dest")" "$C_RESET"
    fi
    ui_key k "Keep your file" "(Enter)"
    ui_key r "Replace it with the herdspace version (backup first)"
    ui_key d "Show the difference of this file" "(q comes back)"
    printf '\n  Your choice: '
    IFS= read -r answer || answer="k"
    case "$answer" in
      r | replace) DECISION="replace"; return 0 ;;
      d | diff) show_diff "$src" "$dest" ;;
      k | keep | "") DECISION="keep"; return 0 ;;
    esac
  done
}
