#!/usr/bin/env bash
# check-pins.sh compares the pinned downloads in tools/versions.tsv and
# tools/versions.env with the latest releases. It runs tools/update-versions.sh
# on a copy, so the files of the repository do not change.
#
# Usage: tools/check-pins.sh [--issue]
#   With no option, it prints a report, and it exits 1 if a pin is old.
#   --issue opens an issue with the report, or updates the open one, with gh.
#   The weekly workflow .github/workflows/pins.yml uses it.
# Set GITHUB_TOKEN if GitHub limits the number of requests.
set -euo pipefail
cd "$(dirname "$0")/.."
ISSUE=0
[ "${1:-}" = "--issue" ] && ISSUE=1
TITLE="Pinned tools have newer releases"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp tools/update-versions.sh "$work/"
"$work/update-versions.sh" >/dev/null

report="$(python3 -I - tools "$work" <<'PY'
import sys

old_dir, new_dir = sys.argv[1], sys.argv[2]

def releases(path):
    found = {}
    for line in open(f"{path}/versions.tsv", encoding="utf-8"):
        name, version = line.split("\t")[:2]
        found[name] = version
    return found

def refs(path):
    found = {}
    for line in open(f"{path}/versions.env", encoding="utf-8"):
        if "=" in line and not line.startswith("#"):
            key, value = line.strip().split("=", 1)
            found[key] = value
    return found

# These git pins follow a branch that changes almost each day. A new commit
# there is listed for information, but it does not count as an old pin.
INFO_ONLY = {"OHMYZSH_REF", "POWERLEVEL10K_REF", "ZSH_AUTOSUGGESTIONS_REF", "ZSH_SYNTAX_HIGHLIGHTING_REF"}
old_rel, new_rel = releases(old_dir), releases(new_dir)
old_ref, new_ref = refs(old_dir), refs(new_dir)
rows, info = [], []
for name in sorted(new_rel):
    if old_rel.get(name) != new_rel[name]:
        rows.append(f"| {name} | {old_rel.get(name, '-')} | {new_rel[name]} |")
for key in sorted(new_ref):
    if old_ref.get(key) != new_ref[key]:
        line = f"| {key} | {old_ref.get(key, '-')[:12]} | {new_ref[key][:12]} |"
        (info if key in INFO_ONLY else rows).append(line)
if rows:
    print("These pins have a newer release or commit:\n")
    print("| Pin | Pinned | Latest |\n|-----|--------|--------|")
    print("\n".join(rows))
    if info:
        print("\nThese git pins follow a branch that changes often. They are here for information:\n")
        print("| Pin | Pinned | Latest |\n|-----|--------|--------|")
        print("\n".join(info))
    print("\nTo update, run `tools/update-versions.sh`, review the result, run the tests, and open a pull request. See the herdspace-bootstrap skill.")
PY
)"

if [ -z "$report" ]; then
  echo "Each pin is the latest release."
  exit 0
fi
printf '%s\n' "$report"
[ "$ISSUE" -eq 1 ] || exit 1

number="$(gh issue list --state open --search "\"${TITLE}\" in:title" --json number,title -q ".[] | select(.title == \"${TITLE}\") | .number" | head -n 1)"
if [ -n "$number" ]; then
  gh issue edit "$number" --body "$report" >/dev/null
  echo "Updated issue #${number}."
else
  gh issue create --title "$TITLE" --body "$report"
fi
