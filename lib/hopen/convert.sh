# shellcheck shell=bash
# hopen --convert: write a herdspace.toml file from a VS Code workspace file.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# convert_list writes ~/SESSION/herdspace.toml from the VS Code list of SESSION.
# It never replaces a file.
convert_list() {
  local source target items
  target="${HOME}/${SESSION}/herdspace.toml"
  [ ! -e "$target" ] || die "${target} exists. Move it, and run --convert again."
  source="$(find_list_for "$SESSION")"
  case "$source" in
    *.code-workspace) ;;
    *) die "No VS Code list for ${SESSION}." ;;
  esac
  mkdir -p "${HOME}/${SESSION}"
  items="$(mktemp)"
  read_list "$source" items >"$items" || { rm -f "$items"; die "Could not read ${source}."; }
  python3 -I - "$source" "$target" "$HOME" "$items" <<'PY'
import os, sys

source, target, home, items = sys.argv[1:5]
target_dir = os.path.dirname(target)

def quote(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'

def where(path):
    relative = os.path.relpath(path, target_dir)
    if not relative.startswith(".."):
        return relative
    if path.startswith(home + os.sep):
        return "~/" + os.path.relpath(path, home)
    return path

def env_table(pairs):
    return "{ " + ", ".join(key + " = " + quote(value) for key, value in pairs) + " }"

def task_table(pairs):
    return "{ " + ", ".join(quote(name) + " = " + quote(command) for name, command in pairs) + " }"

def near(path, folder):
    # A path relative to folder if it is inside folder, else ~/... or absolute.
    relative = os.path.relpath(path, folder)
    if not relative.startswith(".."):
        return relative
    if path.startswith(home + os.sep):
        return "~/" + os.path.relpath(path, home)
    return path

parent = None
projects = []
pending_file = ""
# splitlines() also ends a line at the byte 0x1e, so split at new lines only.
for raw in open(items, encoding="utf-8").read().split("\n"):
    if not raw:
        continue
    kind, *fields = raw.split("\x1e")
    fields = ["" if value == "-" else value for value in fields] + [""] * 5
    if kind == "F":
        # Keep the path of the env file, not its values.
        pending_file = fields[1]
    elif kind in ("R", "P"):
        entry = {"label": fields[0], "path": fields[1], "template": fields[2], "on_open": fields[3], "tabs": [],
                 "env": [item.split("=", 1) for item in fields[4].split("\x1f") if "=" in item],
                 "env_file": pending_file}
        pending_file = ""
        if kind == "R":
            parent = entry
        else:
            projects.append(entry)
    elif kind == "K":
        owner = projects[-1] if projects else parent
        if owner is not None and owner["label"] == fields[0]:
            owner.setdefault("tasks", []).append((fields[1], fields[2]))
    elif kind == "T" and projects and projects[-1]["label"] == fields[0]:
        projects[-1]["tabs"].append({"name": fields[1], "template": fields[2], "run": fields[3]})

lines = ["# Written by hopen --convert from " + source.replace(home, "~", 1) + ".", ""]
if parent is None:
    lines += ["parent_workspace = false", ""]
else:
    if parent["template"] != "plain":
        lines.append("parent_template = " + quote(parent["template"]))
    if parent["on_open"]:
        lines.append("on_open = " + quote(parent["on_open"]))
    if parent["env"]:
        lines.append("env = " + env_table(parent["env"]))
    if parent["env_file"]:
        lines.append("env_file = " + quote(near(parent["env_file"], target_dir)))
    if parent.get("tasks"):
        lines.append("tasks = " + task_table(parent["tasks"]))
    if len(lines) > 2:
        lines.append("")
for project in projects:
    lines += ["[[project]]", "name = " + quote(project["label"]), "path = " + quote(where(project["path"]))]
    if project["template"] != "plain":
        lines.append("template = " + quote(project["template"]))
    if project["on_open"]:
        lines.append("on_open = " + quote(project["on_open"]))
    if project["env"]:
        lines.append("env = " + env_table(project["env"]))
    if project["env_file"]:
        lines.append("env_file = " + quote(near(project["env_file"], project["path"])))
    if project.get("tasks"):
        lines.append("tasks = " + task_table(project["tasks"]))
    if project["tabs"]:
        tabs = []
        for tab in project["tabs"]:
            text = "{ name = " + quote(tab["name"]) + ", template = " + quote(tab["template"])
            if tab["run"]:
                text += ", run = " + quote(tab["run"])
            tabs.append(text + " }")
        lines.append("tabs = [" + ", ".join(tabs) + "]")
    lines.append("")
with open(target, "w", encoding="utf-8") as handle:
    handle.write("\n".join(lines).rstrip() + "\n")
PY
  rm -f "$items"
  printf '  [info] Wrote %s. hopen now uses it in place of %s.\n' "$(short_path "$target")" "$(short_path "$source")"
}
