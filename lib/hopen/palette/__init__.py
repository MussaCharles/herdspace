"""The command palette, like Ctrl+Shift+P in VS Code.

The palette lists each action as "Group: Action", with its key or command at
the right, as in VS Code. It shows only the actions that fit the place: in
Herdr or not, in a project with tasks, in a git folder, on a client, and with
the tools that are installed. The recent list keeps the ids of the last
actions, with no paths and no text that the person typed.

Each group is a module of this package with two parts: items(ctx), which adds
its actions with ctx.add, and ACTIONS, a table from an action id to the
function that runs it. An id that ends with ":" matches each id that starts
with it, for example "open:" for "open:work".
"""
import importlib
import os
import subprocess
import sys

from .. import core, panes, prefix, ui

GROUPS = ["projects", "tasks", "files", "git", "agents", "layout", "tabs", "sessions", "network",
          "herdspace", "herdr", "help"]
KEYS = {"ctrl-v": "right", "ctrl-s": "down", "ctrl-t": "tab"}


def group_module(name):
    return importlib.import_module(f"{__name__}.{name}")


class Context:
    """What an action needs: the folder, the path of hopen, the home folder,
    and the place in Herdr. ctx.place.where is the place that the person
    chose: right, down, tab, or ""."""

    def __init__(self, folder, self_path, home, place):
        self.dir, self.self_path, self.home, self.place = folder, self_path, home, place
        self.items = []

    @property
    def pane(self):
        return self.place.pane

    def add(self, action, group, text, hint=""):
        """Add one action, as (id, group, line, line with colors). The line
        with colors has the group in its color and the hint dim."""
        line = f"{group}: {text}"
        color = ui.sgr(ui.group_color(group)) + group + ui.RESET + f": {text}"
        if hint:
            pad = " " * (58 - len(line)) if len(line) < 58 else ""
            line = "%-58s %s" % (line, hint)
            color = color + pad + " " + ui.sgr(ui.UI_DIM) + hint + ui.RESET
        self.items.append((action, group, line, color))


def then_wait(action, *args):
    """Run a command, or a function that prints a result. In a popup, wait for
    Enter, so that the person can read the result."""
    if callable(action):
        try:
            action(*args)
        except Exception:
            pass
    else:
        try:
            core.run([action, *args])
        except OSError as error:
            print(f"hopen: {action}: {error.strerror}", file=sys.stderr)
    sys.stdout.flush()
    if panes.in_popup():
        print("\n  Press Enter to close.", end="", flush=True)
        try:
            sys.stdin.readline()
        except OSError:
            pass
    return 0


def owner(action):
    """The names of the groups whose table has ACTION."""
    found = []
    for name in GROUPS:
        for key in group_module(name).ACTIONS:
            if action == key or (key.endswith(":") and action.startswith(key)):
                found.append(name)
                break
    return found


def items(ctx):
    for name in GROUPS:
        group_module(name).items(ctx)


def recent_file(home):
    cache = os.environ.get("XDG_CACHE_HOME") or os.path.join(home, ".cache")
    return os.path.join(cache, "herdspace", "palette-recent")


def remember(action, path):
    """Put ACTION first in the recent list, with at most 4 older ids. Agent
    ids change, so they stay out."""
    if action.startswith("agent:"):
        return
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
    except OSError:
        return
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            lines = handle.read().split("\n")
        if lines and lines[-1] == "":
            lines.pop()
    except OSError:
        lines = []
    keep = [line for line in lines if line != action][:4]
    try:
        with open(path + ".new", "w", encoding="utf-8") as handle:
            handle.write("".join(line + "\n" for line in [action] + keep))
        os.replace(path + ".new", path)
    except OSError:
        pass


