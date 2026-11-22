#!/usr/bin/env bash
# release.sh builds the files of a hopen release in dist/<tag>.
#
# Usage: tools/release.sh <tag> [--repo owner/name] [--publish|--preflight]
#
# The files are herdspace-<tag>.tar.gz (the scripts and configuration,
# without the tests and the media), bootstrap.sh and install.sh with the tag and
# the repository filled in, hopen-<tag>.tar.gz (hopen and the templates), and
# SHA256SUMS. With --publish, the
# script creates the GitHub release and uploads the files. Before that, it makes
# sure that the commit is the head of main, that the CI checks of its pull
# request passed, and that the tag has no release yet. --preflight runs only
# these checks. A tag with a dash,
# for example 0.2.0-alpha.1, becomes a pre-release. A tag has no v in front.
set -euo pipefail
cd "$(dirname "$0")/.."

TAG=""
REPO=""
PUBLISH=0
PREFLIGHT=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --publish) PUBLISH=1; shift ;;
    --preflight) PREFLIGHT=1; shift ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) TAG="$1"; shift ;;
  esac
done
[ -n "$TAG" ] || { echo "Usage: tools/release.sh <tag> [--repo owner/name] [--publish|--preflight]" >&2; exit 2; }
case "$TAG" in
  [0-9]*) ;;
  *) echo "A tag is a version with no v in front, for example 0.1.1." >&2; exit 2 ;;
