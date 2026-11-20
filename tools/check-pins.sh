#!/usr/bin/env bash
# check-pins.sh compares the pinned downloads in tools/versions.tsv and
# tools/versions.env with the latest releases. It runs tools/update-versions.sh
# on a copy, so the files of the repository do not change. It also compares
# each Neovim plugin of config/nvim/lazy-lock.json with its branch on GitHub:
# a locked commit that is less than PIN_MIN_AGE_DAYS days old (7 by default)
# counts as a problem, and a newer commit is listed for information.
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
cp tools/update-versions.sh tools/versions.tsv tools/versions.env "$work/"
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

plugins="$(python3 -I - <<'PY'
import datetime, json, os, urllib.request

MIN_AGE = datetime.timedelta(days=int(os.environ.get("PIN_MIN_AGE_DAYS", "7")))
NOW = datetime.datetime.now(datetime.timezone.utc)
UNTIL = (NOW - MIN_AGE).strftime("%Y-%m-%dT%H:%M:%SZ")

def api(path):
    request = urllib.request.Request("https://api.github.com/" + path)
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        request.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)

lock = json.load(open("config/nvim/lazy-lock.json", encoding="utf-8"))
repos = dict(line.split("\t") for line in open("tools/nvim-plugins.tsv", encoding="utf-8").read().splitlines()
             if line and not line.startswith("#"))
young, newer = [], []
for name in sorted(lock, key=str.lower):
    repo, pin = repos[name], lock[name]
    settled = api(f"repos/{repo}/commits?sha={pin['branch']}&until={UNTIL}&per_page=1")
    if settled and settled[0]["sha"] == pin["commit"]:
        continue
    row = f"| {name} | {pin['commit'][:12]} | {settled[0]['sha'][:12] if settled else '-'} |"
    # A plugin with a version, for example blink.cmp, can lock a commit of a
    # release tag that is not on its branch. Only the age of the commit counts.
    locked = api(f"repos/{repo}/commits/{pin['commit']}")["commit"]["committer"]["date"]
    if datetime.datetime.fromisoformat(locked.replace("Z", "+00:00")) > NOW - MIN_AGE:
        young.append(row)
    elif settled and api(f"repos/{repo}/compare/{settled[0]['sha']}...{pin['commit']}")["status"] == "behind":
        newer.append(row)
if young:
    print("These Neovim plugins are locked to a commit that is less than 7 days old. Check the commit, or lock an older one:\n")
    print("| Plugin | Locked | Newest commit that is old enough |\n|--------|--------|------|")
    print("\n".join(young))
if newer:
    print(("\n" if young else "") + "These Neovim plugins have newer commits. They are here for information. To update, run `:Lazy update` in Neovim, and commit `config/nvim/lazy-lock.json`:\n")
    print("| Plugin | Locked | Newest commit that is old enough |\n|--------|--------|------|")
    print("\n".join(newer))
if young:
    print("\nYOUNG")
PY
)"
if [ -n "$plugins" ]; then
  plugins_young=0
  case "$plugins" in *YOUNG) plugins_young=1; plugins="${plugins%$'\n'YOUNG}" ;; esac
  if [ -z "$report" ] && [ "$plugins_young" -eq 0 ]; then
    echo "Each pin is the latest release that is at least ${PIN_MIN_AGE_DAYS:-7} days old."
    printf '\n%s\n' "$plugins"
    exit 0
  fi
  report="${report:+${report}

}${plugins}"
fi

if [ -z "$report" ]; then
  echo "Each pin is the latest release that is at least ${PIN_MIN_AGE_DAYS:-7} days old."
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
