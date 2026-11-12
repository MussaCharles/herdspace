#!/usr/bin/env bash
# ci-changes.sh writes code=true or code=false to GITHUB_OUTPUT for the CI
# workflow. code=false means that a pull request changes only Markdown files,
# docs/, or LICENSE. Each other event, and each other change, gives code=true.
# Usage: EVENT=... BASE=... HEAD=... tools/ci-changes.sh
set -euo pipefail
out="${GITHUB_OUTPUT:-/dev/stdout}"
if [ "${EVENT:-}" != pull_request ] || [ -z "${BASE:-}" ] || [ -z "${HEAD:-}" ]; then
  echo "code=true" >>"$out"
  exit 0
fi
files="$(git diff --name-only "$BASE" "$HEAD")"
printf 'Changed files:\n%s\n' "$files"
if [ -n "$files" ] && ! printf '%s\n' "$files" | grep -qvE '(\.md$|^docs/|^LICENSE$)'; then
  echo "Only docs changed. The long jobs skip their steps."
  echo "code=false" >>"$out"
else
  echo "code=true" >>"$out"
fi
