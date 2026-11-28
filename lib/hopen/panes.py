"""The Herdr panes: wait for one, split, open a tab, find the editor of a tab,
and open a file in it.

A Place holds the pane, the workspace, and the tab of the palette or of quick
open, and the place that the person chose: right, down, tab, or "" for the
default place of the action.
"""
import json
import os
import re
import shlex
import subprocess
import sys
import time

from . import core, editor

SHELLS = {"zsh", "bash", "sh", "fish", "dash"}


class Place:
    def __init__(self, pane="", workspace="", tab="", where=""):
        self.pane, self.workspace, self.tab, self.where = pane, workspace, tab, where

    @classmethod
    def active(cls):
        """The pane, workspace, and tab of a popup, or of the current pane."""
        env = os.environ.get
        return cls(env("HERDR_ACTIVE_PANE_ID") or env("HERDR_PANE_ID") or "",
                   env("HERDR_ACTIVE_WORKSPACE_ID") or env("HERDR_WORKSPACE_ID") or "",
                   env("HERDR_ACTIVE_TAB_ID") or env("HERDR_TAB_ID") or "")


def in_popup():
    """True in a Herdr popup, which closes when its command ends."""
    return not os.environ.get("HERDR_PANE_ID") and bool(os.environ.get("HERDR_ACTIVE_PANE_ID"))


def herdr(*args):
    """Run a Herdr command, and return its output, or "" when it fails."""
    try:
        return subprocess.run(["herdr", *args], capture_output=True, text=True).stdout
    except OSError:
        return ""


def herdr_json(field, *args):
    """Run a Herdr command, and return one field of its result, for example
    root_pane.pane_id of "tab create"."""
    try:
        value = json.loads(herdr(*args)).get("result", {})
    except ValueError:
        return ""
    for key in field.split("."):
        value = value.get(key, {}) if isinstance(value, dict) else {}
    return value if isinstance(value, str) else ""


def pane_ready(pane):
    """Wait until the shell of a new pane draws its prompt, for at most 15
    seconds. Text that reaches a shell before it starts can get lost."""
    for _ in range(60):
        if herdr("pane", "read", pane).strip():
            return
        time.sleep(0.25)


def run_in(pane, command):
    subprocess.run(["herdr", "pane", "run", pane, command], stdout=subprocess.DEVNULL)


def new_tab_run(place, label, folder, command):
    """Open a new tab in the current workspace, and run COMMAND in it."""
    pane = herdr_json("root_pane.pane_id", "tab", "create", "--workspace", place.workspace, "--cwd", folder,
                      "--label", label, "--focus")
    if not pane:
        raise core.Fail("Herdr did not open a new tab.")
    pane_ready(pane)
    run_in(pane, command)


def split_run(place, direction, folder, command=""):
    """Split the current pane, and run COMMAND in the new pane."""
    pane = herdr_json("pane.pane_id", "pane", "split", "--pane", place.pane, "--direction", direction,
                      "--cwd", folder, "--focus")
    if not pane:
        raise core.Fail("Herdr did not split the pane.")
    if command:
        pane_ready(pane)
        run_in(pane, command)


def focus_step(layout, target):
    """The next step from the focused pane toward TARGET, as (direction, pane),
    or None when TARGET has the focus or is not in the layout."""
    rects = {p["pane_id"]: p["rect"] for p in layout.get("panes", [])}
    here = layout.get("focused_pane_id")
    if here == target or here not in rects or target not in rects:
        return None

    def center(r):
        return (r["x"] + r["width"] / 2, r["y"] + r["height"] / 2)
    (hx, hy), (tx, ty) = center(rects[here]), center(rects[target])
    if abs(tx - hx) >= abs(ty - hy):
        return ("right" if tx > hx else "left"), here
    return ("down" if ty > hy else "up"), here


