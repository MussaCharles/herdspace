#!/usr/bin/env bash
# bootstrap.sh sets up a server machine, a client machine, or both on one
# machine. It finds the system, and it runs the scripts for that system from
# the folder bootstrap/platforms/. It is safe to run again.
#
# Usage: ./bootstrap.sh server [options]
#        ./bootstrap.sh client --server HOST [--server HOST]... [options]
#        ./bootstrap.sh both [options]
#        curl -fsSL <release-url>/bootstrap.sh | bash -s -- server
#
# Options for every machine:
#   --os macos|linux|wsl  The system. The default is the system that it finds.
#   --check               Report what is done, missing, or different. Change nothing.
#   --keep-existing       Add what is missing, and change no existing file.
#   --replace-all         Use the repository version of every file, with backups.
#   --yes                 Install the missing prerequisites with no question.
#   --version TAG         With curl: the release to download. The default is
#                         the release of this file.
#   -h, --help            Show this help.
#
# Options for a server:
#   --skip-nvim-tools     Do not install the Neovim language tools.
#   --skip-login-service  Do not start Herdr at login.
#
# Options for a client:
#   --server HOST         An SSH host name of a server, or user@address. Repeat it
#                         for each server.
#   --no-ghostty          Linux: use another terminal. WSL always uses this.
#   --skip-mission-control  macOS: keep the Mission Control shortcuts.
#   --keep-terminal-keys  Keep the keys of Ghostty and macOS. The choice stays.
#   --use-herdspace-keys  Use the editor keys of herdspace again (the default).
#
# both runs the server setup and then the client setup on this machine. It
# takes the options of both, and --server is not necessary.
#
# With curl, the script downloads the release into
# ~/.local/share/herdspace/<tag>, compares its checksum, and runs it.
set -euo pipefail

RELEASE="@VERSION@"
REPO="${HS_REPO:-@REPO@}"
ROLE=""
OS=""
TAG=""
PASS=()

die() { printf '  [err]  %s\n' "$*" >&2; exit 1; }
# At a terminal, the lines of this script have no [info] word, as in the setup scripts.
info() {
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ]; then printf '  %s\n' "$*"; else printf '  [info] %s\n' "$*"; fi
}
usage() { sed -n '2,37p' "${BASH_SOURCE[0]}" 2>/dev/null | sed 's/^# \{0,1\}//' || echo "Usage: bootstrap.sh server|client|both [options]"; }

ARGS=("$@")
i=0
while [ "$i" -lt "${#ARGS[@]}" ]; do
  arg="${ARGS[$i]}"
  case "$arg" in
    server | client | both)
      [ -z "$ROLE" ] || die "Give server, client, or both once."
      ROLE="$arg"
      ;;
    --os)
      i=$((i + 1))
      [ "$i" -lt "${#ARGS[@]}" ] || die "--os needs macos, linux, or wsl."
      OS="${ARGS[$i]}"
      ;;
    --os=*) OS="${arg#--os=}" ;;
    --version)
      i=$((i + 1))
      [ "$i" -lt "${#ARGS[@]}" ] || die "--version needs a release tag."
      TAG="${ARGS[$i]}"
      ;;
    -h | --help) usage; exit 0 ;;
    --server)
      i=$((i + 1))
      [ "$i" -lt "${#ARGS[@]}" ] || die "--server needs a host name."
      PASS+=("$arg" "${ARGS[$i]}")
      ;;
    *) PASS+=("$arg") ;;
  esac
  i=$((i + 1))
done

# ---------- find the repository, or download a release

SELF="${BASH_SOURCE[0]:-}"
HERE=""
if [ -n "$SELF" ] && [ -f "$SELF" ]; then
  HERE="$(cd "$(dirname "$SELF")" && pwd)"
fi

if [ -z "$HERE" ] || [ ! -d "${HERE}/bootstrap/platforms" ]; then
  # This copy came from curl. Download the full release and run it.
  [ -n "$ROLE" ] || { usage >&2; exit 2; }
  TAG="${TAG:-${HS_VERSION:-$RELEASE}}"
  case "$TAG" in "" | @*@) die "No release is set. Give one with --version <tag>." ;; esac
  case "$REPO" in "" | @*@) [ -n "${HS_BASE_URL:-}" ] || die "No repository is set. Set HS_REPO to owner/name." ;; esac
  for tool in curl tar; do command -v "$tool" >/dev/null 2>&1 || die "This script needs ${tool}."; done
  base="${HS_BASE_URL:-https://github.com/${REPO}/releases/download/${TAG}}"
  archive="herdspace-${TAG}.tar.gz"
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  fetch() {
    if curl -fsSL "${base}/$1" -o "${work}/$1" 2>/dev/null; then return 0; fi
    if [ -z "${HS_BASE_URL:-}" ] && command -v gh >/dev/null 2>&1; then
      gh release download "$TAG" --repo "$REPO" --pattern "$1" --dir "$work" --clobber >/dev/null 2>&1 && return 0
    fi
    die "Could not download $1 from ${base}."
  }
  sha_of() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d ' ' -f 1; else shasum -a 256 "$1" | cut -d ' ' -f 1; fi; }
  info "Downloading herdspace ${TAG}."
  fetch "$archive"
  fetch SHA256SUMS
  want="$(awk -v f="$archive" '$2 == f || $2 == "*" f {print $1}' "${work}/SHA256SUMS")"
  [ -n "$want" ] && [ "$(sha_of "${work}/${archive}")" = "$want" ] || die "The checksum of ${archive} is wrong. Nothing was changed."
  dest_root="${HS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/herdspace}"
  mkdir -p "$dest_root"
  tar -xzf "${work}/${archive}" -C "$work"
  rm -rf "${dest_root:?}/${TAG}"
  mv "${work}/herdspace-${TAG}" "${dest_root}/${TAG}"
  info "The files are in ${dest_root}/${TAG}."
  # A script from curl reads its questions from the terminal, not from the pipe.
  if [ -z "${HS_NO_TTY:-}" ] && { : </dev/tty; } 2>/dev/null; then
    exec bash "${dest_root}/${TAG}/bootstrap.sh" "$@" </dev/tty
  fi
  exec bash "${dest_root}/${TAG}/bootstrap.sh" "$@"
