#!/usr/bin/env bash
# bootstrap/platforms/server-linux.sh. Run it with ./bootstrap.sh server, which picks it on Linux.
#
# Sets up Herdr and its tools on a Debian or Ubuntu server. Run it as the
# account that will use Herdr. It does only the parts that are not done.
#
# Usage: ./bootstrap.sh server [options] [--skip-nvim-tools] [--skip-login-service]
#
# With no option, the script asks about each file that you changed.
#   --check          Report what is done, missing, or different. Change nothing.
#   --keep-existing  Add what is missing, and change no existing file.
#   --replace-all    Use the repository version of every file, with backups.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export REPO_ROOT
SKIP_NVIM_TOOLS=0
SKIP_LOGIN_SERVICE=0
PACKAGES="ca-certificates curl git zsh python3 tar gzip unzip ripgrep fd-find bat build-essential nodejs npm"

# shellcheck source=bootstrap/lib/common.sh
source "${REPO_ROOT}/bootstrap/lib/common.sh"
# shellcheck source=bootstrap/lib/shell.sh
source "${REPO_ROOT}/bootstrap/lib/shell.sh"
# shellcheck source=bootstrap/lib/server.sh
source "${REPO_ROOT}/bootstrap/lib/server.sh"
# shellcheck source=bootstrap/lib/linux-tools.sh
source "${REPO_ROOT}/bootstrap/lib/linux-tools.sh"
# shellcheck source=bootstrap/lib/service-linux.sh
source "${REPO_ROOT}/bootstrap/lib/service-linux.sh"
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

step "Checking this computer"
run_part "System packages" packages_ready install_packages
setup_release_tools herdr neovim lazygit git-delta eza zoxide fzf
setup_shell server
setup_zprofile server
setup_server_files "${HOME}/.config/lazygit"
setup_server_common
run_part "Herdr service at boot" linux_service_ready install_linux_service
run_part "Login shell" login_shell_ready set_login_shell_zsh
finish_run "Connect with SSH and run: herdr"
