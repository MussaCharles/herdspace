#!/usr/bin/env bash
# Shared helpers. This file works with the bash 3.2 that macOS ships.

STAMP="$(date +%Y%m%d-%H%M%S)"
export STATE_DIR="${HOME}/.local/share/herdspace"
# The person already agreed to the setup, so brew does not ask again before an
# install. Homebrew 7 asks by default. An older Homebrew ignores the variable.
export HOMEBREW_NO_ASK=1
# The script and its options, for the silent --check that lists the changed files.
HS_SELF="$0"
HS_ARGS=("$@")
# The docs of the release that runs. bootstrap.sh sets it.
HS_DOC_BASE="${HS_DOC_BASE:-https://github.com/MussaCharles/herdspace/blob/main}"

# ---------- output
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

# What the script does with a file that a person changed:
#   ask      ask about each file. With no terminal, keep the file.
#   check    change nothing, and report.
#   keep     keep each changed file, and add only what is missing.
#   replace  use the file from this repository, and keep a backup.
MODE="ask"
CHANGED=0
TODO=0
EDITED=0
KEPT_LIST=""
BACKUP_LIST=""
ASK_ALL=""
# The rows of the summary table: label, result, and seconds, one line each.
SUMMARY=""
# The changed files of this run, from a silent --check, for "File 1 of 6".
CHANGED_FILES=""
CHANGED_FILES_READY=0
# Extras: answers for ~/.zshrc. EXTRAS=1 adds the block, MOVE_LINES=1 copies the lines.
EXTRAS=0
MOVE_LINES=0
ZSHRC_KEPT_NO_EXTRAS=0
# shellcheck disable=SC2034 # prereqs.sh reads ASSUME_YES.
ASSUME_YES=0
MANIFEST="${STATE_DIR}/manifest.tsv"

# apply_mode_flag sets MODE. It returns 1 if the option is something else.
# shellcheck disable=SC2034 # prereqs.sh reads ASSUME_YES.
apply_mode_flag() {
  case "$1" in
    --check) MODE="check" ;;
    --keep-existing) MODE="keep" ;;
    --replace-all) MODE="replace" ;;
    --yes) ASSUME_YES=1 ;;
    *) return 1 ;;
  esac
}

# print_usage prints the comment at the top of a script.
print_usage() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$1"
}

note_todo() {
  TODO=$((TODO + 1))
  if [ "$UI_COLOR" -eq 1 ]; then printf '  %s%s%s %s\n' "$C_RED" "$M_BAD" "$C_RESET" "$(ui_home "$*")"; else printf '  [todo] %s\n' "$*"; fi
}

file_sha() {
  if have sha256sum; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# The manifest records the hash of each file that a script installed. If a file
# still has that hash, no person changed it, so a new version can replace it.
manifest_get() {
  [ -f "$MANIFEST" ] || return 0
  awk -F '\t' -v d="$1" '$1 == d {print $2}' "$MANIFEST" | tail -n 1
}

manifest_set() {
  local tmp
  mkdir -p "$(dirname "$MANIFEST")"
  tmp="$(mktemp)"
  if [ -f "$MANIFEST" ]; then
    awk -F '\t' -v d="$1" '$1 != d' "$MANIFEST" >"$tmp"
  fi
  printf '%s\t%s\n' "$1" "$2" >>"$tmp"
  cat "$tmp" >"$MANIFEST"
  rm -f "$tmp"
}

# file_status prints missing, current, outdated, or edited.
file_status() {
  local src="$1" dest="$2" recorded
  if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    echo missing
  elif [ -f "$dest" ] && cmp -s "$src" "$dest"; then
    echo current
  else
    recorded="$(manifest_get "$dest")"
    if [ -f "$dest" ] && [ -n "$recorded" ] && [ "$recorded" = "$(file_sha "$dest")" ]; then
      echo outdated
    else
      echo edited
    fi
  fi
}

write_file() {
  local src="$1" dest="$2" mode="$3"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    cp -pP "$dest" "${dest}.bak-${STAMP}"
    info "Saved a backup: ${dest}.bak-${STAMP}"
    BACKUP_LIST="${BACKUP_LIST}${dest}
"
  fi
  rm -f "$dest"
  cp "$src" "$dest"
  chmod "$mode" "$dest"
  manifest_set "$dest" "$(file_sha "$dest")"
  CHANGED=$((CHANGED + 1))
}

# scan_changed_files fills CHANGED_FILES with the files that differ, from a
# silent --check of the same script, so that a question can say "File 1 of 6".
scan_changed_files() {
  [ "$CHANGED_FILES_READY" -eq 0 ] || return 0
  CHANGED_FILES_READY=1
  [ -z "${HS_SCAN:-}" ] || return 0
  CHANGED_FILES="$(HS_SCAN=1 NO_COLOR=1 bash "$HS_SELF" ${HS_ARGS[@]+"${HS_ARGS[@]}"} --check </dev/null 2>/dev/null |
    sed -n 's/^  \[diff\] \(.*\) differs from this repository$/\1/p' || true)"
}

