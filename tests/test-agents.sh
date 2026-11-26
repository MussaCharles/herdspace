#!/usr/bin/env bash
# test-agents.sh checks which agents get the Herdr integration in the server
# setup, with stub herdr and agent commands in a temporary home folder: the
# command names of the Herdr registry, the folder that each integration needs,
# and the status line of an experimental integration.
# It needs bash, and no network.
# Usage: tests/test-agents.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }
contains() { case "$1" in *"$2"*) pass "$3" ;; *) fail "$3: wanted [$2] in [${1:0:400}]" ;; esac; }
lacks() { case "$1" in *"$2"*) fail "$3: found [$2]" ;; *) pass "$3" ;; esac; }

home="$tmp/home"
bin="$tmp/bin"
mkdir -p "$home" "$bin"
# The stub herdr logs each install, and reports each logged agent as current.
cat >"$bin/herdr" <<'STUB'
#!/bin/sh
case "$1 $2" in
  "integration install") echo "$3" >>"$HERDR_LOG" ;;
  "integration status")
    [ -f "$HERDR_LOG" ] || exit 0
    while read -r a; do
      if [ "$a" = letta ]; then echo "letta (experimental): current (v1) (x)"; else echo "$a: current (v1) (x)"; fi
    done <"$HERDR_LOG" ;;
  "--skill "*) echo "skill text" ;;
esac
exit 0
STUB
chmod 755 "$bin/herdr"
cmd() { printf '#!/bin/sh\nexit 0\n' >"$bin/$1"; chmod 755 "$bin/$1"; }

# claude: command and folder. cursor: only the Cursor editor command and a
# folder. kilo: the second command name. letta: an experimental status line.
# qwen: a command with no folder. agy: Antigravity CLI.
cmd claude; mkdir -p "$home/.claude"
cmd cursor; mkdir -p "$home/.cursor"
cmd kilo-code; mkdir -p "$home/.config/kilo"
cmd letta; mkdir -p "$home/.letta"
cmd qwen
cmd agy; mkdir -p "$home/.gemini/config"

run() {
  HOME="$home" PATH="$bin:/usr/bin:/bin" HERDR_LOG="$tmp/installs" NO_COLOR=1 bash -c '
    export REPO_ROOT="$1"
    source "$1/bootstrap/lib/common.sh"
    source "$1/bootstrap/lib/server.sh"
    '"$1" _ "$ROOT" 2>&1
}

out="$(run 'agents_ready && echo READY || echo NOT_READY')"
contains "$out" NOT_READY "with no integration, the agents step is not done"
out="$(run install_agents)"
installs="$(tr '\n' ' ' <"$tmp/installs" 2>/dev/null)"
contains " $installs" " claude " "claude gets the integration"
contains " $installs" " kilo " "kilo gets the integration through the kilo-code command"
contains " $installs" " letta " "letta gets the integration"
contains " $installs" " antigravity-cli " "Antigravity CLI gets the integration through agy"
lacks " $installs" " cursor " "the Cursor editor command alone gets no Cursor agent integration"
lacks " $installs" " qwen " "an agent with no folder gets no integration"
contains "$out" "Start qwen one time" "the setup asks to start an agent with no folder"
out="$(run 'agents_ready && echo READY || echo NOT_READY')"
contains "$out" READY "after the install, the agents step is done, also with an experimental status line"
lacks "$out" NOT_READY "after the install, the agents step is done"

cmd cursor-agent
: >"$tmp/installs"
run install_agents >/dev/null
contains " $(tr '\n' ' ' <"$tmp/installs") " " cursor " "cursor-agent with the folder gets the Cursor integration"

echo "RESULT failures=${failures}"
[ "$failures" -eq 0 ]
