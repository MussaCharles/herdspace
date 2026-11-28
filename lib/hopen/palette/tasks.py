"""The Tasks group of the command palette."""
import shlex

from .. import lists, panes, tasks


def items(ctx):
    match = tasks.project_for_dir(ctx.home, ctx.dir)
    if not match:
        return
    path, label = match
    try:
        lines = lists.read_list(path, "items")
    except Exception:
        return
    for line in lines:
        fields = line.split("\x1e") + ["", "", ""]
        if fields[0] == "K" and fields[1] == label and fields[2]:
            ctx.add(f"task:{fields[2]}", "Tasks", f"Run the task {fields[2]}: {fields[3]}", f"hopen --task {fields[2]}")


def run_task(ctx, action):
    command = f"{shlex.quote(ctx.self_path)} --task {shlex.quote(action[len('task:'):])}"
    panes.run_at(ctx.place, "here", "task", ctx.dir, command)


ACTIONS = {"task:": run_task}
