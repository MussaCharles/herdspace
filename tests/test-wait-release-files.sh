#!/usr/bin/env bash
# test-wait-release-files.sh runs tools/wait-release-files.sh with a stub curl:
# files that answer at once, files that answer after two errors, a
# releases/latest link that is late, and a file that never answers.
# It needs bash, and no network.
# Usage: tests/test-wait-release-files.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }
contains() { case "$1" in *"$2"*) pass "$3" ;; *) fail "$3: wanted [$2] in [${1:0:300}]" ;; esac; }

mkdir -p "$tmp/bin"
# The stub curl fails the first $FAILS calls. The address of SHA256SUMS
# prints the list of $LIST_TAG. An address with "never" always fails.
cat >"$tmp/bin/curl" <<'STUB'
#!/bin/sh
n=$(cat "$COUNT" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" >"$COUNT"
[ "$n" -gt "$FAILS" ] || exit 22
for a in "$@"; do url="$a"; done
case "$url" in
  *never*) exit 22 ;;
  */latest/download/SHA256SUMS) printf 'aaa  herdspace-%s.tar.gz\n' "$LATEST_TAG" ;;
  */SHA256SUMS) printf 'aaa  bootstrap.sh\nbbb  herdspace-1.0.0.tar.gz\nccc  %s\n' "${EXTRA:-install.sh}" ;;
esac
exit 0
STUB
chmod 755 "$tmp/bin/curl"
run() { rm -f "$tmp/count"; COUNT="$tmp/count" PATH="$tmp/bin:$PATH" WAIT_SECONDS=0 WAIT_TRIES=4 "$ROOT/tools/wait-release-files.sh" 1.0.0 owner/repo "$@" 2>&1; }

out="$(FAILS=0 LATEST_TAG=1.0.0 run --latest)"; rc=$?
[ "$rc" -eq 0 ] && contains "$out" "The files of 1.0.0 download." "files that answer at once pass" || fail "files that answer at once pass: rc=$rc $out"
out="$(FAILS=2 LATEST_TAG=1.0.0 run)"; rc=$?
[ "$rc" -eq 0 ] && pass "files that answer after two errors pass" || fail "files that answer after two errors pass: rc=$rc $out"
contains "$out" "Waiting for SHA256SUMS of 1.0.0 (try 1 of 4)." "the wait names the file and the try"
out="$(FAILS=0 LATEST_TAG=0.9.0 run --latest)"; rc=$?
[ "$rc" -ne 0 ] && pass "a releases/latest link that points to an older tag fails at the end" || fail "a late releases/latest link fails at the end"
contains "$out" "releases/latest of 1.0.0 still does not download" "the error names releases/latest"
out="$(FAILS=0 LATEST_TAG=0.9.0 run)"; rc=$?
[ "$rc" -eq 0 ] && pass "with no --latest, the releases/latest link does not count" || fail "with no --latest, the releases/latest link does not count: $out"
out="$(FAILS=0 EXTRA=never.tar.gz LATEST_TAG=1.0.0 run)"; rc=$?
[ "$rc" -ne 0 ] && contains "$out" "never.tar.gz of 1.0.0 still does not download" "a file that never answers fails with its name" || fail "a file that never answers fails: rc=$rc"

echo "RESULT failures=${failures}"
[ "$failures" -eq 0 ]
