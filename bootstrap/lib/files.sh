# shellcheck shell=bash
# The manifest of the installed files, and the install of files and blocks.
# bootstrap/lib/common.sh loads this file. It works with the bash 3.2 that macOS ships.

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

# known_old SRC SHA succeeds if SHA is the hash of an older herdspace version
# of SRC. tools/known-hashes.sh writes the list from the git history.
known_old() {
  local list="${REPO_ROOT:-}/bootstrap/known-hashes.tsv" rel
  [ -n "${REPO_ROOT:-}" ] && [ -f "$list" ] || return 1
  rel="${1#"${REPO_ROOT}"/}"
  grep -Fxq -- "${rel}"$'\t'"${2}" "$list"
}

# file_status prints missing, current, outdated, or edited. A file is outdated
# if a script wrote it and no person changed it: its hash is the one in the
# manifest, or, with no manifest entry, the hash of an older herdspace version.
file_status() {
  local src="$1" dest="$2" recorded sha
  if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    echo missing
  elif [ -f "$dest" ] && cmp -s "$src" "$dest"; then
    echo current
  elif [ ! -f "$dest" ]; then
    echo edited
  else
    recorded="$(manifest_get "$dest")"
    sha="$(file_sha "$dest")"
    if [ -n "$recorded" ] && [ "$recorded" = "$sha" ]; then
      echo outdated
    elif [ -z "$recorded" ] && known_old "$src" "$sha"; then
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
# shellcheck disable=SC2034 # ask_all_files in ask.sh reads CHANGED_FILES.
scan_changed_files() {
  [ "$CHANGED_FILES_READY" -eq 0 ] || return 0
  CHANGED_FILES_READY=1
  [ -z "${HS_SCAN:-}" ] || return 0
  CHANGED_FILES="$(HS_SCAN=1 NO_COLOR=1 bash "$HS_SELF" ${HS_ARGS[@]+"${HS_ARGS[@]}"} --check </dev/null 2>/dev/null |
    sed -n 's/^  \[diff\] \(.*\) differs from this repository$/\1/p' || true)"
}

# extras_block DEST adds the marked block that loads the herdspace shell extras.
extras_block() {
  # shellcheck disable=SC2016 # The line is text for zsh.
  ensure_block "$1" "herdspace extras" 'if [[ -r "$HOME/.config/herdspace/extras.zsh" ]]; then
  source "$HOME/.config/herdspace/extras.zsh"
fi'
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
        write_file "$src" "$dest" "$mode"
      else
        EDITED=$((EDITED + 1))
        KEPT_LIST="${KEPT_LIST}${dest}
"
      fi
      ;;
  esac
}

# install_tree copies every file below SRC_DIR to the same place below DEST_DIR.
# Files named in SEED_ONLY are copied only if they are missing, because a
# program changes them after the first start.
install_tree() {
  local src_dir="$1" dest_dir="$2" file
  # The list comes on fd 3, so that a question about a file still reads the terminal.
  while IFS= read -r file <&3; do
    if [ -n "${SEED_ONLY:-}" ] && grep -Fxq -- "$file" <<<"$SEED_ONLY"; then
      seed_file "${src_dir}/${file}" "${dest_dir}/${file}"
    else
      install_file "${src_dir}/${file}" "${dest_dir}/${file}"
    fi
  done 3< <(cd "$src_dir" && find . -type f | sed 's|^\./||')
}

# prune_tree SRC_DIR DEST_DIR removes each file of DEST_DIR that SRC_DIR no
# longer has, when no person changed it: its checksum is in the manifest, or in
# the list of older versions for an install from before the manifest. A
# changed file stays. A check changes nothing.
prune_tree() {
  local src_dir="$1" dest_dir="$2" file sha removed=0
  [ -d "$dest_dir" ] && [ "$MODE" != check ] || return 0
  while IFS= read -r file <&3; do
    [ ! -e "${src_dir}/${file}" ] || continue
    sha="$(file_sha "${dest_dir}/${file}")"
    if [ "$(manifest_get "${dest_dir}/${file}")" = "$sha" ] || known_old "${src_dir}/${file}" "$sha"; then
      rm -f "${dest_dir}/${file}"
      removed=$((removed + 1))
    fi
  done 3< <(cd "$dest_dir" && find . -type f | sed 's|^\./||')
  find "$dest_dir" -depth -mindepth 1 -type d -empty -exec rmdir {} + 2>/dev/null || true
  if [ "$removed" -gt 0 ]; then
    info "Removed ${removed} files of an older herdspace from $(short_home "$dest_dir")."
    CHANGED=$((CHANGED + 1))
  fi
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

# ensure_block FILE NAME TEXT [top] puts TEXT between two marker lines in FILE.
# It replaces the old text between the markers where it is, and leaves the rest
# of the file as it is. A new block goes at the end, or at the top with "top".
ensure_block() {
  local file="$1" name="$2" text="$3" where="${4:-end}"
  local begin="# >>> ${name} >>>" end="# <<< ${name} <<<" tmp block
  tmp="$(mktemp)"
  block="$(printf '%s\n%s\n%s' "$begin" "$text" "$end")"
  if [ -f "$file" ] && grep -qxF -- "$begin" "$file"; then
    # Replace the block where it is, so that the lines around it keep their order.
    HS_BLOCK="$block" awk -v begin="$begin" -v end="$end" '
      $0 == begin { print ENVIRON["HS_BLOCK"]; skip = 1; next }
      skip && $0 == end { skip = 0; next }
      !skip { print }
    ' "$file" >"$tmp"
  elif [ "$where" = "top" ]; then
    { printf '%s\n' "$block"; [ ! -f "$file" ] || { printf '\n'; cat "$file"; }; } >"$tmp"
  else
    { [ ! -f "$file" ] || cat "$file"; printf '%s\n' "$block"; } >"$tmp"
  fi
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
