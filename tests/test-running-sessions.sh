#!/usr/bin/env bash
# test-running-sessions.sh checks the step that updates running Herdr sessions,
# with a stub herdr: a changed config.toml reaches each running session with
# reload-config, a session with an older Herdr gets a note, and no step stops
# a session.
# Usage: tests/test-running-sessions.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }

# run_step NAME CHANGE OLD: CHANGE 1 changes config.toml during the step. OLD
# names the session that runs Herdr 0.9.4. The installed Herdr is 0.9.5. The
# stub logs each call to $HOME/calls.
run_step() {
  local home="${tmp}/$1"
  mkdir -p "${home}/bin" "${home}/.config/herdr"
  echo 'old = true' >"${home}/.config/herdr/config.toml"
  cat >"${home}/bin/herdr" <<STUB
#!/bin/sh
echo "\$*" >>"\$HOME/calls"
case "\$*" in
  --version) echo "herdr 0.9.5" ;;
  "session list --json") echo '{"sessions":[{"name":"default","running":true},{"name":"web","running":true},{"name":"off","running":false}]}' ;;
  "--session $3 status server") printf 'status: running\nversion: 0.9.4\n' ;;
  "--session "*" status server") printf 'status: running\nversion: 0.9.5\n' ;;
  *"server reload-config") echo '{"result":{"diagnostics":[],"status":"applied"}}' ;;
esac
STUB
  chmod 755 "${home}/bin/herdr"
  HOME="$home" PATH="${home}/bin:/usr/bin:/bin" REPO_ROOT="$ROOT" CHANGE="$2" bash -c '
    source "$REPO_ROOT/bootstrap/lib/common.sh"
    source "$REPO_ROOT/bootstrap/lib/server.sh"
    MODE=apply
    HERDR_CONFIG_BEFORE="$(file_sha "$HOME/.config/herdr/config.toml")"
    [ "$CHANGE" = 0 ] || echo "new = true" >"$HOME/.config/herdr/config.toml"
    update_running_sessions
  ' 2>&1
}

out="$(run_step changed 1 none)"
calls="$(cat "${tmp}/changed/calls")"
case "$calls" in *"--session default server reload-config"*) pass "a changed configuration reaches the default session" ;; *) fail "a changed configuration reaches the default session: $calls" ;; esac
case "$calls" in *"--session web server reload-config"*) pass "a changed configuration reaches a named session" ;; *) fail "a changed configuration reaches a named session: $calls" ;; esac
case "$calls" in *"--session off "*) fail "a stopped session gets no call: $calls" ;; *) pass "a stopped session gets no call" ;; esac
case "$calls" in *stop*) fail "the step stops no session: $calls" ;; *) pass "the step stops no session" ;; esac
case "$out" in *"Session web: the new Herdr configuration is active"*) pass "the output names each reloaded session" ;; *) fail "the output names each reloaded session: $out" ;; esac
case "$out" in *"older Herdr"*) fail "no note when each session runs the installed Herdr: $out" ;; *) pass "no note when each session runs the installed Herdr" ;; esac

out="$(run_step same 0 web)"
calls="$(cat "${tmp}/same/calls")"
case "$calls" in *reload-config*) fail "an unchanged configuration needs no reload: $calls" ;; *) pass "an unchanged configuration needs no reload" ;; esac
case "$out" in *"older Herdr than 0.9.5: web."*) pass "a session with an older Herdr gets a note" ;; *) fail "a session with an older Herdr gets a note: $out" ;; esac
case "$out" in *"herdr session stop <name>"*) pass "the note says how to restart a session" ;; *) fail "the note says how to restart a session: $out" ;; esac

echo "RESULT failures=${failures}"
exit $((failures > 0))
