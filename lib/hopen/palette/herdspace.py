"""The herdspace group of the command palette."""
import os
import re
import shutil
import subprocess
import sys

from .. import core, look, panes, prefix, ui
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
        ctx.add("hs-prefix", "herdspace", "Change the Herdr prefix key", f"now {prefix.now(ctx.home)}")
        ctx.add("hs-theme", "herdspace", "Change the Herdr theme", f"now {look.theme(ctx.home)}")
        ctx.add("hs-color", "herdspace", "Change the Herdr accent color", f"now {look.color_name(look.accent(ctx.home))}")


def run_here(*args):
    sys.stdout.flush()
    core.exec_program(list(args))


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
    core.run(["herdspace", "keys"])
    pick = choose("Keys", "normal\tnormal: Cmd+T, Cmd+W, and Cmd+K stay with Ghostty\n"
                          "herdr\therdr: Cmd+T, Cmd+W, and Cmd+K go to Herdr")
    if not pick:
        raise SystemExit(0)
    if ctx.pane:
        panes.new_tab_run(ctx.place, "keys", ctx.home, f"herdspace keys {pick}")
        return 0
    run_here("herdspace", "keys", pick)


def editor_mode(ctx, action):
    core.run(["herdspace", "editor"])
    pick = choose("Editor", "reader\treader: no warnings and no spell marks\nnormal\tnormal: the defaults of LazyVim")
    if not pick:
        raise SystemExit(0)
    return then_wait("herdspace", "editor", pick)


# The keys that the prefix menu offers, with the reason for each.
PREFIXES = [
    ("ctrl+space", "one hand presses both keys. The herdspace default."),
    ("ctrl+a", "next to Caps Lock. The shell then needs Ctrl+A twice to go to the line start."),
    ("ctrl+s", "next to Ctrl+A. Some programs use it to save."),
    ("ctrl+b", "the default of Herdr and tmux."),
]


def prefix_rows(now):
    rows = []
    for key, why in PREFIXES:
        mark = "  (now)" if key == now else ""
        rows.append(f"{key}\t%-12s %s{mark}" % (prefix.label(key), why))
    rows.append("other\tAnother key       Type a key, for example ctrl+q or cmd+shift+space.")
    return "\n".join(rows)


def change_prefix(ctx, action):
    now = prefix.current(ctx.home)
    print(f"  The prefix of Herdr: {prefix.label(now)}. Choose a new one. Esc keeps it.", flush=True)
    pick = choose("Prefix", prefix_rows(now))
    if pick == "other":
        pick = ui.ask_text("The key, as Herdr writes it (ctrl+q)").strip()
    if not pick or pick == now:
        raise SystemExit(0)
    return then_wait("herdspace", "prefix", pick)


def change_theme(ctx, action):
    now = look.theme(ctx.home)
    print(f"  The theme of Herdr: {now}. Choose a new one. Esc keeps it.", flush=True)
    pick = choose_look("Theme", look.theme_rows(now, look.menu_colors()))
    if not pick or pick == now:
        raise SystemExit(0)
    return then_wait("herdspace", "theme", pick)


def change_color(ctx, action):
    now = look.accent(ctx.home)
    print(f"  The accent color of Herdr: {look.color_name(now)}. Choose a new one. Esc keeps it.", flush=True)
    pick = choose_look("Color", look.color_rows(now, look.menu_colors()))
    if not pick or (pick == "default" and not now) or dict(look.COLORS).get(pick) == now:
        raise SystemExit(0)
    return then_wait("herdspace", "color", pick)


def choose_look(prompt, rows):
    try:
        return ui.choose(prompt, rows, ansi=True)
    except ui.NoItem as error:
        print(f"  [err]  {error}", file=sys.stderr)
        raise SystemExit(1)


ACTIONS = {
    "hs-version": lambda ctx, action: then_wait("herdspace", "--version"),
    "hs-update": update,
    "hs-keys": keys,
    "hs-editor": editor_mode,
    "hs-prefix": change_prefix,
    "hs-theme": change_theme,
    "hs-color": change_color,
}