def menu(ctx, recent_path, read=None):
    """Show the menu, and return (id, place), or None. In fzf, Ctrl+V, Ctrl+S,
    and Ctrl+T choose the place. In the numbered menu, a word after the name
    or the number does: "edit right", "3 down", "git tab". The recent actions
    come first. With no fzf, the numbered menu has a heading for each group.
    An unknown answer raises ui.NoItem."""
    recent = []
    try:
        with open(recent_path, encoding="utf-8", errors="replace") as handle:
            ids = [line for line in handle.read().split("\n") if line]
    except OSError:
        ids = []
    for action in ids:
        match = next((item for item in ctx.items if item[0] == action), None)
        if match:
            recent.append((match[0], "Recently used", match[2], match[3]))
    rows = recent + ctx.items
    if ui.has_fzf():
        header = "Type to filter. Enter runs. Esc closes. At the right: the key or the command of each action."
        if ctx.pane:
            key = prefix.now(ctx.home)
            header += (f"\nThis palette: Cmd+Shift+P, or {key}, then A. On Linux, Cmd keys are Ctrl+Shift"
                       f" (Cmd+P is {key}, then F).")
            header += "\nA program opens: Ctrl+V on the right, Ctrl+S below, Ctrl+T in a new tab."
        field = "4" if ui.ui_color() else "3"
        text = "\n".join("\t".join(row) for row in rows)
        out = ui.run_fzf("Command palette", text, "--ansi", "--delimiter", "\t", "--with-nth", field, "--prompt",
                         "> ", "--header", header, "--expect", "ctrl-v,ctrl-s,ctrl-t", "--height", "100%",
                         "--reverse", "--no-multi", "--tiebreak=index")
        lines = out.split("\n")
        key, chosen = (lines + ["", ""])[:2]
        action = chosen.split("\t")[0]
        if not action:
            return None
        return action, KEYS.get(key, "")
    last = ""
    for number, row in enumerate(rows, 1):
        if row[1] != last:
            print(f"\n  {row[1]}", file=sys.stderr)
            last = row[1]
        print("  %3d) %s" % (number, row[2]), file=sys.stderr)
    if ctx.pane:
        print("\n  A word after the action opens a program in another place: right, down, or tab.", end="",
              file=sys.stderr)
    print("\n  Action? Type a number or a name: ", end="", file=sys.stderr, flush=True)
    answer = (read or ui._tty_line)()
    where = ""
    for word in ("right", "down", "tab"):
        if answer.endswith(" " + word):
            where, answer = word, answer[: -len(word) - 1]
            break
    if answer == "":
        return None
    ids = [row[0] for row in rows]
    if answer.isdigit():
        action = ids[int(answer) - 1] if 0 < int(answer) <= len(ids) else ""
    else:
        action = answer if answer in ids else ""
    if not action:
        raise ui.NoItem(f"No action {answer}.")
    return action, where


def run(ctx, action):
    for name in GROUPS:
        table = group_module(name).ACTIONS
        for key, func in table.items():
            if action == key or (key.endswith(":") and action.startswith(key)):
                result = func(ctx, action)
                return 0 if result is None else result
    return 0


def palette(self_path, home, print_only=False):
    """Show the actions that fit the current folder and place, and run the one
    that the person chooses. With PRINT_ONLY, print the actions only."""
    folder = os.environ.get("HERDR_ACTIVE_PANE_CWD") or os.environ.get("PWD") or os.getcwd()
    ctx = Context(folder, self_path, home, panes.Place.active())
    items(ctx)
    if print_only:
        for action, _, line, _ in ctx.items:
            print(f"{action}\t{line}")
        return 0
    if not (sys.stdin.isatty() and sys.stdout.isatty()):
        raise core.Fail("hopen --palette needs a terminal.")
    path = recent_file(home)
    try:
        chosen = menu(ctx, path)
    except ui.NoItem as error:
        print(f"  [err]  {error}", file=sys.stderr)
        return 1
    if not chosen:
        return 0
    action, ctx.place.where = chosen
    remember(action, path)
    try:
        os.chdir(folder)
    except OSError:
        raise core.Fail(f"No folder {folder}.")
    return run(ctx, action)
