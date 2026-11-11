#!/usr/bin/env bash
# run-release-check.sh installs a published release, as a person would, in each
# sandbox that this machine supports. Then it runs tests/tour-release.sh there.
#
# Linux: a fresh container for each image, with Docker.
# macOS: a fresh clone of a Tart VM image, with Tart on a Mac with Apple silicon.
# A sandbox that this machine cannot run prints a SKIP line, and the check goes on.
#
# Usage: tests/run-release-check.sh [--version TAG] [--only linux|macos] [image ...]
#   --version TAG   Install this release. The default is the latest release.
#   image           Linux images. The default is ubuntu:24.04 debian:12.
#   TART_BASE       The local Tart image to clone. The default is tahoe-base.
#   VM_DNS          A DNS server for the VM, for a host whose DNS proxy refuses
#                   the VM. The default is 1.1.1.1. Set VM_DNS= to keep the VM's own.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
mkdir -p tests/.work

TAG=""
ONLY=""
IMAGES=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --version) TAG="$2"; shift 2 ;;
    --only) ONLY="$2"; shift 2 ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) IMAGES+=("$1"); shift ;;
  esac
done
[ "${#IMAGES[@]}" -gt 0 ] || IMAGES=(ubuntu:24.04 debian:12)
TART_BASE="${TART_BASE:-tahoe-base}"
VM_DNS="${VM_DNS-1.1.1.1}"
URL="https://github.com/MussaCharles/herdspace/releases/latest/download/bootstrap.sh"
version_flag=""
[ -z "$TAG" ] || version_flag="--version ${TAG}"
status=0
ran=0

# Prints the PASS, FAIL, and RESULT lines of a log, and the exit code.
report() {
  grep -E '^(PASS|FAIL|RESULT)' "$2" | grep -v '^PASS' | cut -c1-300
  echo "RESULT $1 pass=$(grep -c '^PASS' "$2") exit=$3 log=$2"
  [ "$3" -eq 0 ] || status=1
}

if [ "$ONLY" != macos ]; then
  if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
    for image in "${IMAGES[@]}"; do
      log="tests/.work/release-check-$(printf '%s' "$image" | tr -c 'a-z0-9' '-').log"
      docker run --rm --name "hs-release-check-$$" -v "$PWD/tests:/check:ro" "$image" bash -c "
        set -e
        apt-get update -qq && apt-get install -y -qq --no-install-recommends sudo ca-certificates curl procps >/dev/null
        useradd -m -s /bin/bash tester && echo 'tester ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/tester
        su - tester -c 'export LANG=C.UTF-8; curl -fsSL ${URL} | bash -s -- server --yes --skip-login-service --skip-nvim-tools ${version_flag} && bash /check/tour-release.sh ${TAG}'
      " >"$log" 2>&1
      report "linux ${image}" "$log" "$?"
      ran=$((ran + 1))
    done
  else
    echo "SKIP linux: Docker is not installed or does not answer."
  fi
fi

if [ "$ONLY" != linux ]; then
  if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
    echo "SKIP macos: Tart needs a Mac with Apple silicon."
  elif ! command -v tart >/dev/null; then
    echo "SKIP macos: Tart is not installed. See docs/testing.md#macos-a-tart-vm."
  elif ! tart list --quiet 2>/dev/null | grep -qx "$TART_BASE"; then
    echo "SKIP macos: the Tart image ${TART_BASE} is missing. See docs/testing.md#macos-a-tart-vm."
  else
    vm="hs-release-$$"
    log="tests/.work/release-check-macos.log"
    cleanup() { tart stop "$vm" >/dev/null 2>&1; tart delete "$vm" >/dev/null 2>&1; }
    trap cleanup EXIT
    tart clone "$TART_BASE" "$vm"
    tart run "$vm" --no-graphics --dir="check:$PWD/tests:ro" >/dev/null 2>&1 &
    for _ in $(seq 1 40); do tart exec "$vm" true 2>/dev/null && break; sleep 3; done
    [ -z "$VM_DNS" ] || tart exec "$vm" sudo networksetup -setdnsservers Ethernet "$VM_DNS"
    tart exec "$vm" zsh -lc "cp -R '/Volumes/My Shared Files/check' ~/check && curl -fsSL ${URL} | bash -s -- server --yes --skip-nvim-tools ${version_flag} && zsh -lc 'bash ~/check/tour-release.sh ${TAG}'" >"$log" 2>&1
    report macos "$log" "$?"
    ran=$((ran + 1))
    cleanup
    trap - EXIT
  fi
fi

[ "$ran" -gt 0 ] || { echo "RESULT no sandbox ran"; exit 1; }
exit "$status"
