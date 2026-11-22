#!/usr/bin/env bash
# known-hashes.sh writes bootstrap/known-hashes.tsv: the SHA-256 of each older
# version of each file that the setup installs from config/ and bin/. The setup
# reads the list. A file with no manifest entry that matches a line came from
# an older herdspace, so the setup updates it with no question.
# Usage: tools/known-hashes.sh          Write the list.
#        tools/known-hashes.sh --check  Fail if the list is not up to date.
# It reads the full git history, so CI needs fetch-depth: 0.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=bootstrap/known-hashes.tsv

generate() {
  python3 -I - <<'PY'
import hashlib, re, subprocess

def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True).stdout

roots = ["config", "bin/hopen", "bin/herdr-update-check"]
current = {}
for line in git("ls-tree", "-r", "HEAD", "--", *roots).decode().splitlines():
    meta, path = line.split("\t", 1)
    current[path] = meta.split()[2]

lines = set()
def add(path, data):
    lines.add(f"{path}\t{hashlib.sha256(data).hexdigest()}")

# Each version of each file in the history, except the version of HEAD. The
# setup sees the version of HEAD as current, so it needs no line.
raw = git("log", "--no-renames", "--no-abbrev", "--format=", "--raw", "HEAD", "--", *roots).decode()
for line in raw.splitlines():
    if not line.startswith(":"):
        continue
    meta, path = line.split("\t", 1)
    blob = meta.split()[3]
    if set(blob) == {"0"} or current.get(path) == blob:
        continue
    add(path, git("cat-file", "blob", blob))

# A release writes its tag in bin/hopen, as tools/release.sh does. The tags
# come from the headings of CHANGELOG.md, so the pull request of a release adds
# the line of its own tag before the tag exists.
changelog = git("show", "HEAD:CHANGELOG.md").decode()
for tag in re.findall(r"(?m)^## \[(\d[^\]]*)\]", changelog):
    ref = f"refs/tags/{tag}" if subprocess.run(["git", "rev-parse", "-q", "--verify", f"refs/tags/{tag}"], capture_output=True).returncode == 0 else "HEAD"
    try:
        data = git("show", f"{ref}:bin/hopen")
    except subprocess.CalledProcessError:
        continue
    add("bin/hopen", re.sub(rb"(?m)^HOPEN_VERSION=.*$", b'HOPEN_VERSION="' + tag.encode() + b'"', data))

print("# The SHA-256 of each older version of each installed file. tools/known-hashes.sh writes this list.")
for line in sorted(lines):
    print(line)
PY
}

if [ "${1:-}" = "--check" ]; then
  if ! diff -q <(generate) "$OUT" >/dev/null 2>&1; then
    echo "${OUT} is not up to date. Run tools/known-hashes.sh, and commit the list." >&2
    exit 1
  fi
  echo "${OUT} is up to date."
else
  generate >"$OUT"
  echo "Wrote ${OUT}: $(grep -vc '^#' "$OUT") versions."
fi
