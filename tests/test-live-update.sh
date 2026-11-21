#!/usr/bin/env bash
# test-live-update.sh updates herdspace while a Herdr session runs a program,
# as a person does. It installs the latest published release, starts a session
# with a long program in a pane, and runs the setup of this folder from a copy
# with a changed config.toml, as a next release with a new configuration. The
# server, the program, and the panes must stay, and the session must get the
# new configuration with no restart.
# Usage: tests/test-live-update.sh [setup options]   It runs in a test container.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
failures=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }
SESSION=live-update
export PATH="${HOME}/.local/bin:${PATH}"
REPO="${HS_REPO:-MussaCharles/herdspace}"

echo "== the latest release"
curl -fsSL "https://github.com/${REPO}/releases/latest/download/bootstrap.sh" | bash -s -- server "$@" >/tmp/live-old.log 2>&1 || { tail -n 20 /tmp/live-old.log; fail "the latest release installs"; }

HERDR_SESSION="$SESSION" nohup herdr server >/dev/null 2>&1 &
server_pid=$!
for _ in $(seq 1 40); do
  herdr --session "$SESSION" workspace list 2>/dev/null | grep -q workspace_list && break
  sleep 0.25
done
created="$(herdr --session "$SESSION" workspace create --cwd /tmp --label live 2>&1)"
pane="$(printf '%s' "$created" | python3 -I -c '
import json, sys
def find(value):
    if isinstance(value, dict):
        for key, item in value.items():
            if key == "pane_id" and isinstance(item, str):
                return item
            found = find(item)
            if found:
                return found
    if isinstance(value, list):
        for item in value:
            found = find(item)
            if found:
                return found
    return None
print(find(json.load(sys.stdin)) or "")
' 2>/dev/null)"
[ -n "$pane" ] || { echo "$created"; fail "a workspace with a pane starts"; }
herdr --session "$SESSION" pane run "$pane" "sleep 86400" >/dev/null 2>&1
for _ in $(seq 1 40); do program_pid="$(pgrep -f 'sleep 86400' | head -n 1)"; [ -n "$program_pid" ] && break; sleep 0.25; done
[ -n "${program_pid:-}" ] && pass "a program runs in the session" || fail "a program runs in the session"
panes_before="$(herdr --session "$SESSION" pane list 2>/dev/null | python3 -I -c 'import json, sys; print(len(json.load(sys.stdin).get("result", {}).get("panes", [])))' 2>/dev/null)"

echo "== the update"
next="$(mktemp -d)/herdspace"
cp -R . "$next"
printf '\n# A new line of the next release.\n' >>"${next}/config/herdr/config.toml"
"${next}/bootstrap.sh" server "$@" >/tmp/live-new.log 2>&1 || { tail -n 20 /tmp/live-new.log; fail "the update runs"; }

kill -0 "$server_pid" 2>/dev/null && pass "the server keeps running" || fail "the server keeps running"
[ -n "${program_pid:-}" ] && kill -0 "$program_pid" 2>/dev/null && pass "the program keeps running" || fail "the program keeps running"
panes_after="$(herdr --session "$SESSION" pane list 2>/dev/null | python3 -I -c 'import json, sys; print(len(json.load(sys.stdin).get("result", {}).get("panes", [])))' 2>/dev/null)"
[ -n "$panes_before" ] && [ "$panes_before" = "$panes_after" ] && pass "the session keeps its ${panes_after} panes" || fail "the session keeps its panes: ${panes_before} ${panes_after}"
grep -q "Session ${SESSION}: the new Herdr configuration is active" /tmp/live-new.log && pass "the session gets the new configuration" || { grep -i 'session' /tmp/live-new.log | tail -n 5; fail "the session gets the new configuration"; }
grep -q 'A new line of the next release' "${HOME}/.config/herdr/config.toml" && pass "the new config.toml is installed" || fail "the new config.toml is installed"

herdr session stop "$SESSION" >/dev/null 2>&1 || true
echo "RESULT live-update failures=${failures}"
exit $((failures > 0))
