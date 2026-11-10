#!/usr/bin/env bash
# bootstrap-server-macos.sh
#
# Sets up Herdr and its tools on a macOS server. Run it as the account that will
# use Herdr. It does only the parts that are not done.
#
# Usage: ./bootstrap-server-macos.sh [options] [--skip-nvim-tools] [--skip-login-service]
#
# With no option, the script asks about each file that you changed.
#   --check          Report what is done, missing, or different. Change nothing.
#   --keep-existing  Add what is missing, and change no existing file.
#   --replace-all    Use the repository version of every file, with backups.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
export REPO_ROOT
SKIP_NVIM_TOOLS=0
SKIP_LOGIN_SERVICE=0
FORMULAS="herdr neovim lazygit git-delta eza zoxide fzf bat fd ripgrep node"

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
  apply_mode_flag "$arg" && continue
  case "$arg" in
    --skip-nvim-tools) SKIP_NVIM_TOOLS=1 ;;
    --skip-login-service) SKIP_LOGIN_SERVICE=1 ;;
    -h | --help) print_usage "$0"; exit 0 ;;
    *) die "Unknown option: ${arg}" ;;
  esac
done

[ "$(uname -s)" = "Darwin" ] || die "This script is for macOS."

export PATH="${HOME}/.local/bin:${PATH}"
load_homebrew

# shellcheck disable=SC2086 # The list must split into words.
formulas_ready() { brew_formulas_ready $FORMULAS; }
# shellcheck disable=SC2086
install_formulas() { brew_install $FORMULAS; }

step "Checking this computer"
run_part "Homebrew" homebrew_ready install_homebrew
run_part "Homebrew packages" formulas_ready install_formulas
setup_shell server
setup_zprofile server
setup_server_files "${HOME}/Library/Application Support/lazygit"
setup_server_common
run_part "Herdr LaunchAgent" macos_service_ready install_macos_service
finish_run "Connect with SSH and run: herdr"