def focus_pane(pane):
    """Move the focus to PANE in its tab. Herdr moves the focus only from one
    pane to its neighbor, so this steps toward PANE, at most 8 times."""
    for _ in range(8):
        try:
            layout = json.loads(herdr("pane", "layout", "--pane", pane)).get("result", {}).get("layout", {})
        except ValueError:
            return True
        step = focus_step(layout, pane)
        if step is None:
            return True
        result = subprocess.run(["herdr", "pane", "focus", "--pane", step[1], "--direction", step[0]],
                                capture_output=True)
        if result.returncode != 0:
            return False
    return True


def pane_runs(pane, kind):
    """True when the foreground of PANE is Neovim or Vim (KIND editor), or
    only a shell at its prompt (KIND shell)."""
    try:
        info = json.loads(herdr("pane", "process-info", "--pane", pane))
    except ValueError:
        return False
    procs = info.get("result", {}).get("process_info", {}).get("foreground_processes", [])
    names = {p.get("name") for p in procs}
    if kind == "editor":
        return bool(names & {"nvim", "vim"})
    return bool(names) and names <= SHELLS


def editor_pane(tab):
    """The first pane of TAB that runs Neovim or Vim, or ""."""
    try:
        panes = json.loads(herdr("pane", "list")).get("result", {}).get("panes", [])
    except ValueError:
        return ""
    for pane in panes:
        if pane.get("tab_id") == tab and pane_runs(pane["pane_id"], "editor"):
            return pane["pane_id"]
    return ""


def digits(line):
    """The line comes from a search result, and a file name can hold any text,
    also a colon. So a line is digits only, or nothing."""
    return line if re.fullmatch(r"[0-9]+", line or "") else ""


def drop_in(pane, path, line=""):
    """Open PATH in the Neovim of PANE, at LINE, and focus PANE."""
    line = digits(line)
    go = f" | call cursor({line}, 1)" if line else ""
    quoted = path.replace("'", "''")
    subprocess.run(["herdr", "pane", "send-keys", pane, "esc"], stdout=subprocess.DEVNULL)
    subprocess.run(["herdr", "pane", "send-text", pane, f":execute 'drop' fnameescape('{quoted}'){go}"],
                   stdout=subprocess.DEVNULL)
    subprocess.run(["herdr", "pane", "send-keys", pane, "enter"], stdout=subprocess.DEVNULL)
    focus_pane(pane)


def open_target(place, path, root, line, home):
    """Open a file for quick open and search, in this order: the Neovim of the
    focused pane, the focused shell at its prompt, the Neovim pane of the tab,
    or a new split on the right. place.where asks for a new editor in that
    place. A new editor runs with exec, so that its pane closes when Neovim
    quits."""
    line = digits(line)
    plus = f"+{line} " if line else ""
    if not place.where:
        if pane_runs(place.pane, "editor"):
            drop_in(place.pane, path, line)
            return
        if pane_runs(place.pane, "shell"):
            run_in(place.pane, f"{editor.editor_command(home)} {plus}{shlex.quote(path)}")
            return
        pane = editor_pane(place.tab)
        if pane:
            drop_in(pane, path, line)
            return
    run_at(place, "right", os.path.basename(path), root, f"exec env {editor.editor_command(home)} {plus}{shlex.quote(path)}")


def run_at(place, default, label, folder, command=""):
    """Run COMMAND in the place that the person chose (place.where), or in
    DEFAULT: here, right, down, or tab. "here" runs COMMAND in the place of
    this process. Outside Herdr, only "here" works."""
    where = place.where or default
    if not place.pane:
        where = "here"
    if where in ("right", "down"):
        split_run(place, where, folder, command)
    elif where == "tab":
        if command:
            new_tab_run(place, label, folder, command)
        else:
            subprocess.run(["herdr", "tab", "create", "--workspace", place.workspace, "--cwd", folder,
                            "--label", label, "--focus"], stdout=subprocess.DEVNULL)
    else:
        try:
            os.chdir(folder)
        except OSError:
            raise core.Fail(f"No folder {folder}.")
        sys.stdout.flush()
        if command:
            # bash read the command with eval, so bash reads it here too.
            os.execvp("bash", ["bash", "-c", f"exec {command}"])
        shell = os.environ.get("SHELL") or "sh"
        os.execvp(shell, [shell])
