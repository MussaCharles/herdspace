#!/usr/bin/env bash
# sign-tag.sh makes the signed tag of a release, or checks it.
#
# Usage: tools/sign-tag.sh TAG COMMIT   Make the signed tag TAG on COMMIT. If
#                                       TAG exists, check its signature.
#        tools/sign-tag.sh --check      Check that the signing key is in the
#                                       list of release keys.
#
# The tag has an SSH signature. The key is the git setting user.signingkey,
# or HS_SIGNING_KEY: the path of a private or public key file. The list of
# release keys is .github/release-signers (HS_SIGNERS_FILE). Anyone can check
# a tag with this list. See docs/updating.md#sign-the-release-tags.
set -euo pipefail

die() { echo "$*" >&2; exit 1; }
SIGNERS="${HS_SIGNERS_FILE:-.github/release-signers}"
KEY="${HS_SIGNING_KEY:-$(git config --get user.signingkey || true)}"

[ -s "$SIGNERS" ] || die "The list of release keys ${SIGNERS} is missing or empty."

# check_key succeeds if the public key of KEY is in the list.
check_key() {
  local pub
  [ -n "$KEY" ] || die "No signing key. Set it with: git config user.signingkey ~/.ssh/<key>.pub. See docs/updating.md#sign-the-release-tags."
  pub="${KEY%.pub}.pub"
  [ -f "$pub" ] || die "The public key ${pub} does not exist."
  grep -qF -- "$(awk '{print $1" "$2}' "$pub")" "$SIGNERS" || die "The key ${pub} is not in ${SIGNERS}."
}

verify() {
  git -c gpg.format=ssh -c gpg.ssh.allowedSignersFile="$SIGNERS" tag -v "$1" >/dev/null 2>&1
}

if [ "${1:-}" = "--check" ]; then
  check_key
  echo "The signing key is in ${SIGNERS}."
  exit 0
fi

TAG="${1:-}"
COMMIT="${2:-}"
[ -n "$TAG" ] && [ -n "$COMMIT" ] || die "Usage: tools/sign-tag.sh TAG COMMIT"
if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
  verify "$TAG" || die "The tag ${TAG} exists, but it has no valid signature of a key in ${SIGNERS}."
  [ "$(git rev-parse "${TAG}^{commit}")" = "$(git rev-parse "${COMMIT}^{commit}")" ] || die "The tag ${TAG} does not point to ${COMMIT}."
  echo "The tag ${TAG} has a valid signature."
  exit 0
fi
check_key
git -c gpg.format=ssh -c user.signingkey="${KEY%.pub}.pub" tag -s "$TAG" -m "herdspace ${TAG}" "$COMMIT"
verify "$TAG" || { git tag -d "$TAG" >/dev/null; die "The new tag ${TAG} has no valid signature, so the script removed it."; }
echo "Made the signed tag ${TAG}."
