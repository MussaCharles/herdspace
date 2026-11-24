#!/usr/bin/env bash
# run-rollback.sh runs tests/test-rollback.sh in a fresh container: it installs
# a release, goes back to the release before it with "herdspace update
# --version", and goes forward again.
# Usage: tests/run-rollback.sh [NEW OLD]   Default: the last 2 tagged releases in CHANGELOG.md.
# Set IMAGE to change the base image. Default: ubuntu:24.04. Do not run it at
# the same time as tests/run-linux.sh: both use the same apt download cache.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
# shellcheck source=tests/lib-docker.sh
source tests/lib-docker.sh
mkdir -p tests/.work
if [ "$#" -eq 0 ]; then
  # Skip a version with no git tag yet, for example while its release PR is open.
  # shellcheck disable=SC2046 # One word for each tag.
  set -- $(sed -n 's/^## \[\([0-9][^]-]*\)\] - .*/\1/p' CHANGELOG.md |
    while read -r t; do git rev-parse -q --verify "refs/tags/$t" >/dev/null && echo "$t"; done | head -n 2)
fi
[ "$#" -eq 2 ] || { echo "FAIL need two release tags: NEW OLD"; exit 1; }
new="$1"
old="$2"
base="${IMAGE:-ubuntu:24.04}"
tag_name="hb-rollback-$(printf '%s' "$base" | tr -c 'a-z0-9' '-')"
# shellcheck disable=SC2046 # build_flags prints one option or nothing.
docker build -q $(build_flags) --build-arg "BASE=${base}" -f tests/Dockerfile.linux -t "$tag_name" . >tests/.work/rollback-build.log 2>&1 ||
  { echo "FAIL build ${base}"; tail -n 20 tests/.work/rollback-build.log; exit 1; }
apt_cache_args "$base"
log="tests/.work/rollback-${new}-${old}.log"
docker run --rm --name "${tag_name}-$$" ${APT_CACHE[@]+"${APT_CACHE[@]}"} "$tag_name" \
  tests/test-rollback.sh "$new" "$old" --skip-login-service --skip-nvim-tools >"$log" 2>&1
rc=$?
grep -E '^(PASS|FAIL|RESULT)' "$log" | cut -c1-200
echo "${new} to ${old} and back: exit ${rc}"
remove_images "$tag_name"
exit "$rc"
