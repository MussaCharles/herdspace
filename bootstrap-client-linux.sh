#!/usr/bin/env bash
# bootstrap-client-linux.sh
#
# Sets up the shell and Ghostty on a Debian or Ubuntu computer that you use for
# SSH. It also copies the Ghostty terminal description to each server. You can
# run it again. Use --no-ghostty if you use another terminal, for example in WSL.
#
# Usage: ./bootstrap-client-linux.sh [--server HOST]... [--no-ghostty]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
export REPO_ROOT
SERVERS=()
USE_GHOSTTY=1

# shellcheck source=lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
# shellcheck source=lib/shell.sh
source "${REPO_ROOT}/lib/shell.sh"
# shellcheck source=lib/linux-tools.sh
source "${REPO_ROOT}/lib/linux-tools.sh"
# shellcheck source=tools/versions.env
source "${REPO_ROOT}/tools/versions.env"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --server)
      [ "$#" -ge 2 ] || die "--server needs a host name."
      SERVERS+=("$2")
      shift 2
      ;;
    --no-ghostty) USE_GHOSTTY=0; shift ;;
    -h | --help)
      sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "Unknown option: $1" ;;
  esac
done

[ "$(uname -s)" = "Linux" ] || die "This script is for Linux."
have apt-get || die "This script needs apt-get, so it works only on Debian and Ubuntu."

step "System packages"
apt_install ca-certificates curl git zsh python3 tar gzip openssh-client ncurses-bin fd-find bat
link_debian_tools
ok "System packages"

install_release_tools eza zoxide fzf
setup_shell client
setup_zprofile client

if [ "$USE_GHOSTTY" -eq 1 ]; then
  step "Ghostty"
  if install_ghostty; then
    install_file "${REPO_ROOT}/config/ghostty/config-linux.ghostty" "${HOME}/.config/ghostty/config.ghostty"
    ok "Configuration. Press Ctrl+Shift+, in Ghostty to reload it."
  else
    warn "This system has no Ghostty package. See https://ghostty.org/docs/install/binary, or use --no-ghostty."
    USE_GHOSTTY=0
  fi
fi

# copy_terminfo sends the Ghostty terminal description to one server.
copy_terminfo() {
  local server="$1"
  if infocmp -x xterm-ghostty | ssh -- "$server" tic -x - 2>/dev/null; then
    ok "Terminal description on ${server}"
  else
    warn "Could not copy the terminal description to ${server}."
  fi
}

if [ "$USE_GHOSTTY" -eq 1 ] && [ "${#SERVERS[@]}" -gt 0 ]; then
  step "Terminal description"
  for server in "${SERVERS[@]}"; do
    copy_terminfo "$server"
  done
fi

set_login_shell_zsh

step "Done"
ok "Open a new terminal window."