fi

# ---------- pick the script for this machine

[ -n "$ROLE" ] || { usage >&2; exit 2; }
if [ -z "$OS" ]; then
  case "$(uname -s)" in
    Darwin) OS="macos" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then OS="wsl"; else OS="linux"; fi
      ;;
    *) die "This system is not supported: $(uname -s). Use macOS, Linux, or WSL." ;;
  esac
fi
case "$OS" in
  macos | linux | wsl) ;;
  *) die "--os must be macos, linux, or wsl." ;;
esac

case "${ROLE}-${OS}" in
  server-macos) script="server-macos.sh" ;;
  server-linux | server-wsl) script="server-linux.sh" ;;
  client-macos) script="client-macos.sh" ;;
  client-linux) script="client-linux.sh" ;;
  client-wsl | both-wsl)
    script="client-linux.sh"
    case " ${PASS[*]:-} " in *" --no-ghostty "*) ;; *) PASS+=("--no-ghostty") ;; esac
    ;;
  both-macos) script="client-macos.sh" ;;
  both-linux) script="client-linux.sh" ;;
esac

# The first line of a run names the script, its release, the role, and the system.
case "$RELEASE" in
  @*@) script_version="from the repository" ;;
  *) script_version="$RELEASE" ;;
esac
# The links at the end of a run point at the docs of this release.
case "${RELEASE}${REPO}" in
  *@*) HS_DOC_BASE="https://github.com/MussaCharles/herdspace/blob/main" ;;
  *) HS_DOC_BASE="https://github.com/${REPO}/blob/${RELEASE}" ;;
esac
export HS_DOC_BASE
case "$OS" in
  macos) os_name="macOS" ;;
  linux) os_name="Linux" ;;
  wsl) os_name="Windows with WSL" ;;
  *) os_name="$OS" ;;
esac

if [ "$ROLE" != "both" ]; then
  info "herdspace setup (bootstrap.sh ${script_version}): a ${ROLE} on ${os_name}."
  if [ -n "${HS_DRY_RUN:-}" ]; then
    echo "bootstrap/platforms/${script} ${PASS[*]:-}"
    exit 0
  fi
  exec "${HERE}/bootstrap/platforms/${script}" ${PASS[@]+"${PASS[@]}"}
fi

# both: give each script only its own options. The shell files get the role
# "both", so that the second script does not undo the first one.
case "$OS" in
  macos) server_script="server-macos.sh" ;;
  *) server_script="server-linux.sh" ;;
esac
PASS_SERVER=()
PASS_CLIENT=()
check=0
j=0
while [ "$j" -lt "${#PASS[@]}" ]; do
  arg="${PASS[$j]}"
  case "$arg" in
    --skip-nvim-tools | --skip-login-service) PASS_SERVER+=("$arg") ;;
    --no-ghostty | --skip-mission-control | --keep-terminal-keys | --use-herdspace-keys) PASS_CLIENT+=("$arg") ;;
    --server)
      j=$((j + 1))
      PASS_CLIENT+=("$arg" "${PASS[$j]}")
      ;;
    *)
      [ "$arg" = "--check" ] && check=1
      PASS_SERVER+=("$arg")
      PASS_CLIENT+=("$arg")
      ;;
  esac
  j=$((j + 1))
done

info "herdspace setup (bootstrap.sh ${script_version}): a server and a client on ${os_name}, on this one machine."
if [ -n "${HS_DRY_RUN:-}" ]; then
  echo "bootstrap/platforms/${server_script} ${PASS_SERVER[*]:-}"
  echo "bootstrap/platforms/${script} ${PASS_CLIENT[*]:-}"
  exit 0
fi
export HS_ROLE=both
info "Part 1 of 2: the server setup."
rc=0
"${HERE}/bootstrap/platforms/${server_script}" ${PASS_SERVER[@]+"${PASS_SERVER[@]}"} || rc=$?
# A check reports both parts. A real run stops if the server part fails.
if [ "$rc" -ne 0 ] && [ "$check" -eq 0 ]; then
  exit "$rc"
fi
info "Part 2 of 2: the client setup."
"${HERE}/bootstrap/platforms/${script}" ${PASS_CLIENT[@]+"${PASS_CLIENT[@]}"} || rc=$?
exit "$rc"
