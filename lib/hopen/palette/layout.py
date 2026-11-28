"""The Layout group of the command palette."""
import os

from .. import panes, templates
from . import then_wait


def template_dir(home):
    return os.environ.get("HOPEN_TEMPLATES") or os.path.join(
        os.environ.get("XDG_CONFIG_HOME") or os.path.join(home, ".config"), "hopen", "templates")


def items(ctx):
    if ctx.pane:
        for line in templates.show_templates(template_dir(ctx.home))[1:]:
            name = line.split(" ")[0]
            if name != "plain":
                ctx.add(f"apply:{name}", "Layout", f"Split the current tab with the template {name}", f"hopen --apply {name}")
        ctx.add("split-right", "Layout", "Split right", "Ctrl+B V")
        ctx.add("split-down", "Layout", "Split down", "Ctrl+B -")
        ctx.add("zoom", "Layout", "Zoom the pane, or return", "Ctrl+B Z")
    ctx.add("templates", "Layout", "Show every template", "hopen --templates")


ACTIONS = {
    "apply:": lambda ctx, action: then_wait(ctx.self_path, "--apply", action[len("apply:"):]),
    "split-right": lambda ctx, action: panes.split_run(ctx.place, "right", ctx.dir),
    "split-down": lambda ctx, action: panes.split_run(ctx.place, "down", ctx.dir),
    "zoom": lambda ctx, action: panes.herdr_run("pane", "zoom", "--pane", ctx.pane, "--toggle"),
    "templates": lambda ctx, action: then_wait(ctx.self_path, "--templates"),
}
