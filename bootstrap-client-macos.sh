#!/usr/bin/env bash
# bootstrap-client-macos.sh
#
# Sets up Ghostty and the shell on the Mac that you use for SSH. It also copies
# the Ghostty terminal description to each server. You can run it again.
#
# Usage: ./bootstrap-client-macos.sh [--server HOST]... [--skip-mission-control]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
export REPO_ROOT
SERVERS=()
SKIP_MISSION_CONTROL=0
ACTIVATE_SETTINGS="${ACTIVATE_SETTINGS:-/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings}"
GHOSTTY_TERMINFO="${GHOSTTY_TERMINFO:-/Applications/Ghostty.app/Contents/Resources/terminfo}"

# shellcheck source=lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
# shellcheck source=lib/shell.sh
source "${REPO_ROOT}/lib/shell.sh"
# shellcheck source=tools/versions.env
source "${REPO_ROOT}/tools/versions.env"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --server)
      [ "$#" -ge 2 ] || die "--server needs a host name."
      SERVERS+=("$2")
      shift 2
      ;;
    --skip-mission-control) SKIP_MISSION_CONTROL=1; shift ;;
    -h | --help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "Unknown option: $1" ;;
  esac
done

[ "$(uname -s)" = "Darwin" ] || die "This script is for macOS."

step "Homebrew packages"
ensure_homebrew
brew install eza zoxide fzf bat fd
if [ -d /Applications/Ghostty.app ] || brew list --cask ghostty >/dev/null 2>&1; then
  ok "Ghostty is already installed"
else
  brew install --cask ghostty
fi
ok "Homebrew packages"

setup_shell client
setup_zprofile client

step "Ghostty"
install_file "${REPO_ROOT}/config/ghostty/config.ghostty" "${HOME}/.config/ghostty/config.ghostty"
ok "Configuration. Press Cmd+Shift+, in Ghostty to reload it."

# copy_terminfo sends the Ghostty terminal description to one server.
copy_terminfo() {
  local server="$1"
  if TERMINFO="$GHOSTTY_TERMINFO" infocmp -x xterm-ghostty | ssh -- "$server" tic -x - 2>/dev/null; then
    ok "Terminal description on ${server}"
  else
    warn "Could not copy the terminal description to ${server}."
  fi
}

if [ "${#SERVERS[@]}" -gt 0 ]; then
  step "Terminal description"
  for server in "${SERVERS[@]}"; do
    copy_terminfo "$server"
  done
fi

# release_hotkey turns off one macOS shortcut. The key code is the arrow key.
release_hotkey() {
  local id="$1" key="$2"
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$id" \
    "<dict><key>enabled</key><false/><key>value</key><dict><key>type</key><string>standard</string><key>parameters</key><array><integer>65535</integer><integer>${key}</integer><integer>8650752</integer></array></dict></dict>"
}

if [ "$SKIP_MISSION_CONTROL" -eq 0 ]; then
  step "Mission Control shortcuts"
  # 32 Mission Control, 33 Application windows, 79 and 81 move one space.
  release_hotkey 32 126
  release_hotkey 33 125
  release_hotkey 79 123
  release_hotkey 81 124
  [ -x "$ACTIVATE_SETTINGS" ] && "$ACTIVATE_SETTINGS" -u >/dev/null 2>&1 || true
  ok "The Ctrl arrow keys are free. If a key still moves a space, log out and log in."
fi

step "Done"
ok "Open a new Ghostty window."
