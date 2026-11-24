#!/usr/bin/env bash
# test-rollback.sh installs a newer release, goes back to an older release with
# "herdspace update --version", and goes forward again. Each step must leave
# no file that a --check of the target release counts as changed: the setup
# asked no question about a file that herdspace wrote, and kept no file.
# Usage: tests/test-rollback.sh NEW OLD [setup options]   It runs in a test container.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
failures=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }
NEW="$1"
OLD="$2"
shift 2
REPO="${HS_REPO:-MussaCharles/herdspace}"
STATE="${HOME}/.local/share/herdspace"
export PATH="${HOME}/.local/bin:${PATH}"

# differs TAG prints the files that a --check of the release TAG counts as changed.
differs() {
  local tag="$1"
  shift
  bash "${STATE}/${tag}/bootstrap.sh" server --check "$@" 2>&1 | sed -n 's/^ *\[diff\] \(.*\) differs from this repository$/\1/p'
}

echo "== install ${NEW}"
command -v curl >/dev/null || { sudo apt-get update -qq && sudo apt-get install -y -qq curl >/dev/null; } >/tmp/rollback-curl.log 2>&1
if ! curl -fsSL "https://github.com/${REPO}/releases/download/${NEW}/bootstrap.sh" | bash -s -- server "$@" >/tmp/rollback-new.log 2>&1; then
  tail -n 20 /tmp/rollback-new.log
  fail "${NEW} installs"
  echo "RESULT rollback-${NEW}-${OLD} failures=${failures}"
  exit 1
fi
pass "${NEW} installs"
[ "$(cat "${STATE}/version")" = "$NEW" ] && pass "the installed version is ${NEW}" || fail "the installed version is ${NEW}"

echo "== go back to ${OLD}"
# The command of this folder: the installed release may be too old to know --version.
out="$(./bin/herdspace update --version "$OLD" </dev/null 2>&1)"
rc=$?
[ "$rc" -eq 0 ] && pass "update --version ${OLD} runs" || { echo "$out" | tail -n 20; fail "update --version ${OLD} runs: exit ${rc}"; }
case "$out" in *"Going back from herdspace ${NEW} to the older release ${OLD}"*) pass "the update says that it goes back" ;; *) fail "the update says that it goes back: ${out:0:300}" ;; esac
[ "$(cat "${STATE}/version")" = "$OLD" ] && pass "the installed version is ${OLD}" || fail "the installed version is ${OLD}: $(cat "${STATE}/version")"
out="$(differs "$OLD" "$@")"
[ -z "$out" ] && pass "after going back, no file differs from ${OLD}" || fail "after going back, no file differs from ${OLD}: ${out}"
out="$(./bin/herdspace update --version "$OLD" </dev/null 2>&1)"
case "$out" in *"installed already. Nothing to change"*) pass "a second run says that nothing changes" ;; *) fail "a second run says that nothing changes: ${out:0:300}" ;; esac

echo "== go forward to ${NEW}"
out="$(./bin/herdspace update --version "$NEW" </dev/null 2>&1)"
rc=$?
[ "$rc" -eq 0 ] && pass "update --version ${NEW} runs" || { echo "$out" | tail -n 20; fail "update --version ${NEW} runs: exit ${rc}"; }
[ "$(cat "${STATE}/version")" = "$NEW" ] && pass "the installed version is ${NEW} again" || fail "the installed version is ${NEW} again"
out="$(differs "$NEW" "$@")"
[ -z "$out" ] && pass "after going forward, no file differs from ${NEW}" || fail "after going forward, no file differs from ${NEW}: ${out}"

echo "RESULT rollback-${NEW}-${OLD} failures=${failures}"
exit $((failures > 0))
