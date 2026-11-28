"""The herdspace group of the command palette."""
import os
import re
import shutil
import subprocess
import sys

from .. import panes, ui
from . import then_wait


def role(home):
    data = os.environ.get("XDG_DATA_HOME") or os.path.join(home, ".local", "share")
    try:
        with open(os.path.join(data, "herdspace", "last-setup"), encoding="utf-8", errors="replace") as handle:
            return next((m.group(1) for m in (re.match(r"^role=(.*)$", l) for l in handle.read().split("\n")) if m), "")
    except OSError:
        return ""


def items(ctx):
    if not shutil.which("herdspace"):
        return
    ctx.add("hs-version", "herdspace", "Show the installed and the latest version", "herdspace --version")
    ctx.add("hs-update", "herdspace", "Update herdspace", "herdspace update")
    kind = role(ctx.home)
    if kind in ("client", "both"):
        ctx.add("hs-keys", "herdspace", "Show or change the Ghostty keys", "herdspace keys")
    if kind in ("server", "both"):
        ctx.add("hs-editor", "herdspace", "Show or change the editor mode: reader or normal", "herdspace editor")


def run_here(*args):
    sys.stdout.flush()
    os.execvp(args[0], list(args))


def update(ctx, action):
    if ctx.pane:
        panes.new_tab_run(ctx.place, "update", ctx.home, "herdspace update")
        return 0
    run_here("herdspace", "update")


def choose(prompt, rows):
    try:
        return ui.choose(prompt, rows)
    except ui.NoItem as error:
        print(f"  [err]  {error}", file=sys.stderr)
        raise SystemExit(1)


def keys(ctx, action):
    subprocess.run(["herdspace", "keys"])
    pick = choose("Keys", "normal\tnormal: Cmd+T, Cmd+W, and Cmd+K stay with Ghostty\n"
                          "herdr\therdr: Cmd+T, Cmd+W, and Cmd+K go to Herdr")
    if not pick:
        raise SystemExit(0)
    if ctx.pane:
        panes.new_tab_run(ctx.place, "keys", ctx.home, f"herdspace keys {pick}")
        return 0
    run_here("herdspace", "keys", pick)


def editor_mode(ctx, action):
    subprocess.run(["herdspace", "editor"])
    pick = choose("Editor", "reader\treader: no warnings and no spell marks\nnormal\tnormal: the defaults of LazyVim")
    if not pick:
        raise SystemExit(0)
    return then_wait("herdspace", "editor", pick)


ACTIONS = {
    "hs-version": lambda ctx, action: then_wait("herdspace", "--version"),
    "hs-update": update,
    "hs-keys": keys,
    "hs-editor": editor_mode,
}
