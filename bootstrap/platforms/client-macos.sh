#!/usr/bin/env bash
# bootstrap/platforms/client-macos.sh. Run it with ./bootstrap.sh client, which picks it on macOS.
#
# Sets up Ghostty and the shell on the Mac that you use for SSH. It also copies
# the Ghostty terminal description to each server. It does only the parts that
# are not done.
#
# Usage: ./bootstrap.sh client [options] [--server HOST]... [--skip-mission-control]
#        [--keep-terminal-keys | --use-herdspace-keys]
#
# With no option, the script asks about each file that you changed.
#   --check          Report what is done, missing, or different. Change nothing.
#   --keep-existing  Add what is missing, and change no existing file.
#   --replace-all    Use the repository version of every file, with backups.
#   --yes            Install the missing prerequisites with no question.
#   --keep-terminal-keys  Keep the keys of Ghostty and macOS. The choice stays.
#   --use-herdspace-keys  Use the editor keys of herdspace again (the default).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export REPO_ROOT
SERVERS=()
SKIP_MISSION_CONTROL=0
FORMULAS="eza zoxide fzf bat fd"
ACTIVATE_SETTINGS="${ACTIVATE_SETTINGS:-/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings}"
export TERMINFO="${GHOSTTY_TERMINFO:-/Applications/Ghostty.app/Contents/Resources/terminfo}"

# shellcheck source=bootstrap/lib/common.sh
source "${REPO_ROOT}/bootstrap/lib/common.sh"
# shellcheck source=bootstrap/lib/prereqs.sh
source "${REPO_ROOT}/bootstrap/lib/prereqs.sh"
# shellcheck source=bootstrap/lib/shell.sh
source "${REPO_ROOT}/bootstrap/lib/shell.sh"
# shellcheck source=bootstrap/lib/client.sh
source "${REPO_ROOT}/bootstrap/lib/client.sh"
# shellcheck source=tools/versions.env
source "${REPO_ROOT}/tools/versions.env"

while [ "$#" -gt 0 ]; do
  if apply_mode_flag "$1" || keys_flag "$1"; then
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

# set_hotkey turns one macOS shortcut on (true) or off (false). The key code is
# the arrow key, and 8650752 is the Ctrl key.
set_hotkey() {
  local id="$1" key="$2" enabled="$3"
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$id" \
    "<dict><key>enabled</key><${enabled}/><key>value</key><dict><key>type</key><string>standard</string><key>parameters</key><array><integer>65535</integer><integer>${key}</integer><integer>8650752</integer></array></dict></dict>"
}

# With the herdspace keys, the Ctrl arrow keys leave Mission Control. With the
# terminal keys, Mission Control gets them back if this script took them.
mission_control_ready() {
  [ "$SKIP_MISSION_CONTROL" -eq 1 ] && return 0
  if [ "$KEYS" = "terminal" ]; then
    [ ! -f "${STATE_DIR}/done/mission-control" ]
  else
    [ -f "${STATE_DIR}/done/mission-control" ]
  fi
}

set_mission_control() {
  local enabled="false"
  [ "$KEYS" = "terminal" ] && enabled="true"
  # 32 Mission Control, 33 Application windows, 79 and 81 move one space.
  set_hotkey 32 126 "$enabled"
  set_hotkey 33 125 "$enabled"
  set_hotkey 79 123 "$enabled"
  set_hotkey 81 124 "$enabled"
  if [ -x "$ACTIVATE_SETTINGS" ]; then
    "$ACTIVATE_SETTINGS" -u >/dev/null 2>&1 || true
  fi
  mkdir -p "${STATE_DIR}/done"
  if [ "$enabled" = "true" ]; then
    rm -f "${STATE_DIR}/done/mission-control"
  else
    touch "${STATE_DIR}/done/mission-control"
  fi
  info "If a Ctrl arrow key does not do what you expect, log out and log in."
}

prereq_add "Homebrew" necessary homebrew_ready install_homebrew yes "Install Homebrew from https://brew.sh, and run the setup again."
prereq_add "Homebrew can write to its folder" necessary brew_writable - no "Run the setup from the account that owns Homebrew, or give this account write access to $(brew --prefix 2>/dev/null || echo /opt/homebrew)."
prereq_add "Ghostty" necessary ghostty_ready install_ghostty_app no "Ghostty needs an admin account. From an admin account, run: brew install --cask ghostty"
if [ "${#SERVERS[@]}" -gt 0 ]; then
  prereq_add "SSH connection to each server" optional servers_ready - no "$(ssh_fix "${SERVERS[*]}")"
fi
run_prereqs

step "Checking this machine"
run_part "Homebrew packages" formulas_ready install_formulas
setup_shell client
setup_zprofile client
load_keys
install_ghostty_config "${REPO_ROOT}/config/ghostty/config.ghostty"
if [ "${#SERVERS[@]}" -gt 0 ]; then
  for server in "${SERVERS[@]}"; do
    run_part "Terminal description on ${server}" terminfo_ready copy_terminfo "$server"
  done
fi
run_part "Mission Control shortcuts" mission_control_ready set_mission_control
NEXT_SERVER="${SERVERS[0]:-}"
finish_run "$([ "${HS_ROLE:-}" = both ] && echo both || echo client)"
