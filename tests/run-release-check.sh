#!/usr/bin/env bash
# run-release-check.sh runs each option of the Quick start of README.md, as a
# person would: with the command of the README, from a published release, in a
# fresh sandbox. Then it checks the result, and runs tests/tour-release.sh where
# hopen is installed.
#
# The options: server, client, both, and hopen (the "Only hopen" option).
# Linux: fresh Docker containers. The client option uses two containers: a
# server, and a client that connects to it with SSH.
# macOS: fresh clones of a Tart VM image, on a Mac with Apple silicon. The client
# option needs a second machine, so it runs only on Linux.
# A sandbox that this machine cannot run prints a SKIP line, and the check goes on.
#
# Usage: tests/run-release-check.sh [--version TAG] [--only linux|macos] [option ...]
#   --version TAG   Install this release. The default is the latest release.
#   option          server, client, both, or hopen. The default is all four.
#   IMAGES          Linux images for the server option. Default: "ubuntu:24.04 debian:12".
#                   The other options use the first image.
#   TART_BASE       The local Tart image to clone. The default is tahoe-base.
#   VM_DNS          A DNS server for the VM. Default 1.1.1.1. Set VM_DNS= to keep the VM's own.
#   --here OPTION   Run one option on this machine, with no sandbox. Only for a
#                   throwaway machine, such as a CI runner: it needs CI=true or
#                   HS_THROWAWAY_MACHINE=1.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
mkdir -p tests/.work

TAG=""
ONLY=""
HERE_OPTION=""
OPTIONS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --version) TAG="$2"; shift 2 ;;
    --only) ONLY="$2"; shift 2 ;;
    --here) HERE_OPTION="$2"; shift 2 ;;
    server | client | both | hopen) OPTIONS+=("$1"); shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
[ "${#OPTIONS[@]}" -gt 0 ] || OPTIONS=(server client both hopen)
read -r -a IMAGE_LIST <<<"${IMAGES:-ubuntu:24.04 debian:12}"
TART_BASE="${TART_BASE:-tahoe-base}"
VM_DNS="${VM_DNS-1.1.1.1}"
status=0
ran=0

# readme_command HEADING prints the command of one option of the Quick start.
readme_command() {
  python3 -I - "$1" <<'PY'
import re, sys
text = open("README.md", encoding="utf-8").read()
part = re.search(r"^### " + re.escape(sys.argv[1]) + r"\n(.*?)(?=^### |^## )", text, re.S | re.M)
block = part and re.search(r"```bash\n(.*?)\n```", part.group(1), re.S)
if not block:
    sys.exit("No command for the option " + sys.argv[1] + " in README.md")
print(block.group(1).strip())
PY
}

CMD_SERVER="$(readme_command "Server machine")" || exit 1
CMD_CLIENT="$(readme_command "Client machine")" || exit 1
CMD_BOTH="$(readme_command "One machine as both")" || exit 1
CMD_HOPEN="$(readme_command "Only hopen")" || exit 1
# Options of the test, after the command of the README: no question, and no
# slow download of the language tools. A container also has no login service.
version_flag=""
[ -z "$TAG" ] || version_flag=" --version ${TAG}"
TEST_FLAGS=" --yes --skip-nvim-tools${version_flag}"
LINUX_FLAGS="${TEST_FLAGS} --skip-login-service"
# The client role has no Neovim and no login service.
CLIENT_FLAGS=" --yes${version_flag}"
# install.sh reads its options after "bash -s --".
CMD_HOPEN_RUN="$CMD_HOPEN"
[ -z "$TAG" ] || CMD_HOPEN_RUN="${CMD_HOPEN} -s -- --version ${TAG}"

# HERDR_LINUX installs the terminal program herdr from its latest release.
HERDR_LINUX='mkdir -p $HOME/.local/bin && curl -fsSL -o $HOME/.local/bin/herdr https://github.com/herdrdev/herdr/releases/latest/download/herdr-linux-$(uname -m | sed s/arm64/aarch64/) && chmod 755 $HOME/.local/bin/herdr'

wanted() { local o; for o in "${OPTIONS[@]}"; do [ "$o" = "$1" ] && return 0; done; return 1; }

# report NAME LOG STATUS prints the FAIL and RESULT lines of a log, and the exit code.
report() {
  grep -E '^(FAIL|RESULT)' "$2" | grep -v '^RESULT pass=' | cut -c1-300
  echo "RESULT $1 pass=$(grep -c '^PASS' "$2") exit=$3 log=$2"
  [ "$3" -eq 0 ] || status=1
  ran=$((ran + 1))
}