esac
if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" || true
fi
[ -n "$REPO" ] || { echo "Give the repository with --repo owner/name." >&2; exit 2; }
# A build for the tests can use files that are not committed yet. A published
# release must hold only committed files, so --publish needs a clean folder.
if [ "$PUBLISH" -eq 1 ] || [ "$PREFLIGHT" -eq 1 ]; then
  if [ -n "$(git status --porcelain)" ]; then
    echo "The folder has changes or untracked files. Commit or remove them before --publish:" >&2
    git status --short >&2
    exit 1
  fi
  # A release is the head of main, after CI, and a published tag never changes.
  # .github/workflows/release.yml compares the published files with the tag.
  git fetch -q origin main --tags
  head="$(git rev-parse HEAD)"
  if [ "$head" != "$(git rev-parse origin/main)" ]; then
    echo "The commit ${head} is not the head of origin/main. Switch to main, and pull." >&2
    exit 1
  fi
  if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    echo "The tag ${TAG} already has a release. A published release does not change. Release a new tag." >&2
    exit 1
  fi
  tagged="$(git rev-parse -q --verify "refs/tags/${TAG}^{commit}" 2>/dev/null)" || tagged=""
  if [ -n "$tagged" ] && [ "$tagged" != "$head" ]; then
    echo "The tag ${TAG} exists and points to ${tagged}, not to ${head}." >&2
    exit 1
  fi
  # The setup must know each older version of an installed file, the hopen of
  # this tag included.
  if ! grep -q "^## \[${TAG}\]" CHANGELOG.md || ! tools/known-hashes.sh --check >/dev/null; then
    echo "bootstrap/known-hashes.tsv does not list the files of ${TAG}. Add the CHANGELOG.md section, run tools/known-hashes.sh, and merge the change." >&2
    exit 1
  fi
  # Main gets each change from a pull request, and CI runs on the pull request.
  # Each check run of its last commit must pass.
  pr_head="$(gh api "repos/${REPO}/commits/${head}/pulls" -q '[.[] | select(.merged_at != null)][0].head.sha' 2>/dev/null)" || pr_head=""
  if [ -z "$pr_head" ]; then
    echo "No merged pull request has the commit ${head}. Merge the release change with a pull request." >&2
    exit 1
  fi
  runs="$(gh api --paginate "repos/${REPO}/commits/${pr_head}/check-runs" -q '.check_runs[] | "\(.conclusion // .status)\t\(.name)"')"
  bad="$(printf '%s\n' "$runs" | awk -F '\t' 'NF && $1 != "success" && $1 != "skipped" && $1 != "neutral"')"
  if [ -z "$runs" ] || [ -n "$bad" ]; then
    echo "The CI checks of the pull request did not all pass:" >&2
    printf '%s\n' "${bad:-no check ran}" >&2
    exit 1
  fi
  echo "Preflight: ${head} is the head of main, its pull request passed $(printf '%s\n' "$runs" | grep -c .) checks, and ${TAG} has no release."
  [ "$PREFLIGHT" -eq 0 ] || exit 0
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
# The full archive gets the same hopen, with the tag in it.
mv "${stage}/hopen" "${out}/hopen.tagged"
rm -rf "$stage"
sed -e "s|@VERSION@|${TAG}|" -e "s|@REPO@|${REPO}|" bootstrap.sh >"${out}/bootstrap.sh"
chmod 755 "${out}/bootstrap.sh"
# The full archive holds each file that git tracks or would track, so a test can
# build it before a commit. The release copies of bootstrap.sh and bin/hopen
# replace the ones in git.
git ls-files -co --exclude-standard | python3 -I -c '
import os, sys, tarfile
tag, out = sys.argv[1], sys.argv[2]
skip = ("tests/", "docs/media/", "dist/")
with tarfile.open(os.path.join(out, f"herdspace-{tag}.tar.gz"), "w:gz") as tar:
    for name in sorted(sys.stdin.read().splitlines()):
        if name.startswith(skip) or not os.path.isfile(name) or name in ("bootstrap.sh", "bin/hopen"):
            continue
        tar.add(name, arcname=f"herdspace-{tag}/{name}")
    tar.add(os.path.join(out, "bootstrap.sh"), arcname=f"herdspace-{tag}/bootstrap.sh")
    tar.add(os.path.join(out, "hopen.tagged"), arcname=f"herdspace-{tag}/bin/hopen")
' "$TAG" "$out"
rm -f "${out}/hopen.tagged"
(
  cd "$out"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum ./*.tar.gz ./*.sh | sed 's|  ./|  |' >SHA256SUMS
  else
    shasum -a 256 ./*.tar.gz ./*.sh | sed 's|  ./|  |' >SHA256SUMS
  fi
)
ls -1 "$out"

# The release notes are the section of CHANGELOG.md for this tag, with a link
# to the install steps at the top. HS_CHANGELOG names another file for tests.
changelog="${HS_CHANGELOG:-CHANGELOG.md}"
notes="dist/${TAG}.notes.md"
section="$(awk -v tag="$TAG" '
  index($0, "## [" tag "]") == 1 { found = 1; next }
  found && (/^## \[/ || /^\[[^]]+\]: /) { exit }
  found { print }
' "$changelog" 2>/dev/null | sed '/./,$!d')" || section=""
if [ -z "$section" ]; then
  if [ "$PUBLISH" -eq 1 ]; then
    echo "${changelog} has no section for ${TAG}. Add \"## [${TAG}] - <date>\" with the changes, and commit it." >&2
    exit 1
  fi
  echo "Note: ${changelog} has no section for ${TAG}, so ${notes} has only the install link." >&2
fi
{
  printf 'To install, follow the [Quick start](https://github.com/%s/blob/%s/README.md#quick-start). The [setup guide](https://github.com/%s/blob/%s/docs/setup.md) has every option.\n' "$REPO" "$TAG" "$REPO" "$TAG"
  [ -z "$section" ] || printf '\n%s\n' "$section"
} >"$notes"
echo "$notes"

if [ "$PUBLISH" -eq 1 ]; then
  pre=""
  case "$TAG" in *-*) pre="--prerelease" ;; esac
  # gh creates a draft, uploads the files, and then publishes it, so the
  # release works with immutable releases turned on.
  gh release create "$TAG" --repo "$REPO" --target "$head" $pre --title "$TAG" --notes-file "$notes" "${out}"/*
fi
