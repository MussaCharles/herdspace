#!/usr/bin/env bash
# release.sh builds the files of a hopen release in dist/<tag>.
#
# Usage: tools/release.sh <tag> [--repo owner/name] [--publish]
#
# The files are herdr-bootstrap-<tag>.tar.gz (the scripts and configuration,
# without the tests and the media), bootstrap.sh and install.sh with the tag and
# the repository filled in, hopen-<tag>.tar.gz (hopen and the templates), and
# SHA256SUMS. With --publish, the
# script creates the GitHub release and uploads the files. A tag with a dash,
# for example v0.1.0-alpha.2, becomes a pre-release.
set -euo pipefail
cd "$(dirname "$0")/.."

TAG=""
REPO=""
PUBLISH=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --publish) PUBLISH=1; shift ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) TAG="$1"; shift ;;
  esac
done
[ -n "$TAG" ] || { echo "Usage: tools/release.sh <tag> [--repo owner/name] [--publish]" >&2; exit 2; }
case "$TAG" in
  v[0-9]*) ;;
  *) echo "A tag starts with v and a number, for example v0.1.0." >&2; exit 2 ;;
esac
if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" || true
fi
[ -n "$REPO" ] || { echo "Give the repository with --repo owner/name." >&2; exit 2; }
# A build for the tests can use files that are not committed yet. A published
# release must hold only committed files, so --publish needs a clean folder.
if [ "$PUBLISH" -eq 1 ] && [ -n "$(git status --porcelain)" ]; then
  echo "The folder has changes or untracked files. Commit or remove them before --publish:" >&2
  git status --short >&2
  exit 1
fi

out="dist/${TAG}"
stage="${out}/hopen-${TAG}"
rm -rf "$out"
mkdir -p "${stage}/templates"
sed "s|^HOPEN_VERSION=.*|HOPEN_VERSION=\"${TAG}\"|" bin/hopen >"${stage}/hopen"
chmod 755 "${stage}/hopen"
cp config/templates/*.layout "${stage}/templates/"
sed -e "s|@VERSION@|${TAG}|" -e "s|@REPO@|${REPO}|" install.sh >"${out}/install.sh"
chmod 755 "${out}/install.sh"
COPYFILE_DISABLE=1 tar -czf "${out}/hopen-${TAG}.tar.gz" -C "$out" "hopen-${TAG}"
rm -rf "$stage"
sed -e "s|@VERSION@|${TAG}|" -e "s|@REPO@|${REPO}|" bootstrap.sh >"${out}/bootstrap.sh"
chmod 755 "${out}/bootstrap.sh"
# The full archive holds each file that git tracks or would track, so a test can
# build it before a commit. The release copy of bootstrap.sh replaces the one in git.
git ls-files -co --exclude-standard | python3 -I -c '
import os, sys, tarfile
tag, out = sys.argv[1], sys.argv[2]
skip = ("tests/", "docs/media/", "dist/")
with tarfile.open(os.path.join(out, f"herdr-bootstrap-{tag}.tar.gz"), "w:gz") as tar:
    for name in sorted(sys.stdin.read().splitlines()):
        if name.startswith(skip) or not os.path.isfile(name) or name == "bootstrap.sh":
            continue
        tar.add(name, arcname=f"herdr-bootstrap-{tag}/{name}")
    tar.add(os.path.join(out, "bootstrap.sh"), arcname=f"herdr-bootstrap-{tag}/bootstrap.sh")
' "$TAG" "$out"
(
  cd "$out"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum ./*.tar.gz ./*.sh | sed 's|  ./|  |' >SHA256SUMS
  else
    shasum -a 256 ./*.tar.gz ./*.sh | sed 's|  ./|  |' >SHA256SUMS
  fi
)
ls -1 "$out"

if [ "$PUBLISH" -eq 1 ]; then
  pre=""
  case "$TAG" in *-*) pre="--prerelease" ;; esac
  if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    gh release upload "$TAG" --repo "$REPO" --clobber "${out}"/*
  else
    gh release create "$TAG" --repo "$REPO" --target main $pre --title "$TAG" --generate-notes "${out}"/*
  fi
fi
