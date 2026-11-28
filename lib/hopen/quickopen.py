"""Quick open, like Ctrl+P in VS Code, and the menus of hopen --find and --grep.

Quick open lets the person choose a file of the project, and opens it with the
focus on it. In Herdr, Enter opens the file in the focused pane when it runs
Neovim or is a shell at its prompt, else in the Neovim pane of the tab, else in
a new split on the right. Ctrl+V, Ctrl+S, and Ctrl+T open a new editor on the
right, below, or in a new tab. A new editor runs with exec, so that its pane
closes when Neovim quits.
"""
import os
import re
import shutil
import subprocess
import sys

from . import core, editor, panes, search, ui

KEYS = {"ctrl-v": "right", "ctrl-s": "down", "ctrl-t": "tab"}


def need(command, what):
    if not shutil.which(command):
        raise core.Fail(f"{what} needs {command}. The server setup installs it.")


def need_terminal(what):
    if not (sys.stdin.isatty() and sys.stdout.isatty()):
        raise core.Fail(f"{what} needs a terminal.")


def file_line(path):
    """A path of the file list as the menu shows it: no "./" in front, except
    for a name that starts with "-", which keeps it."""
    return re.sub(r"^\./([^-])", r"\1", path)


def dimmed(path):
    return ui.dim_folders([file_line(path)])[0]


def preview_file():
    return "bat --color=always --style=numbers {}" if shutil.which("bat") else "cat {}"


def quick_open(folder, search_in, home):
    need("fzf", "hopen --quick-open")
    need_terminal("hopen --quick-open")
    top = core.run(["git", "-C", folder, "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    root = top.stdout.rstrip("\n") if top.returncode == 0 else folder
    place = panes.Place.active()
    header = "Type to filter. Enter opens the file. Esc closes. In Neovim, Ctrl+Q closes the file."
    if place.pane:
        header += "\nCtrl+V opens a new editor on the right, Ctrl+S below, Ctrl+T in a new tab."
    out = ui.run_fzf_from("Quick open", search.files_command(search_in), root, dimmed, "--ansi", "--prompt",
                          "Open file > ", "--header", header, "--expect", "ctrl-v,ctrl-s,ctrl-t",
                          "--preview", preview_file(), "--height", "100%", "--reverse")
    lines = out.split("\n")
    key, name = (lines + ["", ""])[:2]
    if not name:
        return 0
    if not place.pane:
        os.chdir(root)
        editor.open_in_editor(name)
    place.where = KEYS.get(key, "")
    panes.open_target(place, f"{root}/{name}", root, "", home)
    return 0


def find_file(folder, search_in):
    need("fzf", "hopen --find")
    need_terminal("hopen --find")
    name = ui.run_fzf_from("Find a file", search.files_command(search_in), folder, dimmed, "--ansi", "--prompt",
                           "Open file > ", "--preview", preview_file(), "--height", "80%", "--reverse").rstrip("\n")
    if not name:
        return 0
    os.chdir(folder)
    editor.open_in_editor(name)


def grep_files(folder, text, search_in, home):
    need("rg", "hopen --grep")
    need("fzf", "hopen --grep")
    need_terminal("hopen --grep")
    preview = ("bat --color=always --style=numbers --highlight-line {2} {1}" if shutil.which("bat")
               else "sed -n '{2},+20p' {1}")
    command = search.text_command(text, search_in)
    args = ["--ansi", "--delimiter", ":", "--prompt", f"Search {text} > "]
    if not panes.in_popup():
        hit = ui.run_fzf_from("Search", command, folder, lambda line: line, *args, "--preview", preview,
                              "--preview-window", "+{2}-5", "--height", "80%", "--reverse").rstrip("\n")
        if not hit:
            return 0
        os.chdir(folder)
        fields = hit.split(":")
        editor.open_in_editor(fields[0], fields[1] if len(fields) > 1 else "")
    # In a Herdr popup, the result opens like quick open, at its line.
    env = os.environ.get
    place = panes.Place(env("HERDR_ACTIVE_PANE_ID") or "", env("HERDR_ACTIVE_WORKSPACE_ID") or "",
                        env("HERDR_ACTIVE_TAB_ID") or "")
    out = ui.run_fzf_from("Search", command, folder, lambda line: line, *args, "--header",
                          "Enter opens the result. Ctrl+V opens a new editor on the right, Ctrl+S below, Ctrl+T in a new tab.",
                          "--expect", "ctrl-v,ctrl-s,ctrl-t", "--preview", preview, "--preview-window", "+{2}-5",
                          "--height", "100%", "--reverse")
    lines = out.split("\n")
    key, hit = (lines + ["", ""])[:2]
    if not hit:
        return 0
    place.where = KEYS.get(key, "")
    fields = hit.split(":")
    panes.open_target(place, f"{os.path.abspath(folder)}/{fields[0]}", folder, fields[1] if len(fields) > 1 else "", home)
    return 0
