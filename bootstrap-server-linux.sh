#!/usr/bin/env bash
# bootstrap-server-linux.sh
#
# Sets up Herdr and its tools on a Debian or Ubuntu server. Run it as the
# account that will use Herdr. You can run it again at any time.
#
# Usage: ./bootstrap-server-linux.sh [--skip-nvim-tools] [--skip-login-service]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
export REPO_ROOT
SKIP_NVIM_TOOLS=0
SKIP_LOGIN_SERVICE=0

# shellcheck source=lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
# shellcheck source=lib/shell.sh
source "${REPO_ROOT}/lib/shell.sh"
# shellcheck source=lib/server.sh
source "${REPO_ROOT}/lib/server.sh"
# shellcheck source=lib/linux-tools.sh
source "${REPO_ROOT}/lib/linux-tools.sh"
# shellcheck source=lib/service-linux.sh
source "${REPO_ROOT}/lib/service-linux.sh"
# shellcheck source=tools/versions.env
source "${REPO_ROOT}/tools/versions.env"

for arg in "$@"; do
  case "$arg" in
    --skip-nvim-tools) SKIP_NVIM_TOOLS=1 ;;
    --skip-login-service) SKIP_LOGIN_SERVICE=1 ;;
    -h | --help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "Unknown option: ${arg}" ;;
  esac
done

[ "$(uname -s)" = "Linux" ] || die "This script is for Linux."
have apt-get || die "This script needs apt-get, so it works only on Debian and Ubuntu."

step "System packages"
apt_install ca-certificates curl git zsh python3 tar gzip unzip ripgrep fd-find bat \
  build-essential nodejs npm
link_debian_tools
ok "System packages"

install_release_tools herdr neovim lazygit git-delta eza zoxide fzf
setup_shell server
setup_zprofile server
setup_server_files "${HOME}/.config/lazygit"
setup_neovim
ensure_server
setup_auto_title
setup_agents
install_linux_service

set_login_shell_zsh

finish_server
