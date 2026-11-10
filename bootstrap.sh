#!/usr/bin/env bash
# bootstrap.sh sets up a Herdr server, or a computer that you use to connect to
# one. It finds the system, and it runs the script for that system from the
# folder platforms/. It is safe to run again.
#
# Usage: ./bootstrap.sh server [options]
#        ./bootstrap.sh client --server HOST [--server HOST]... [options]
#        curl -fsSL <release-url>/bootstrap.sh | bash -s -- server
#
# Options for every computer:
#   --os macos|linux|wsl  The system. The default is the system that it finds.
#   --check               Report what is done, missing, or different. Change nothing.
#   --keep-existing       Add what is missing, and change no existing file.
#   --replace-all         Use the repository version of every file, with backups.
#   --version TAG         With curl: the release to download. The default is
#                         the release of this file.
#   -h, --help            Show this help.
#
# Options for a server:
#   --skip-nvim-tools     Do not install the Neovim language tools.
#   --skip-login-service  Do not start Herdr at login.
#
# Options for a client:
#   --server HOST         An SSH host name of a server. Repeat it for each server.
#   --no-ghostty          Linux: use another terminal. WSL always uses this.
#   --skip-mission-control  macOS: keep the Mission Control shortcuts.
#
# With curl, the script downloads the release into
# ~/.local/share/herdr-bootstrap/<tag>, compares its checksum, and runs it.
set -euo pipefail

RELEASE="@VERSION@"
REPO="${HB_REPO:-@REPO@}"
ROLE=""
OS=""
TAG=""
PASS=()

die() { printf '  [err]  %s\n' "$*" >&2; exit 1; }
info() { printf '  [info] %s\n' "$*"; }
usage() { sed -n '2,29p' "${BASH_SOURCE[0]}" 2>/dev/null | sed 's/^# \{0,1\}//' || echo "Usage: bootstrap.sh server|client [options]"; }

ARGS=("$@")
i=0
while [ "$i" -lt "${#ARGS[@]}" ]; do
  arg="${ARGS[$i]}"
  case "$arg" in
    server | client)
      [ -z "$ROLE" ] || die "Give server or client once."
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

if [ -z "$HERE" ] || [ ! -d "${HERE}/platforms" ]; then
  # This copy came from curl. Download the full release and run it.
  [ -n "$ROLE" ] || { usage >&2; exit 2; }
  TAG="${TAG:-${HB_VERSION:-$RELEASE}}"
  case "$TAG" in "" | @*@) die "No release is set. Give one with --version <tag>." ;; esac
  case "$REPO" in "" | @*@) [ -n "${HB_BASE_URL:-}" ] || die "No repository is set. Set HB_REPO to owner/name." ;; esac
  for tool in curl tar; do command -v "$tool" >/dev/null 2>&1 || die "This script needs ${tool}."; done
  base="${HB_BASE_URL:-https://github.com/${REPO}/releases/download/${TAG}}"
  archive="herdr-bootstrap-${TAG}.tar.gz"
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  fetch() {
    if curl -fsSL "${base}/$1" -o "${work}/$1" 2>/dev/null; then return 0; fi
    if [ -z "${HB_BASE_URL:-}" ] && command -v gh >/dev/null 2>&1; then
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
  dest_root="${HB_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/herdr-bootstrap}"
  mkdir -p "$dest_root"
  tar -xzf "${work}/${archive}" -C "$work"
  rm -rf "${dest_root:?}/${TAG}"
  mv "${work}/herdr-bootstrap-${TAG}" "${dest_root}/${TAG}"
  info "The files are in ${dest_root}/${TAG}."
  # A script from curl reads its questions from the terminal, not from the pipe.
  if [ -z "${HB_NO_TTY:-}" ] && { : </dev/tty; } 2>/dev/null; then
    exec bash "${dest_root}/${TAG}/bootstrap.sh" "$@" </dev/tty
  fi
  exec bash "${dest_root}/${TAG}/bootstrap.sh" "$@"
fi

# ---------- pick the script for this computer

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
  client-wsl)
    script="client-linux.sh"
    case " ${PASS[*]:-} " in *" --no-ghostty "*) ;; *) PASS+=("--no-ghostty") ;; esac
    ;;
esac

info "Setting up a ${ROLE} on ${OS}."
if [ -n "${HB_DRY_RUN:-}" ]; then
  echo "platforms/${script} ${PASS[*]:-}"
  exit 0
fi
exec "${HERE}/platforms/${script}" ${PASS[@]+"${PASS[@]}"}
