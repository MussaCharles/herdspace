# shellcheck shell=bash
# The download of pinned repositories, and Homebrew.
# bootstrap/lib/common.sh loads this file. It works with the bash 3.2 that macOS ships.

# git_pin puts one commit of a repository in DEST, with no history.
git_pin() {
  local url="$1" dest="$2" ref="$3"
  if [ -d "${dest}/.git" ] && [ "$(git -C "$dest" rev-parse HEAD)" = "$ref" ]; then
    return 0
  fi
  local plugin
  plugin="$(basename "$dest")"
  info "Downloading ${plugin#.}."
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
