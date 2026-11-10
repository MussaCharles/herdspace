#!/usr/bin/env bash
# platforms/client-macos.sh. Run it with ./bootstrap.sh client, which picks it on macOS.
#
# Sets up Ghostty and the shell on the Mac that you use for SSH. It also copies
# the Ghostty terminal description to each server. It does only the parts that
# are not done.
#
# Usage: ./bootstrap.sh client [options] [--server HOST]... [--skip-mission-control]
#
# With no option, the script asks about each file that you changed.
#   --check          Report what is done, missing, or different. Change nothing.
#   --keep-existing  Add what is missing, and change no existing file.
#   --replace-all    Use the repository version of every file, with backups.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export REPO_ROOT
SERVERS=()
SKIP_MISSION_CONTROL=0
FORMULAS="eza zoxide fzf bat fd"
ACTIVATE_SETTINGS="${ACTIVATE_SETTINGS:-/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings}"
export TERMINFO="${GHOSTTY_TERMINFO:-/Applications/Ghostty.app/Contents/Resources/terminfo}"

# shellcheck source=lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
# shellcheck source=lib/shell.sh
source "${REPO_ROOT}/lib/shell.sh"
# shellcheck source=lib/client.sh
source "${REPO_ROOT}/lib/client.sh"
# shellcheck source=tools/versions.env
source "${REPO_ROOT}/tools/versions.env"

while [ "$#" -gt 0 ]; do
  if apply_mode_flag "$1"; then
    shift
    continue
  fi
  case "$1" in
    --server)
      [ "$#" -ge 2 ] || die "--server needs a host name."
      SERVERS+=("$2")
      shift 2
      ;;
    --skip-mission-control) SKIP_MISSION_CONTROL=1; shift ;;
    -h | --help) print_usage "$0"; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[ "$(uname -s)" = "Darwin" ] || die "This script is for macOS."

load_homebrew

# shellcheck disable=SC2086 # The list must split into words.
formulas_ready() { brew_formulas_ready $FORMULAS; }
# shellcheck disable=SC2086
install_formulas() { brew_install $FORMULAS; }
ghostty_ready() { [ -d /Applications/Ghostty.app ] || { have brew && brew list --cask ghostty >/dev/null 2>&1; }; }
install_ghostty() { brew install --cask ghostty; }

# release_hotkey turns off one macOS shortcut. The key code is the arrow key.
release_hotkey() {
  local id="$1" key="$2"
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$id" \
    "<dict><key>enabled</key><false/><key>value</key><dict><key>type</key><string>standard</string><key>parameters</key><array><integer>65535</integer><integer>${key}</integer><integer>8650752</integer></array></dict></dict>"
}

mission_control_ready() {
  [ "$SKIP_MISSION_CONTROL" -eq 1 ] && return 0
  [ -f "${STATE_DIR}/done/mission-control" ]
}

release_mission_control() {
  # 32 Mission Control, 33 Application windows, 79 and 81 move one space.
  release_hotkey 32 126
  release_hotkey 33 125
  release_hotkey 79 123
  release_hotkey 81 124
  if [ -x "$ACTIVATE_SETTINGS" ]; then
    "$ACTIVATE_SETTINGS" -u >/dev/null 2>&1 || true
  fi
  mkdir -p "${STATE_DIR}/done"
  touch "${STATE_DIR}/done/mission-control"
  info "If a Ctrl arrow key still moves a space, log out and log in."
}

step "Checking this computer"
run_part "Homebrew" homebrew_ready install_homebrew
run_part "Homebrew packages" formulas_ready install_formulas
run_part "Ghostty" ghostty_ready install_ghostty
setup_shell client
setup_zprofile client
install_file "${REPO_ROOT}/config/ghostty/config.ghostty" "${HOME}/.config/ghostty/config.ghostty"
if [ "${#SERVERS[@]}" -gt 0 ]; then
  for server in "${SERVERS[@]}"; do
    run_part "Terminal description on ${server}" terminfo_ready copy_terminfo "$server"
  done
fi
run_part "Mission Control shortcuts" mission_control_ready release_mission_control
finish_run "Open a new Ghostty window. Press Cmd+Shift+, to reload the configuration."