# A user with sudo in a fresh Linux container, as on a real server.
# docker exec can start with no file mask, so set the usual one first.
LINUX_PREP="umask 022
apt-get update -qq && apt-get install -y -qq --no-install-recommends sudo ca-certificates curl procps python3 >/dev/null
id tester >/dev/null 2>&1 || { useradd -m -s /bin/bash tester && echo 'tester ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/tester; }"

# as_tester COMMAND prints a command that runs COMMAND as the user tester.
as_tester() { printf 'su - tester -c %q' "export LANG=C.UTF-8; $1"; }

# linux_run NAME IMAGE SCRIPT runs SCRIPT as root in a fresh container.
linux_run() {
  local log="tests/.work/release-check-$1.log"
  docker run --rm --name "hs-release-check-$1-$$" -v "$PWD/tests:/check:ro" "$2" bash -c "set -e
$LINUX_PREP
$3" >"$log" 2>&1
  report "linux $1" "$log" "$?"
}

linux_options() {
  local image first="${IMAGE_LIST[0]}" name
  if wanted server; then
    for image in "${IMAGE_LIST[@]}"; do
      name="server-$(printf '%s' "$image" | tr -c 'a-z0-9' '-')"
      linux_run "$name" "$image" "$(as_tester "${CMD_SERVER}${LINUX_FLAGS} && ${CMD_SERVER}${LINUX_FLAGS} --check && bash /check/tour-release.sh ${TAG}")"
    done
  fi
  if wanted both; then
    # A container has no display, so the client part installs no Ghostty here.
    # The client test of CI presses the real keys of Ghostty.
    linux_run "both" "$first" "$(as_tester "${CMD_BOTH}${LINUX_FLAGS} --no-ghostty && ${CMD_BOTH}${LINUX_FLAGS} --no-ghostty --check && bash /check/tour-release.sh ${TAG}")"
  fi
  if wanted hopen; then
    # The terminal program herdr first, from its release, and then only hopen.
    # The installer of herdr.dev installs the Herdr app, which has no herdr command.
    linux_run "hopen" "$first" "$(as_tester "${HERDR_LINUX} && export PATH=\$HOME/.local/bin:\$PATH && herdr --version && ${CMD_HOPEN_RUN} && bash /check/tour-release.sh ${TAG} --only-hopen")"
  fi
  if wanted client; then
    linux_client "$first"
  fi
}

# linux_client IMAGE: a server container with SSH, and a client container that
# runs the client option of the README against it.
linux_client() {
  local image="$1" net="hs-rc-net-$$" srv="hs-rc-srv-$$" cli="hs-rc-cli-$$" log="tests/.work/release-check-client.log" rc=0 key cmd c
  docker network create "$net" >/dev/null
  docker run -d --rm --name "$srv" --network "$net" --network-alias my-server "$image" sleep 7200 >/dev/null
  docker run -d --rm --name "$cli" --network "$net" "$image" sleep 7200 >/dev/null
  {
    for c in "$srv" "$cli"; do docker exec "$c" bash -c "$LINUX_PREP" || rc=1; done
    docker exec "$srv" bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends openssh-server >/dev/null && mkdir -p /run/sshd && chmod 755 /run/sshd && /usr/sbin/sshd" || rc=1
    docker exec "$srv" bash -c "$(as_tester "${CMD_SERVER}${LINUX_FLAGS}")" || rc=1
    docker exec "$cli" bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends openssh-client >/dev/null" || rc=1
    docker exec -u tester "$cli" bash -c 'umask 077 && mkdir -p ~/.ssh && ssh-keygen -q -t ed25519 -N "" -f ~/.ssh/id_ed25519 && printf "Host my-server\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null\n  LogLevel ERROR\n" >~/.ssh/config' || rc=1
    key="$(docker exec -u tester "$cli" cat /home/tester/.ssh/id_ed25519.pub)"
    docker exec -u tester "$srv" bash -c "umask 077 && mkdir -p ~/.ssh && echo '${key}' >>~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys" || rc=1
    # A container has no display, so the client installs no Ghostty here.
    cmd="${CMD_CLIENT}${CLIENT_FLAGS} --no-ghostty"
    if docker exec "$cli" bash -c "$(as_tester "$cmd")"; then echo "PASS the client option runs"; else echo "FAIL the client option runs"; rc=1; fi
    if docker exec "$cli" bash -c "$(as_tester "$cmd --check")"; then echo "PASS the client check finds nothing to do"; else echo "FAIL the client check finds nothing to do"; rc=1; fi
    if docker exec -u tester "$cli" ssh my-server 'export PATH=$HOME/.local/bin:$PATH; hopen --version' | grep -q 'hopen '; then echo "PASS the client reaches hopen on the server over SSH"; else echo "FAIL the client reaches hopen on the server over SSH"; rc=1; fi
    if docker exec "$cli" bash -c "$(as_tester 'command -v hopen')" >/dev/null 2>&1; then echo "FAIL the client has no hopen"; rc=1; else echo "PASS the client has no hopen"; fi
  } >"$log" 2>&1
  docker rm -f "$srv" "$cli" >/dev/null 2>&1
  docker network rm "$net" >/dev/null 2>&1
  report "linux client" "$log" "$rc"
}

# macos_run NAME SCRIPT runs SCRIPT in a fresh clone of the Tart image.
macos_run() {
  local vm="hs-rc-$1-$$" log="tests/.work/release-check-macos-$1.log" rc=0
  tart clone "$TART_BASE" "$vm"
  tart run "$vm" --no-graphics --dir="check:$PWD/tests:ro" >/dev/null 2>&1 &
  for _ in $(seq 1 40); do tart exec "$vm" true 2>/dev/null && break; sleep 3; done
  [ -z "$VM_DNS" ] || tart exec "$vm" sudo networksetup -setdnsservers Ethernet "$VM_DNS"
  tart exec "$vm" zsh -lc "cp -R '/Volumes/My Shared Files/check' ~/check && $2" >"$log" 2>&1 || rc=$?
  tart stop "$vm" >/dev/null 2>&1
  tart delete "$vm" >/dev/null 2>&1
  report "macos $1" "$log" "$rc"
}

macos_options() {
  if wanted server; then
    macos_run server "${CMD_SERVER}${TEST_FLAGS} && ${CMD_SERVER}${TEST_FLAGS} --check && zsh -lc 'bash ~/check/tour-release.sh ${TAG}'"
  fi
  if wanted both; then
    macos_run both "${CMD_BOTH}${TEST_FLAGS} && ${CMD_BOTH}${TEST_FLAGS} --check && zsh -lc 'bash ~/check/tour-release.sh ${TAG}'"
  fi
  if wanted hopen; then
    macos_run hopen "brew install herdr && ${CMD_HOPEN_RUN} && zsh -lc 'bash ~/check/tour-release.sh ${TAG} --only-hopen'"
  fi
  if wanted client; then
    echo "SKIP macos client: it needs a second machine. The Linux client check covers it."
  fi
}

# here_run OPTION runs one option on this machine, which must be throwaway.
here_run() {
  [ "${CI:-}" = "true" ] || [ "${HS_THROWAWAY_MACHINE:-}" = "1" ] ||
    { echo "--here changes this machine. Use it only on a throwaway machine, with CI=true or HS_THROWAWAY_MACHINE=1." >&2; exit 2; }
  local flags="$TEST_FLAGS" log="tests/.work/release-check-here-$1.log" rc=0
  [ "$(uname -s)" = Darwin ] || flags="$LINUX_FLAGS"
  case "$1" in
    server) bash -c "${CMD_SERVER}${flags} </dev/null && ${CMD_SERVER}${flags} --check </dev/null && bash tests/tour-release.sh ${TAG}" >"$log" 2>&1 || rc=$? ;;
    both) bash -c "${CMD_BOTH}${flags} </dev/null && ${CMD_BOTH}${flags} --check </dev/null && bash tests/tour-release.sh ${TAG}" >"$log" 2>&1 || rc=$? ;;
    hopen)
      if [ "$(uname -s)" = Darwin ]; then
        bash -c "brew install herdr && ${CMD_HOPEN_RUN} && bash tests/tour-release.sh ${TAG} --only-hopen" >"$log" 2>&1 || rc=$?
      else
        bash -c "${HERDR_LINUX} && export PATH=\$HOME/.local/bin:\$PATH && ${CMD_HOPEN_RUN} && bash tests/tour-release.sh ${TAG} --only-hopen" >"$log" 2>&1 || rc=$?
      fi
      ;;
    *) echo "--here takes server, both, or hopen." >&2; exit 2 ;;
  esac
  report "here $1" "$log" "$rc"
  exit "$status"
}
[ -z "$HERE_OPTION" ] || here_run "$HERE_OPTION"

if [ "$ONLY" != macos ]; then
  if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
    linux_options
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
    macos_options
  fi
fi

[ "$ran" -gt 0 ] || { echo "RESULT no sandbox ran"; exit 1; }
exit "$status"
