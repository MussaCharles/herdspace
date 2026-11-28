"""The Herdr group of the command palette."""
import os
import shutil

from . import then_wait


def update_check(home):
    return os.path.join(home, ".local", "bin", "herdr-update-check")


def items(ctx):
    if not shutil.which("herdr"):
        return
    if os.access(update_check(ctx.home), os.X_OK):
        ctx.add("herdr-update", "Herdr", "Check for a new Herdr version", "herdr-update-check --now")
    ctx.add("herdr-reload", "Herdr", "Reload the Herdr configuration", "herdr server reload-config")
    ctx.add("herdr-status", "Herdr", "Show the state of the Herdr server", "herdr status")


ACTIONS = {
    "herdr-update": lambda ctx, action: then_wait(update_check(ctx.home), "--now"),
    "herdr-reload": lambda ctx, action: then_wait("herdr", "server", "reload-config"),
    "herdr-status": lambda ctx, action: then_wait("herdr", "status"),
}
