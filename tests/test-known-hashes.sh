#!/usr/bin/env bash
# test-known-hashes.sh runs tools/known-hashes.sh in a temporary repository. It
# checks that the list has each older version of a file, also a version that
# only a merge commit made, and not the version of HEAD.
# It needs git and Python 3, and no network.
# Usage: tests/test-known-hashes.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }
sha() { printf '%s' "$1" | shasum -a 256 | cut -c1-64; }
listed() { grep -q "^bin/herdspace	$(sha "$1")$" "$tmp/repo/bootstrap/known-hashes.tsv"; }

repo="$tmp/repo"
mkdir -p "$repo/tools" "$repo/bin" "$repo/bootstrap"
cp "$ROOT/tools/known-hashes.sh" "$repo/tools/"
cd "$repo" || exit 1
g() { git -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@" >/dev/null; }
g init -q -b main
printf '# Changelog\n' >CHANGELOG.md
printf 'v1\n' >bin/herdspace
g add -A && g commit -q -m one
g checkout -q -b side
printf 'side\n' >bin/herdspace
g commit -q -am side
g checkout -q main
printf 'main\n' >bin/herdspace
g commit -q -am main
# A merge with a conflict, resolved by hand: this version exists only in the
# merge commit.
g merge -q side 2>/dev/null && fail "the merge has a conflict"
[ "$(git rev-list --count --merges HEAD)" = 0 ] || fail "no merge commit yet"
printf 'merged\n' >bin/herdspace
g add bin/herdspace && g commit -q -m merge
[ "$(git rev-list --count --merges HEAD)" = 1 ] && pass "the version comes from a merge commit" || fail "the version comes from a merge commit"
printf 'head\n' >bin/herdspace
g commit -q -am head

tools/known-hashes.sh >/dev/null || fail "the tool runs"
listed $'v1\n' && pass "the first version is listed" || fail "the first version is listed"
listed $'side\n' && pass "a version of a branch is listed" || fail "a version of a branch is listed"
listed $'main\n' && pass "a version of main is listed" || fail "a version of main is listed"
listed $'merged\n' && pass "a version that only a merge commit made is listed" || fail "a version that only a merge commit made is listed"
listed $'head\n' && fail "the version of HEAD is not listed" || pass "the version of HEAD is not listed"
tools/known-hashes.sh --check >/dev/null && pass "--check passes after a write" || fail "--check passes after a write"

echo "RESULT failures=${failures}"
[ "$failures" -eq 0 ]
