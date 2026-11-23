#!/usr/bin/env bash
# run-upgrade.sh runs tests/test-upgrade.sh in a fresh container for each
# older release: it installs the release, and updates to this folder.
# Usage: tests/run-upgrade.sh [tag ...]   Default: the last 3 tagged releases in CHANGELOG.md.
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
    while read -r t; do git rev-parse -q --verify "refs/tags/$t" >/dev/null && echo "$t"; done | head -n 3)
fi
base="${IMAGE:-ubuntu:24.04}"
tag_name="hb-upgrade-$(printf '%s' "$base" | tr -c 'a-z0-9' '-')"
# shellcheck disable=SC2046 # build_flags prints one option or nothing.
docker build -q $(build_flags) --build-arg "BASE=${base}" -f tests/Dockerfile.linux -t "$tag_name" . >tests/.work/upgrade-build.log 2>&1 ||
  { echo "FAIL build ${base}"; tail -n 20 tests/.work/upgrade-build.log; exit 1; }
apt_cache_args "$base"
status=0
for tag in "$@"; do
  log="tests/.work/upgrade-${tag}.log"
  docker run --rm --name "${tag_name}-${tag//./-}-$$" ${APT_CACHE[@]+"${APT_CACHE[@]}"} "$tag_name" \
    tests/test-upgrade.sh "$tag" --skip-login-service --skip-nvim-tools >"$log" 2>&1
  rc=$?
  grep -E '^(PASS|FAIL|RESULT)' "$log" | cut -c1-200
  echo "${tag}: exit ${rc}"
  [ "$rc" -eq 0 ] || status=1
done
remove_images "$tag_name"
exit "$status"
