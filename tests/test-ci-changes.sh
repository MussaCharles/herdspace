#!/usr/bin/env bash
# test-ci-changes.sh checks tools/ci-changes.sh in a temporary git repository:
# a change of only docs gives code=false, and every other change gives code=true.
# Usage: tests/test-ci-changes.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
mkdir -p "$tmp/repo"
cd "$tmp/repo" || exit 1
git init -q && git config user.email t@example.com && git config user.name t && git config core.hooksPath /dev/null
mkdir -p docs bin && echo a >README.md && echo a >docs/a.md && echo a >bin/x && git add . && git commit -qm base
base="$(git rev-parse HEAD)"

# result FILES... commits a change of FILES on top of base and prints the answer.
result() {
  git checkout -q "$base" 2>/dev/null
  local f
  for f in "$@"; do mkdir -p "$(dirname "$f")"; echo "$RANDOM" >>"$f"; done
  git add -A -f . && git commit -qm change
  GITHUB_OUTPUT="$tmp/out" EVENT=pull_request BASE="$base" HEAD="$(git rev-parse HEAD)" "$ROOT/tools/ci-changes.sh" >/dev/null
  tail -n 1 "$tmp/out"
}
check() {
  if [ "$1" = "$2" ]; then echo "PASS $3"; else echo "FAIL $3: $1"; failures=$((failures + 1)); fi
}
check "$(result README.md docs/a.md LICENSE)" code=false "Markdown, docs, and LICENSE only skip the long jobs"
check "$(result docs/media/x.gif)" code=false "a file in docs/ only skips the long jobs"
check "$(result README.md bin/x)" code=true "a change of code runs the long jobs"
check "$(result .github/workflows/ci.yml)" code=true "a change of a workflow runs the long jobs"
GITHUB_OUTPUT="$tmp/out" EVENT=schedule "$ROOT/tools/ci-changes.sh" >/dev/null
check "$(tail -n 1 "$tmp/out")" code=true "the weekly run runs the long jobs"
echo "RESULT failures=${failures}"
exit $((failures > 0))
