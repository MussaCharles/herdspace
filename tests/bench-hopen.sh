#!/usr/bin/env bash
# bench-hopen.sh measures how long hopen takes with a list of many projects. It
# needs a finished server setup with a running Herdr. tests/run-linux.sh runs it
# in a container. It creates its own sessions and folders, and removes them.
#
# Usage: tests/bench-hopen.sh [count]   Default: 20 projects.
set -uo pipefail
export PATH="${HOME}/.local/bin:${PATH}"
count="${1:-20}"
work="$(mktemp -d)"
now() { python3 -c 'import time; print(time.time())'; }
since() { python3 -c 'import sys, time; print(f"{time.time() - float(sys.argv[1]):.1f}")' "$1"; }
workspace_count() { HERDR_SESSION="$1" herdr workspace list | python3 -c 'import json, sys; print(len(json.load(sys.stdin)["result"]["workspaces"]))'; }
stop_session() { herdr session stop "$1" >/dev/null 2>&1; sleep 1; herdr session delete "$1" >/dev/null 2>&1; }
cleanup() {
  stop_session hb-bench
  stop_session hb-bench-code
  rm -rf "${work:?}"
}
trap cleanup EXIT

# One folder for each project, and one list.
folders=""
for i in $(seq 1 "$count"); do
  mkdir -p "${work}/p${i}"
  folders="${folders}${folders:+, }{ \"path\": \"./p${i}\" }"
done
printf '{ "folders": [ %s ] }\n' "$folders" >"${work}/bench.code-workspace"

failures=0
# measure SESSION TEMPLATE prints the seconds of a first and a second run.
measure() {
  local session="$1" template="$2" start first second
  start="$(now)"
  hopen "$session" --file "${work}/bench.code-workspace" --template "$template" --no-attach >/dev/null 2>&1
  first="$(since "$start")"
  start="$(now)"
  hopen "$session" --file "${work}/bench.code-workspace" --template "$template" --no-attach >/dev/null 2>&1
  second="$(since "$start")"
  echo "RESULT bench ${template} first=${first}s second=${second}s projects=${count}"
  # The parent workspace and one workspace for each project.
  if [ "$(workspace_count "$session")" -ne $((count + 1)) ]; then
    echo "FAIL bench ${template}: $(workspace_count "$session") workspaces, wanted $((count + 1))"
    failures=$((failures + 1))
  fi
}

measure hb-bench plain
measure hb-bench-code code
[ "$failures" -eq 0 ]
