"""The Projects group of the command palette."""
import os
import sys

from .. import core, lists, ui
from . import then_wait


def session_command():
    """The command that attaches to the current session."""
    session = os.environ.get("HERDR_SESSION", "default")
    return "herdr" if session in ("default", "") else f"herdr --session {session}"


def items(ctx):
    if ctx.pane:
        ctx.add("here", "Projects", "Open this folder as its own workspace", "herdr workspace create")
        ctx.add("window", "Projects", "Open this session in a new window", session_command())
    else:
        ctx.add("folder", "Projects", "Open this folder in Herdr", "hopen .")
        found, _ = lists.find_lists(ctx.home)
        for name, _path in found:
            ctx.add(f"open:{name}", "Projects", f"Open the list {name}", f"hopen {name}")
    ctx.add("all", "Projects", "Open every list in the background", "hopen --all")
    ctx.add("lists", "Projects", "Show every list and its state", "hopen --list")
    ctx.add("convert", "Projects", "Write a herdspace.toml from a VS Code list", "hopen --convert")


def here(ctx, action):
    from ..panes import herdr_run
    return herdr_run("workspace", "create", "--cwd", ctx.dir, "--label", os.path.basename(ctx.dir), "--focus")


def window(ctx, action):
    return then_wait(lambda: print(
        "  Open a new terminal window, connect to this machine, and run:\n\n"
        f"    {session_command()}\n\n"
        "  Each window keeps its own workspace and tab. Keep the two windows on\n"
        "  different tabs while an agent runs: https://github.com/herdrdev/herdr/issues/5749"))


def folder(ctx, action):
    sys.stdout.flush()
    core.exec_program([ctx.self_path, "."])


def open_list(ctx, action):
    sys.stdout.flush()
    core.exec_program([ctx.self_path, action[len("open:"):]])


def convert(ctx, action):
    name = ui.ask_text("The name of the VS Code list")
    if name:
        then_wait(ctx.self_path, "--convert", name)
    return 0


ACTIONS = {
    "here": here,
    "window": window,
    "folder": folder,
    "open:": open_list,
    "all": lambda ctx, action: then_wait(ctx.self_path, "--all", "--no-attach"),
    "lists": lambda ctx, action: then_wait(ctx.self_path, "--list"),
    "convert": convert,
}
