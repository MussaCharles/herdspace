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

# run_root runs a command as root, with sudo when this account is not root.
run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

step "System packages"
run_root env DEBIAN_FRONTEND=noninteractive apt-get update -qq
run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
  ca-certificates curl git zsh python3 tar gzip unzip ripgrep fd-find bat \
  build-essential nodejs npm >/dev/null
mkdir -p "${HOME}/.local/bin"
# Debian names these two tools batcat and fdfind.
have batcat && ln -sfn "$(command -v batcat)" "${HOME}/.local/bin/bat"
have fdfind && ln -sfn "$(command -v fdfind)" "${HOME}/.local/bin/fd"
export PATH="${HOME}/.local/bin:${PATH}"
ok "System packages"

install_release_tools
setup_shell server
setup_zprofile server
setup_server_files "${HOME}/.config/lazygit"
setup_neovim
ensure_server
setup_auto_title
setup_agents
install_linux_service

zsh_path="$(command -v zsh)"
if [ "$(getent passwd "$(id -un)" | cut -d: -f7)" != "$zsh_path" ]; then
  step "Login shell"
  run_root chsh -s "$zsh_path" "$(id -un)" || warn "Could not change the login shell. Run: chsh -s ${zsh_path}"
fi

finish_server
