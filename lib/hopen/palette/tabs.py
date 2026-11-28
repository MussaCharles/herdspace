"""The Workspace and tabs group of the command palette."""
from .. import panes, ui

GROUP = "Workspace and tabs"


def items(ctx):
    if ctx.pane:
        ctx.add("new-tab", GROUP, "New tab", "Cmd+T, Ctrl+B C")
        ctx.add("new-ws", GROUP, "New workspace in this folder", "Ctrl+B Shift+N")
        ctx.add("rename-ws", GROUP, "Rename the workspace", "Ctrl+B Shift+W")
        ctx.add("rename-tab", GROUP, "Rename the tab", "Ctrl+B Shift+T")
        ctx.add("rename-pane", GROUP, "Rename the pane", "Ctrl+B Shift+P")
        ctx.add("close-tab", GROUP, "Close the tab", "Cmd+W, Ctrl+B Shift+X")


def rename(ctx, action):
    name = ui.ask_text("The new name")
    if not name:
        raise SystemExit(0)
    target = {"rename-ws": ("workspace", ctx.place.workspace), "rename-tab": ("tab", ctx.place.tab),
              "rename-pane": ("pane", ctx.pane)}[action]
    return panes.herdr_run(target[0], "rename", target[1], name)


def close_tab(ctx, action):
    if not ui.confirm("Close this tab and end the programs in it?"):
        return 1
    return panes.herdr_run("tab", "close", ctx.place.tab)


ACTIONS = {
    "new-tab": lambda ctx, action: panes.herdr_run("tab", "create", "--workspace", ctx.place.workspace, "--cwd", ctx.dir, "--focus"),
    "new-ws": lambda ctx, action: panes.herdr_run("workspace", "create", "--cwd", ctx.dir, "--focus"),
    "rename-ws": rename,
    "rename-tab": rename,
    "rename-pane": rename,
    "close-tab": close_tab,
}
