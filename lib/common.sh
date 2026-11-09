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

# install_file copies SRC to DEST. It does nothing if the two are the same. It
# makes a backup if DEST holds different content.
install_file() {
  local src="$1" dest="$2" mode="${3:-644}"
  mkdir -p "$(dirname "$dest")"
  if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
    return 0
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    cp -pP "$dest" "${dest}.bak-${STAMP}"
    info "Saved a backup: ${dest}.bak-${STAMP}"
  fi
  rm -f "$dest"
  cp "$src" "$dest"
  chmod "$mode" "$dest"
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
  mkdir -p "$(dirname "$file")"
  touch "$file"
  tmp="$(mktemp)"
  awk -v begin="$begin" -v end="$end" '
    $0 == begin { skip = 1; next }
    $0 == end { skip = 0; next }
    !skip { print }
  ' "$file" >"$tmp"
  {
    cat "$tmp"
    printf '%s\n%s\n%s\n' "$begin" "$text" "$end"
  } >"${tmp}.new"
  rm -f "$tmp"
  if cmp -s "${tmp}.new" "$file"; then
    rm -f "${tmp}.new"
    return 0
  fi
  cat "${tmp}.new" >"$file"
  rm -f "${tmp}.new"
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

# ensure_homebrew installs Homebrew if it is missing. The installer asks for
# your password, so this step needs a person at the keyboard.
ensure_homebrew() {
  if ! have brew; then
    [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
    [ -x /usr/local/bin/brew ] && eval "$(/usr/local/bin/brew shellenv)"
  fi
  if ! have brew; then
    info "Installing Homebrew. It asks for your password."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
    [ -x /usr/local/bin/brew ] && eval "$(/usr/local/bin/brew shellenv)"
    have brew || die "Homebrew did not install."
  fi
}
