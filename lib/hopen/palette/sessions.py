"""The Sessions group of the command palette."""
import os
import shutil
import sys

from .. import panes, ui
from . import then_wait


def items(ctx):
    if shutil.which("herdr"):
        ctx.add("sessions", "Sessions", "Show the sessions", "herdr session list")
        ctx.add("stop-session", "Sessions", "Stop a session", "herdr session stop")


def stop_session(ctx, action):
    rows = [line.split() for line in panes.herdr("session", "list").split("\n")[1:]]
    running = [f"{row[0]}\t{row[0]}" for row in rows if len(row) > 1 and row[1] == "running"]
    try:
        pick = ui.choose("Session", "\n".join(running))
    except ui.NoItem as error:
        print(f"  [err]  {error}", file=sys.stderr)
        raise SystemExit(1)
    if not pick:
        raise SystemExit(0)
    text = f"Stop the session {pick}, and end every program in it?"
    if pick == (os.environ.get("HERDR_SESSION") or "default"):
        text = f"Stop the session {pick}, the one that you use now, and end every program in it?"
    if not ui.confirm(text):
        raise SystemExit(0)
    if pick == "default":
        return then_wait("herdr", "server", "stop")
    return then_wait("herdr", "session", "stop", pick)


ACTIONS = {
    "sessions": lambda ctx, action: then_wait("herdr", "session", "list"),
    "stop-session": stop_session,
}
