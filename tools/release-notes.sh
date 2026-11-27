#!/usr/bin/env bash
# release-notes.sh prints the release notes of a tag: a link to the install
# steps, the section of CHANGELOG.md for the tag, and the list of the pull
# requests that were merged since the previous tag of CHANGELOG.md, each with
# its author. GitHub writes that list with its generate-notes API, which saves
# nothing. .github/release.yml leaves out the pull requests of bots.
#
# Usage: tools/release-notes.sh <tag> --repo owner/name
#   HS_CHANGELOG names another changelog file, for tests.
#   HS_NO_PR_LIST=1 leaves out the list of pull requests.
# With no section for the tag, it prints the rest and exits with status 3.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

TAG=""
REPO=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    -*) echo "Usage: tools/release-notes.sh <tag> --repo owner/name" >&2; exit 2 ;;
    *) TAG="$1"; shift ;;
  esac
done
[ -n "$TAG" ] && [ -n "$REPO" ] || { echo "Usage: tools/release-notes.sh <tag> --repo owner/name" >&2; exit 2; }

changelog="${HS_CHANGELOG:-CHANGELOG.md}"
section="$(awk -v tag="$TAG" '
  index($0, "## [" tag "]") == 1 { found = 1; next }
  found && (/^## \[/ || /^\[[^]]+\]: /) { exit }
  found { print }
' "$changelog" 2>/dev/null | sed '/./,$!d')" || section=""
# The previous tag is the next version heading below the section of the tag.
previous="$(awk -v tag="$TAG" '
  index($0, "## [" tag "]") == 1 { found = 1; next }
  found && /^## \[[0-9]/ { sub(/^## \[/, ""); sub(/\].*/, ""); print; exit }
' "$changelog" 2>/dev/null)" || previous=""

printf 'To install, follow the [Quick start](https://github.com/%s/blob/%s/README.md#quick-start). The [setup guide](https://github.com/%s/blob/%s/docs/setup.md) has every option.\n' "$REPO" "$TAG" "$REPO" "$TAG"
[ -z "$section" ] || printf '\n%s\n' "$section"

if [ "${HS_NO_PR_LIST:-0}" != 1 ]; then
  # target_commitish counts only for a tag that does not exist yet. A release
  # is made on main.
  args=(-X POST "repos/${REPO}/releases/generate-notes" -f "tag_name=${TAG}" -f "target_commitish=main")
  [ -z "$previous" ] || args+=(-f "previous_tag_name=${previous}")
  if list="$(gh api "${args[@]}" --jq .body 2>/dev/null)" && [ -n "$list" ]; then
    printf '\n%s\n' "$list"
  else
    echo "Note: GitHub gave no list of pull requests for ${TAG}, so the notes have none." >&2
  fi
fi
[ -n "$section" ] || exit 3
