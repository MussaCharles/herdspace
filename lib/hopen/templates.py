"""The layout templates: find and list them, read one, and guard the names.

A template is a file NAME.layout in the templates folder. Each line that is not
a comment is one pane: NAME FROM DIRECTION SIZE COMMAND.
"""
import glob
import json
import os
import re
import subprocess
import time

from . import core

NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]*")


def template_file(folder, name):
    return os.path.join(folder, name + ".layout")


def template_exists(folder, name):
    """True for a template file, and for "plain", which means no panes. A name
    is letters, numbers, "-", and "_", so it cannot leave the folder."""
    if name == "plain":
        return True
    return bool(NAME.fullmatch(name)) and os.path.isfile(template_file(folder, name))


def template_lines(folder, name):
    """The lines of a template that are not a comment and not empty."""
    with open(template_file(folder, name), encoding="utf-8", errors="replace") as handle:
        lines = handle.read().split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    return [line for line in lines if not re.match(r"^\s*(#|$)", line)]


def show_templates(folder):
    """The table of hopen --templates: plain first, then each template file."""
    out = ["%-12s %s" % ("TEMPLATE", "DESCRIPTION"), "%-12s %s" % ("plain", "One pane with a shell. This is the default.")]
    for path in sorted(glob.glob(os.path.join(folder, "*.layout")), key=core.collate):
        if not os.path.isfile(path):
            continue
        name = os.path.basename(path)[: -len(".layout")]
        with open(path, encoding="utf-8", errors="replace") as handle:
            first = handle.readline().rstrip("\n")
        match = re.match(r"^# *" + re.escape(name) + r": *", first)
        out.append("%-12s %s" % (name, first[match.end():] if match else ""))
    return out


def guard(text, seconds):
    """Put back each template pane name and each tab name of a list that
    changed, for SECONDS. TEXT has "pane<TAB>name" lines, the byte 0x1e, and
    "root pane<TAB>tab name" lines. guard_names in templates.sh starts it in
    the background."""
    panes_text, _, tabs_text = text.partition("\x1e")
    pairs = [line.split("\t", 1) for line in panes_text.split("\n") if "\t" in line]
    # A tab is found by its first pane, because a tab create answer has that pane.
    tabs = [line.split("\t", 1) for line in tabs_text.split("\n") if "\t" in line]
    end = time.time() + float(seconds)

    def herdr(*args):
        out = subprocess.run(["herdr", *args], capture_output=True, text=True, timeout=5).stdout
        return json.loads(out)["result"]

    while (pairs or tabs) and time.time() < end:
        time.sleep(0.5)
        try:
            panes = herdr("pane", "list")["panes"]
            labels = {p["pane_id"]: p.get("label") or "" for p in panes}
            tab_of = {p["pane_id"]: (p["workspace_id"], p["tab_id"]) for p in panes}
            tab_labels = {}
            for workspace in {tab_of[pane][0] for pane, _ in tabs if pane in tab_of}:
                for tab in herdr("tab", "list", "--workspace", workspace)["tabs"]:
                    tab_labels[tab["tab_id"]] = tab.get("label") or ""
        except Exception:
            continue
        pairs = [(pane, name) for pane, name in pairs if pane in labels]
        for pane, name in pairs:
            if labels[pane] != name:
                subprocess.run(["herdr", "pane", "rename", pane, name], capture_output=True, timeout=5)
        tabs = [(pane, name) for pane, name in tabs if pane in tab_of and tab_of[pane][1] in tab_labels]
        for pane, name in tabs:
            tab = tab_of[pane][1]
            if tab_labels[tab] != name:
                subprocess.run(["herdr", "tab", "rename", tab, name], capture_output=True, timeout=5)
