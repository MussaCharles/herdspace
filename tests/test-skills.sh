#!/usr/bin/env bash
# test-skills.sh checks each skill against the Agent Skills specification
# (https://agentskills.io/specification), and checks the links for Claude Code.
# Usage: tests/test-skills.sh
cd "$(dirname "$0")/.." || exit 1
python3 -I - <<'PY'
import os, re, sys

failures = 0
def result(ok, text):
    global failures
    print(("PASS " if ok else "FAIL ") + text)
    if not ok:
        failures += 1

ALLOWED = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}
NAME = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")

def frontmatter(path):
    lines = open(path, encoding="utf-8").read().split("\n")
    if lines[0] != "---" or "---" not in lines[1:]:
        return None
    end = lines.index("---", 1)
    fields, key = {}, None
    for line in lines[1:end]:
        top = re.match(r"^([A-Za-z_-]+):\s*(.*)$", line)
        if top:
            key, value = top.group(1), top.group(2).strip()
            fields[key] = "" if value in ("|", ">", "|-", ">-") else value.strip('"')
        elif key and line.startswith(" "):
            fields[key] = (fields[key] + " " + line.strip()).strip()
    return fields

skills = []
for root in (".agents/skills", "skills"):
    for name in sorted(os.listdir(root)):
        if os.path.isdir(os.path.join(root, name)):
            skills.append((root, name))

for root, name in skills:
    path = os.path.join(root, name, "SKILL.md")
    label = f"{root}/{name}"
    if not os.path.isfile(path):
        result(False, f"{label}: has SKILL.md")
        continue
    fields = frontmatter(path)
    if fields is None:
        result(False, f"{label}: has frontmatter")
        continue
    result(fields.get("name") == name, f"{label}: name matches the folder")
    result(bool(NAME.match(name)) and len(name) <= 64, f"{label}: name has lowercase letters, numbers, and single hyphens")
    description = fields.get("description", "")
    result(0 < len(description) <= 1024, f"{label}: description has 1 to 1024 characters ({len(description)})")
    result(len(fields.get("compatibility", "")) <= 500, f"{label}: compatibility has 500 characters at most")
    extra = sorted(set(fields) - ALLOWED)
    result(not extra, f"{label}: only fields of the specification {extra if extra else ''}".rstrip())
    lines = open(path, encoding="utf-8").read().count("\n")
    result(lines < 500, f"{label}: SKILL.md has fewer than 500 lines ({lines})")
    body = open(path, encoding="utf-8").read()
    # Example links in code are not real links.
    body = re.sub(r"```.*?```", "", body, flags=re.S)
    body = re.sub(r"`[^`]*`", "", body)
    for target in re.findall(r"\]\(([^)#\s]+)(?:#[^)]*)?\)", body):
        if target.startswith("http"):
            continue
        ok = os.path.exists(os.path.normpath(os.path.join(root, name, target)))
        result(ok, f"{label}: link {target} resolves")

agents = open("AGENTS.md", encoding="utf-8").read()
for name in sorted(os.listdir(".agents/skills")):
    link = os.path.join(".claude/skills", name)
    ok = os.path.islink(link) and os.path.realpath(link) == os.path.realpath(os.path.join(".agents/skills", name))
    result(ok, f"Claude Code link for {name}")
    result(f"`{name}`" in agents, f"AGENTS.md lists {name}")
for name in sorted(os.listdir(".claude/skills")):
    result(os.path.exists(os.path.join(".claude/skills", name)), f"Claude Code link {name} is not broken")

print(f"RESULT failures={failures}")
sys.exit(1 if failures else 0)
PY