# short_home PATH prints PATH with ~ for the home folder.
short_home() {
  local home="$HOME"
  case "$1" in "$home"/*) printf '~%s' "${1#"$home"}" ;; *) printf '%s' "$1" ;; esac
}

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

# decide_edit SRC DEST sets DECISION to keep or replace for a file that a person
# changed. For ~/.zshrc, it can also set EXTRAS or MOVE_LINES.
decide_edit() {
  local src="$1" dest="$2" answer total=0 index=0 after=0 rest="" f i=0 is_zshrc=0
  EXTRAS=0
  MOVE_LINES=0
  case "$MODE" in
    replace) DECISION="replace"; return 0 ;;
    keep) DECISION="keep"; return 0 ;;
  esac
  if [ -n "$ASK_ALL" ]; then
    DECISION="$ASK_ALL"
    return 0
  fi
  if [ ! -t 0 ]; then
    DECISION="keep"
    return 0
  fi
  [ "$dest" != "${HOME}/.zshrc" ] || is_zshrc=1
  scan_changed_files
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    i=$((i + 1))
    [ "$f" != "$dest" ] || index="$i"
    if [ "$index" -gt 0 ] && [ "$i" -gt "$index" ]; then rest="${rest}${f}
"; fi
  done <<<"$CHANGED_FILES"
  total="$i"
  [ "$index" -gt 0 ] || { total=0; rest=""; }
  [ -z "$rest" ] || after="$(printf '%s' "$rest" | grep -c .)"
  if [ "$index" -eq 1 ] && [ "$total" -gt 1 ]; then
    printf '\n  %s differ from the herdspace version:\n' "$(ui_count file "$total")"
    i=0
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      i=$((i + 1))
      printf '    %s. %s\n' "$i" "$(short_home "$f")"
    done <<<"$CHANGED_FILES"
  fi
  while true; do
    if [ "$total" -gt 0 ]; then
      printf '\n  %sFile %s of %s: %s%s differs from the herdspace version.\n\n' "$C_BOLD" "$index" "$total" "$(short_home "$dest")" "$C_RESET"
    else
      printf '\n  %s%s%s differs from the herdspace version.\n\n' "$C_BOLD" "$(short_home "$dest")" "$C_RESET"
    fi
    ui_key k "Keep your file" "(Enter)"
    ui_key r "Replace it with the herdspace version (backup first)"
    ui_key d "Show the difference"
    if [ "$is_zshrc" -eq 1 ]; then
      ui_key e "Keep your file, and add the herdspace shell extras"
      ui_key m "Replace it, and copy your own lines to ~/.zshrc.local"
    fi
    if [ "$after" -gt 0 ]; then
      ui_key K "Keep this file and the $(ui_count file "$after") after it"
      ui_key R "Replace this file and the $(ui_count file "$after") after it (backups first)"
    fi
    printf '\n  Your choice: '
    IFS= read -r answer || answer="k"
    case "$answer" in
      r | replace) DECISION="replace"; return 0 ;;
      d | diff) show_diff "$src" "$dest" ;;
      e) [ "$is_zshrc" -eq 1 ] || continue; DECISION="keep"; EXTRAS=1; return 0 ;;
      m) [ "$is_zshrc" -eq 1 ] || continue; DECISION="replace"; MOVE_LINES=1; return 0 ;;
      K) [ "$after" -gt 0 ] || continue; ASK_ALL="keep"; DECISION="keep"; return 0 ;;
      R)
        [ "$after" -gt 0 ] || continue
        printf '\n  These files also get the herdspace version, each with a backup:\n'
        printf '%s' "$rest" | while IFS= read -r f; do printf '    %s\n' "$(short_home "$f")"; done
        printf '  Replace these %s too? [y/N] (Enter = no) ' "$(ui_count file "$after")"
        IFS= read -r answer || answer=""
        case "$answer" in
          y | Y | yes | Yes) ASK_ALL="replace" ;;
          *) printf '  Only %s gets the herdspace version.\n' "$(short_home "$dest")" ;;
        esac
        DECISION="replace"
        return 0
        ;;
      k | keep | "") DECISION="keep"; return 0 ;;
    esac
  done
}

# extras_block DEST adds the marked block that loads the herdspace shell extras.
extras_block() {
  # shellcheck disable=SC2016 # The line is text for zsh.
  ensure_block "$1" "herdspace extras" '[[ -r "$HOME/.config/herdspace/extras.zsh" ]] && source "$HOME/.config/herdspace/extras.zsh"'
}

# move_own_lines SRC DEST copies the own lines of DEST to ~/.zshrc.local, each
# one behind "# ", so that nothing runs before the person reviews it.
move_own_lines() {
  local own local_file="${HOME}/.zshrc.local"
  own="$(own_lines "$1" "$2")"
  [ -n "$own" ] || return 0
  {
    printf '\n# Lines from your old %s, copied by the herdspace setup on %s.\n' "$(short_home "$2")" "$(date +%Y-%m-%d)"
    printf '# The full old file is %s.bak-%s.\n' "$(short_home "$2")" "$STAMP"
    printf '# Each line starts with "# ". Remove it from each line that you want, and keep\n'
    printf '# if/fi and other blocks complete.\n'
    printf '%s\n' "$own" | sed 's/^/# /'
  } >>"$local_file"
  info "Copied $(ui_count line "$(printf '%s\n' "$own" | grep -c .)") to $(short_home "$local_file"). Review them there."
}

# install_file makes DEST match SRC. A file that a script wrote and no person
# changed gets the new version. MODE decides for a file that a person changed.
install_file() {
  local src="$1" dest="$2" mode="${3:-644}" status sha
  status="$(file_status "$src" "$dest")"
  case "$status" in
    current)
      if [ "$MODE" != "check" ]; then
        sha="$(file_sha "$dest")"
        [ "$(manifest_get "$dest")" = "$sha" ] || manifest_set "$dest" "$sha"
      fi
      ;;
    missing | outdated)
      if [ "$MODE" = "check" ]; then
        note_todo "${dest} is ${status}"
      else
        write_file "$src" "$dest" "$mode"
      fi
      ;;
    edited)
      if [ "$MODE" = "check" ]; then
        EDITED=$((EDITED + 1))
        # The silent scan reads the plain line, so keep its words.
        if [ "$UI_COLOR" -eq 1 ]; then
          printf '  %s%s%s %s differs from the herdspace version\n' "$C_YELLOW" "$M_WARN" "$C_RESET" "$(short_home "$dest")"
        else
          printf '  [diff] %s differs from this repository\n' "$dest"
        fi
        return 0
      fi
      decide_edit "$src" "$dest"
      if [ "$DECISION" = "replace" ]; then
        [ "$MOVE_LINES" -ne 1 ] || move_own_lines "$src" "$dest"
        write_file "$src" "$dest" "$mode"
      else
        EDITED=$((EDITED + 1))
        KEPT_LIST="${KEPT_LIST}${dest}
"
        if [ "$dest" = "${HOME}/.zshrc" ]; then
          if [ "$EXTRAS" -eq 1 ]; then
            extras_block "$dest"
            ok "Added the herdspace shell extras to your ~/.zshrc."
          elif ! grep -q '>>> herdspace extras >>>' "$dest" 2>/dev/null; then
            ZSHRC_KEPT_NO_EXTRAS=1
          fi
        fi
      fi
      ;;
  esac
}

# install_tree copies every file below SRC_DIR to the same place below DEST_DIR.
# Files named in SEED_ONLY are copied only if they are missing, because a
# program changes them after the first start.
install_tree() {
  local src_dir="$1" dest_dir="$2" file
  while IFS= read -r file; do
    if [ -n "${SEED_ONLY:-}" ] && grep -Fxq -- "$file" <<<"$SEED_ONLY"; then
      seed_file "${src_dir}/${file}" "${dest_dir}/${file}"
    else
      install_file "${src_dir}/${file}" "${dest_dir}/${file}"
    fi
  done < <(cd "$src_dir" && find . -type f | sed 's|^\./||')
}

# seed_file copies SRC to DEST only if DEST is missing.
seed_file() {
  [ -e "$2" ] && return 0
  if [ "$MODE" = "check" ]; then
    note_todo "${2} is missing"
  else
    mkdir -p "$(dirname "$2")"
    cp "$1" "$2"
    CHANGED=$((CHANGED + 1))
  fi
}

# ensure_block puts TEXT between two marker lines in FILE. It replaces the old
# text between the markers and leaves the rest of the file as it is.
ensure_block() {
  local file="$1" name="$2" text="$3"
  local begin="# >>> ${name} >>>" end="# <<< ${name} <<<" tmp
  tmp="$(mktemp)"
  if [ -f "$file" ]; then
    awk -v begin="$begin" -v end="$end" '
      $0 == begin { skip = 1; next }
      $0 == end { skip = 0; next }
      !skip { print }
    ' "$file" >"$tmp"
  fi
  printf '%s\n%s\n%s\n' "$begin" "$text" "$end" >>"$tmp"
  if [ -f "$file" ] && cmp -s "$tmp" "$file"; then
    rm -f "$tmp"
    return 0
  fi
  if [ "$MODE" = "check" ]; then
    note_todo "${file} needs its ${name} block"
  else
    mkdir -p "$(dirname "$file")"
    cat "$tmp" >"$file"
    CHANGED=$((CHANGED + 1))
  fi
  rm -f "$tmp"
}

# run_part LABEL CHECK APPLY [ARG...] runs APPLY only if CHECK fails.
run_part() {
  local label="$1" check_fn="$2" apply_fn="$3" start
  shift 3
  if "$check_fn" "$@"; then
    ok "$label"
    SUMMARY="${SUMMARY}${label}|ready|0
"
    return 0
  fi
  if [ "$MODE" = "check" ]; then
    note_todo "$label"
    return 0
  fi
  step "$label"
  start="$SECONDS"
  "$apply_fn" "$@"
  CHANGED=$((CHANGED + 1))
  SUMMARY="${SUMMARY}${label}|done|$((SECONDS - start))
"
}

# summary_table prints the steps of the run in a table, at a terminal.
summary_table() {
  [ "$UI_COLOR" -eq 1 ] || return 0
  [ -n "$SUMMARY" ] || return 0
  local n=0 label result secs color mark
  printf '  %s%-4s %-34s %-10s %s%s\n' "$C_BOLD" "#" "Step" "Result" "Time" "$C_RESET"
  while IFS='|' read -r label result secs; do
    [ -n "$label" ] || continue
    n=$((n + 1))
    color="$C_GREEN" mark="$M_OK"
    case "$result" in missing) color="$C_RED" mark="$M_BAD" ;; esac
    printf '  %-4s %-34s %s%s %-8s%s %s\n' "$n" "${label:0:34}" "$color" "$mark" "$result" "$C_RESET" "$(ui_time "$secs")"
  done <<<"$SUMMARY"
  printf '\n'
}

# next_steps ROLE prints what to do after a run, with links to the docs of the release.
next_steps() {
  local server="${NEXT_SERVER:-<SSH name>}"
  # In a run of "both", the server part prints none. The client part follows.
  [ "$1" != "none" ] || return 0
  printf '\n  %sNext steps%s\n\n' "$C_BOLD" "$C_RESET"
  case "$1" in
    server)
      printf '    1. Set up your client machine, the machine that you type on:\n'
      printf '       %s/README.md#client-machine\n' "$HS_DOC_BASE"
      printf '       If this machine is also your client, run the setup with "both":\n'
      printf '       %s/README.md#one-machine-as-both\n' "$HS_DOC_BASE"
      printf '    2. From the client, connect with SSH, and open your projects:\n'
      printf '       hopen .          the current folder\n'
      printf '       hopen <list>     the projects of a list: %s/docs/hopen.md\n' "$HS_DOC_BASE"
      printf '    3. To check this machine later, run the setup with --check.\n'
      ;;
    client)
      printf '    1. Open a new Ghostty window, so that the new keys and colors load.\n'
      printf '    2. Connect to your server:\n'
      printf '       ssh %s\n' "$server"
      printf '       If the server has no herdspace yet: %s/README.md#server-machine\n' "$HS_DOC_BASE"
      printf '    3. On the server, open your projects:\n'
      printf '       hopen .          the current folder\n'
      printf '       hopen <list>     the projects of a list\n'
      printf '    4. Learn the keys: %s/docs/keyboard-shortcuts.md\n' "$HS_DOC_BASE"
      printf '    If a Ctrl arrow key does not work on macOS, log out and log in again.\n'
      ;;
    both)
      printf '    1. Open a new Ghostty window, so that the new keys and colors load.\n'
      printf '    2. Open your projects:\n'
      printf '       hopen .          the current folder\n'
      printf '       hopen <list>     the projects of a list: %s/docs/hopen.md\n' "$HS_DOC_BASE"
      printf '    3. Learn the keys: %s/docs/keyboard-shortcuts.md\n' "$HS_DOC_BASE"
      ;;
  esac
}

# finish_run ROLE prints the result: the summary, the kept files, the backups,
# and the next steps for ROLE (server, client, or both).
finish_run() {
  local role="$1" f
  step "Result"
  if [ "$MODE" = "check" ]; then
    if [ "$TODO" -gt 0 ]; then
      info "$(ui_count item "$TODO") need work. Run the script with no --check to do them."
      exit 1
    fi
    if [ "$EDITED" -gt 0 ]; then
      ok "Nothing is missing. $(ui_count file "$EDITED") differ from this repository."
    else
      ok "Everything is already set up."
    fi
    exit 0
  fi
  summary_table
  if [ -n "$KEPT_LIST" ]; then
    info "Kept $(ui_count file "$EDITED") that differ from this repository:"
    printf '%s' "$KEPT_LIST" | while IFS= read -r f; do printf '    %s\n' "$(short_home "$f")"; done
    info "To decide again for a kept file, run the setup again. It asks about each file."
  fi
  if [ "$ZSHRC_KEPT_NO_EXTRAS" -eq 1 ]; then
    info "Your ~/.zshrc does not load the herdspace shell extras: ff, fif, the completion of hopen, and the fzf keys."
    info "To add them, run the setup again and answer e for ~/.zshrc."
  fi
  if [ -n "$BACKUP_LIST" ]; then
    info "Saved $(ui_count backup "$(printf '%s' "$BACKUP_LIST" | grep -c .)"). To put a file back, run its command:"
    printf '%s' "$BACKUP_LIST" | while IFS= read -r f; do printf '    mv %s.bak-%s %s\n' "$(short_home "$f")" "$STAMP" "$(short_home "$f")"; done
  fi
  if [ "$CHANGED" -eq 0 ]; then
    ok "Everything is already set up."
  else
    ok "Done."
  fi
  next_steps "$role"
}

# git_pin puts one commit of a repository in DEST, with no history.
git_pin() {
  local url="$1" dest="$2" ref="$3"
  if [ -d "${dest}/.git" ] && [ "$(git -C "$dest" rev-parse HEAD)" = "$ref" ]; then
    return 0
  fi
  if [ ! -d "${dest}/.git" ]; then
    rm -rf "$dest"
    mkdir -p "$dest"
    git -C "$dest" init -q
    git -C "$dest" remote add origin "$url"
  fi
  git -C "$dest" fetch -q --depth 1 origin "$ref"
  git -C "$dest" -c advice.detachedHead=false checkout -q --force FETCH_HEAD
}

# load_homebrew adds Homebrew to PATH, if it is installed.
load_homebrew() {
  if ! have brew; then
    [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
    [ -x /usr/local/bin/brew ] && eval "$(/usr/local/bin/brew shellenv)"
  fi
  return 0
}

homebrew_ready() { have brew; }

# install_homebrew asks for a password, so it needs a person at the keyboard.
install_homebrew() {
  info "Installing Homebrew. It asks for your password."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  load_homebrew
  have brew || die "Homebrew did not install."
}

# brew_formulas_ready NAME... exits 0 if each formula is installed.
brew_formulas_ready() {
  have brew || return 1
  local installed name
  installed="$(brew list --formula -1 2>/dev/null)"
  for name in "$@"; do
    grep -Fxq -- "$name" <<<"$installed" || return 1
  done
}

# brew_install NAME... installs formulas. At a terminal, the output of brew is
# indented and dim, so that the lines of the setup stand out.
brew_install() { brew install "$@" 2>&1 | ui_indent; }
