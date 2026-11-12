#!/usr/bin/env bash
# test-links.sh checks each relative link of each Markdown file that git
# tracks: the file or folder must exist, and an #anchor must match a heading.
# A link in a community file in .github/ must start with /, because the
# Contributing tab of GitHub reads a relative link from the wrong folder.
# It needs no network.
# Usage: tests/test-links.sh
cd "$(dirname "$0")/.." || exit 1
git ls-files '*.md' | python3 -I -c '
import os, re, sys

def slug(heading):
    # The anchor that GitHub makes from a heading.
    text = re.sub(r"`([^`]*)`", r"\1", heading.strip().lower())
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"[^\w\- ]", "", text)
    return text.replace(" ", "-")

def anchors(path):
    found, seen = set(), {}
    in_code = False
    for line in open(path, encoding="utf-8"):
        if line.lstrip().startswith("```"):
            in_code = not in_code
            continue
        match = None if in_code else re.match(r"^#{1,6}\s+(.*?)\s*#*\s*$", line)
        if match:
            base = slug(match.group(1))
            count = seen.get(base, 0)
            seen[base] = count + 1
            found.add(base if count == 0 else f"{base}-{count}")
    return found

COMMUNITY = {".github/CONTRIBUTING.md", ".github/CODE_OF_CONDUCT.md", ".github/SECURITY.md", ".github/SUPPORT.md"}
failures = checked = 0
cache = {}
for path in sys.stdin.read().split():
    text = open(path, encoding="utf-8").read()
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    text = re.sub(r"`[^`\n]*`", "", text)
    for target in re.findall(r"\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)", text):
        if re.match(r"^[a-z][a-z0-9+.-]*:", target):
            continue
        checked += 1
        file_part, _, anchor = target.partition("#")
        if path in COMMUNITY and file_part and not file_part.startswith("/"):
            print(f"FAIL {path}: {target} must start with /")
            failures += 1
            continue
        if not file_part:
            dest = path
        elif file_part.startswith("/"):
            dest = file_part.lstrip("/")
        else:
            dest = os.path.normpath(os.path.join(os.path.dirname(path), file_part))
        if not os.path.exists(dest):
            print(f"FAIL {path}: {target} does not exist")
            failures += 1
            continue
        if anchor and dest.endswith(".md"):
            if dest not in cache:
                cache[dest] = anchors(dest)
            if anchor.lower() not in cache[dest]:
                print(f"FAIL {path}: {target} has no heading for #{anchor}")
                failures += 1
print(f"RESULT links={checked} failures={failures}")
sys.exit(1 if failures else 0)
'
