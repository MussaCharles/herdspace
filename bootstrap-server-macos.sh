#!/usr/bin/env bash
# bootstrap-server-macos.sh
#
# Sets up Herdr and its tools on a macOS server. Run it as the account that will
# use Herdr. You can run it again at any time.
#
# Usage: ./bootstrap-server-macos.sh [--skip-nvim-tools] [--skip-login-service]
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
# shellcheck source=lib/service-macos.sh
source "${REPO_ROOT}/lib/service-macos.sh"
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

[ "$(uname -s)" = "Darwin" ] || die "This script is for macOS."

step "Homebrew packages"
ensure_homebrew
brew install herdr neovim lazygit git-delta eza zoxide fzf bat fd ripgrep node
export PATH="${HOME}/.local/bin:${PATH}"
ok "Homebrew packages"

setup_shell server
setup_zprofile server
setup_server_files "${HOME}/Library/Application Support/lazygit"
setup_neovim
ensure_server
setup_auto_title
setup_agents
install_macos_service
finish_server
