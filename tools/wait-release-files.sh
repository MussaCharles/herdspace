#!/usr/bin/env bash
# wait-release-files.sh waits until the files of a published release download.
# Right after a publish, the download addresses and the releases/latest link
# can answer with an error for a short time. The Release check runs it before
# it installs the release.
#
# Usage: tools/wait-release-files.sh TAG REPO [--latest]
#   --latest  Also wait until releases/latest points to TAG.
# WAIT_TRIES (default 20) and WAIT_SECONDS (default 15) set the retries.
set -uo pipefail
TAG="${1:?Usage: tools/wait-release-files.sh TAG REPO [--latest]}"
REPO="${2:?Usage: tools/wait-release-files.sh TAG REPO [--latest]}"
LATEST=0
[ "${3:-}" != --latest ] || LATEST=1
tries="${WAIT_TRIES:-20}"
pause="${WAIT_SECONDS:-15}"
base="https://github.com/${REPO}/releases"

# ready prints nothing and is true when each file downloads. Else it prints the
# first file that does not.
ready() {
  local sums name
  sums="$(curl -fsSL "${base}/download/${TAG}/SHA256SUMS" 2>/dev/null)" || { echo SHA256SUMS; return 1; }
  for name in $(awk '{ sub(/^\*/, "", $2); print $2 }' <<<"$sums"); do
    curl -fsSL -o /dev/null "${base}/download/${TAG}/${name}" 2>/dev/null || { echo "$name"; return 1; }
  done
  if [ "$LATEST" -eq 1 ]; then
    curl -fsSL "${base}/latest/download/SHA256SUMS" 2>/dev/null | grep -qF -- "-${TAG}.tar.gz" || { echo "releases/latest"; return 1; }
  fi
}

i=1
while :; do
  missing="$(ready)" && { echo "The files of ${TAG} download."; exit 0; }
  [ "$i" -lt "$tries" ] || break
  echo "Waiting for ${missing} of ${TAG} (try ${i} of ${tries})."
  sleep "$pause"
  i=$((i + 1))
done
echo "After ${tries} tries, ${missing} of ${TAG} still does not download." >&2
exit 1
