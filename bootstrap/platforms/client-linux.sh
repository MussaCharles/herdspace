#!/usr/bin/env bash
# bootstrap/platforms/client-linux.sh. Run it with ./bootstrap.sh client, which picks it on Linux.
#
# Sets up the shell and Ghostty on a Debian or Ubuntu machine that you use for
# SSH. It also copies the Ghostty terminal description to each server. It does
# only the parts that are not done. Use --no-ghostty with another terminal.
#
# Usage: ./bootstrap.sh client [options] [--server HOST]... [--no-ghostty]
#        [--keep-terminal-keys | --use-herdspace-keys]
#
# With no option, the script asks about each file that you changed.
#   --check          Report what is done, missing, or different. Change nothing.
#   --keep-existing  Add what is missing, and change no existing file.
#   --replace-all    Use the repository version of every file, with backups.
#   --keep-terminal-keys  Keep the keys of Ghostty. The choice stays.
#   --use-herdspace-keys  Use the editor keys of herdspace again (the default).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export REPO_ROOT
SERVERS=()
USE_GHOSTTY=1
PACKAGES="ca-certificates curl git zsh python3 tar gzip openssh-client ncurses-bin fd-find bat"

# shellcheck source=bootstrap/lib/common.sh
source "${REPO_ROOT}/bootstrap/lib/common.sh"
# shellcheck source=bootstrap/lib/shell.sh
source "${REPO_ROOT}/bootstrap/lib/shell.sh"
# shellcheck source=bootstrap/lib/linux-tools.sh
source "${REPO_ROOT}/bootstrap/lib/linux-tools.sh"
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
    --no-ghostty) USE_GHOSTTY=0; shift ;;
    -h | --help) print_usage "$0"; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[ "$(uname -s)" = "Linux" ] || die "This script is for Linux."
have apt-get || die "This script needs apt-get, so it works only on Debian and Ubuntu."

export PATH="${HOME}/.local/bin:${PATH}"

packages_ready() {
  # shellcheck disable=SC2086 # The list must split into words.
  apt_ready $PACKAGES && have bat && have fd
}

install_packages() {
  # shellcheck disable=SC2086
  apt_install $PACKAGES
  link_debian_tools
}

step "Checking this machine"
run_part "System packages" packages_ready install_packages
setup_release_tools eza zoxide fzf
setup_shell client
setup_zprofile client

ghostty_ready() { have ghostty; }

if [ "$USE_GHOSTTY" -eq 1 ] && ! ghostty_available; then
  warn "This system has no Ghostty package. See https://ghostty.org/docs/install/binary, or use --no-ghostty."
  USE_GHOSTTY=0
fi

if [ "$USE_GHOSTTY" -eq 1 ]; then
  run_part "Ghostty" ghostty_ready install_ghostty
  load_keys
  install_ghostty_config "${REPO_ROOT}/config/ghostty/config-linux.ghostty"
  if [ "${#SERVERS[@]}" -gt 0 ]; then
    for server in "${SERVERS[@]}"; do
      run_part "Terminal description on ${server}" terminfo_ready copy_terminfo "$server"
    done
  fi
fi

run_part "Login shell" login_shell_ready set_login_shell_zsh
finish_run "Open a new terminal window."
