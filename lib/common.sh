#!/usr/bin/env bash
# Shared helpers. This file works with the bash 3.2 that macOS ships.

STAMP="$(date +%Y%m%d-%H%M%S)"
export STATE_DIR="${HOME}/.local/share/herdr-bootstrap"

info() { printf '  [info] %s\n' "$*"; }
ok() { printf '  [ok]   %s\n' "$*"; }
warn() { printf '  [warn] %s\n' "$*" >&2; }
die() { printf '  [err]  %s\n' "$*" >&2; exit 1; }
step() { printf '\n== %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

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
ASK_ALL=""
MANIFEST="${STATE_DIR}/manifest.tsv"

# apply_mode_flag sets MODE. It returns 1 if the option is something else.
apply_mode_flag() {
  case "$1" in
    --check) MODE="check" ;;
    --keep-existing) MODE="keep" ;;
    --replace-all) MODE="replace" ;;
    *) return 1 ;;
  esac
}

# print_usage prints the comment at the top of a script.
print_usage() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$1"
}

note_todo() {
  TODO=$((TODO + 1))
  printf '  [todo] %s\n' "$*"
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
  fi
  rm -f "$dest"
  cp "$src" "$dest"
  chmod "$mode" "$dest"
  manifest_set "$dest" "$(file_sha "$dest")"
  CHANGED=$((CHANGED + 1))
}

# decide_edit sets DECISION to keep or replace for a file that a person changed.
decide_edit() {
  local src="$1" dest="$2" answer
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
  while true; do
    printf '\n  %s differs from this repository.\n' "$dest"
    printf '  [k]eep it, [r]eplace it, show the [d]ifference, [K]eep all, [R]eplace all: '
    IFS= read -r answer || answer="k"
    case "$answer" in
      r | replace) DECISION="replace"; return 0 ;;
      R) ASK_ALL="replace"; DECISION="replace"; return 0 ;;
      K) ASK_ALL="keep"; DECISION="keep"; return 0 ;;
      d | diff) diff -u "$dest" "$src" | ${PAGER:-cat} || true ;;
      k | keep | "") DECISION="keep"; return 0 ;;
    esac
  done
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
        printf '  [diff] %s differs from this repository\n' "$dest"
        return 0
      fi
      decide_edit "$src" "$dest"
      if [ "$DECISION" = "replace" ]; then
        write_file "$src" "$dest" "$mode"
      else
        EDITED=$((EDITED + 1))
        KEPT_LIST="${KEPT_LIST}    ${dest}
"
      fi
      ;;
  esac
}

# install_tree copies every file below SRC_DIR to the same place below DEST_DIR.
install_tree() {
  local src_dir="$1" dest_dir="$2" file
  while IFS= read -r file; do
    install_file "${src_dir}/${file}" "${dest_dir}/${file}"
  done < <(cd "$src_dir" && find . -type f | sed 's|^\./||')
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
  local label="$1" check_fn="$2" apply_fn="$3"
  shift 3
  if "$check_fn" "$@"; then
    ok "$label"
    return 0
  fi
  if [ "$MODE" = "check" ]; then
    note_todo "$label"
    return 0
  fi
  step "$label"
  "$apply_fn" "$@"
  CHANGED=$((CHANGED + 1))
}

# finish_run prints the result. NEXT_STEP is shown after a run that changed something.
finish_run() {
  local next_step="$1"
  step "Result"
  if [ "$MODE" = "check" ]; then
    if [ "$TODO" -gt 0 ]; then
      info "${TODO} items need work. Run the script with no --check to do them."
      exit 1
    fi
    if [ "$EDITED" -gt 0 ]; then
      ok "Nothing is missing. ${EDITED} files differ from this repository."
    else
      ok "Everything is already set up."
    fi
    exit 0
  fi
  if [ -n "$KEPT_LIST" ]; then
    info "Kept ${EDITED} files that differ from this repository:"
    printf '%s' "$KEPT_LIST"
    info "To use the repository version of each file, run the script with --replace-all."
  fi
  if [ "$CHANGED" -eq 0 ]; then
    ok "Everything is already set up."
  else
    ok "Done. ${next_step}"
  fi
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

brew_install() { brew install "$@"; }
