"""The Git group of the command palette."""
import json
import os
import shutil
import subprocess
import sys

from .. import core, panes, prefix, ui
from . import then_wait


def worktrees(folder):
    """One (path, branch, workspace) for each linked worktree."""
    try:
        data = json.loads(panes.herdr("worktree", "list", "--cwd", folder))
    except ValueError:
        return []
    return [(w.get("path", ""), w.get("branch") or "-", w.get("workspace_id") or "")
            for w in data.get("result", {}).get("worktrees", []) if w.get("is_linked_worktree")]


def items(ctx):
    inside = core.run(["git", "-C", ctx.dir, "rev-parse", "--is-inside-work-tree"], capture_output=True)
    if inside.returncode != 0:
        return
    if shutil.which("lazygit"):
        ctx.add("git", "Git", "Git status (lazygit)", f"Cmd+Shift+G, {prefix.now(ctx.home)} D")
        if ctx.pane:
            ctx.add("git-tab", "Git", "Open lazygit in a new tab", "lazygit")
    if ctx.pane:
        ctx.add("wt-new", "Git", "New worktree for an agent, on a new branch", f"{prefix.now(ctx.home)} Shift+G")
        ctx.add("wt-open", "Git", "Open a worktree", "herdr worktree open")
        ctx.add("wt-list", "Git", "Show the worktrees", "herdr worktree list")
        ctx.add("wt-remove", "Git", "Remove a worktree", "herdr worktree remove")


def wt_new(ctx, action):
    name = ui.ask_text("The name of the new branch")
    if not name:
        raise SystemExit(0)
    return then_wait("herdr", "worktree", "create", "--cwd", ctx.dir, "--branch", name, "--focus")


def wt_pick(ctx, action):
    found = worktrees(ctx.dir)
    try:
        pick = ui.choose("Worktree", "\n".join(f"{path}\t{branch}  {path}" for path, branch, _ in found))
    except ui.NoItem as error:
        print(f"  [err]  {error}", file=sys.stderr)
        raise SystemExit(1)
    if not pick:
        raise SystemExit(0)
    if action == "wt-open" and ctx.place.where:
        panes.run_at(ctx.place, "here", os.path.basename(pick), pick)
        return 0
    if action == "wt-open":
        return panes.herdr_run("worktree", "open", "--cwd", ctx.dir, "--path", pick, "--focus")
    workspace = next((ws for path, _, ws in found if path == pick), "")
    if not workspace:
        then_wait(lambda: print(f"  The worktree {pick} has no workspace. Open it first, then remove it."))
        raise SystemExit(0)
    if not ui.confirm(f"Remove the worktree {pick}? Changes that you did not commit are lost."):
        raise SystemExit(0)
    return then_wait("herdr", "worktree", "remove", "--workspace", workspace)


def wt_list(ctx, action):
    def show():
        data = json.loads(panes.herdr("worktree", "list", "--cwd", ctx.dir))
        for w in data.get("result", {}).get("worktrees", []):
            print("  " + (w.get("branch") or "-") + "  " + w.get("path", ""))
    return then_wait(show)


ACTIONS = {
    "git": lambda ctx, action: panes.run_at(ctx.place, "here", "git", ctx.dir, "lazygit"),
    "git-tab": lambda ctx, action: panes.run_at(ctx.place, "tab", "git", ctx.dir, "lazygit"),
    "wt-new": wt_new,
    "wt-open": wt_pick,
    "wt-remove": wt_pick,
    "wt-list": wt_list,
}
