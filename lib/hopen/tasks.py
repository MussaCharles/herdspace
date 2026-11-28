"""The tasks of a list: hopen --task, with the environment of the project.

A task is a name and a command of a project, like a task of tasks.json in VS
Code. In Herdr, a task runs in a new pane below the current pane. Outside
Herdr, it runs in the current terminal.
"""
import json
import os
import shlex
import subprocess
import sys
import time

from . import core, lists, trust, ui

DOCS = "https://github.com/MussaCharles/herdspace/blob/main/docs/hopen.md#tasks"


def project_for_dir(home, folder):
    """Return (list file, label) for the project that holds FOLDER, or None.
    The deepest project folder wins, so a project wins over the parent
    workspace of its list."""
    found, _ = lists.find_lists(home)
    best, best_len = None, 0
    for _, path in found:
        try:
            lines = lists.read_list(path, "items")
        except Exception:
            continue
        for line in lines:
            fields = line.split("\x1e")
            if fields[0] in ("R", "P") and len(fields) > 2:
                root = fields[2]
                if (folder == root or folder.startswith(root + "/")) and len(root) > best_len:
                    best, best_len = (path, fields[1]), len(root)
    return best


def env_for(items, label):
    """The environment values of one project, as KEY=VALUE items: its env
    values, and the values of its env file that env does not set."""
    envs = file_env = ""
    for line in items:
        fields = line.split("\x1e") + [""] * 6
        if not envs and fields[0] in ("R", "P") and fields[1] == label and fields[5] != "-":
            envs = fields[5]
        if not file_env and fields[0] == "F" and fields[1] == label:
            file_env = fields[4]
    values = [item for item in envs.split("\x1f") if item] if envs else []
    if file_env:
        own = {item.split("=", 1)[0] for item in values}
        values += [item for item in file_env.split("\x1f") if item and item.split("=", 1)[0] not in own]
    return values


def keep_pane_name(pane, name, wait=1):
    """Set the name of PANE again if a plugin changed it. The Auto Title plugin
    can name a new pane when it first sees it, also a pane that has a name
    already. It keeps a name that changes after that first sighting."""
    for _ in range(2):
        time.sleep(wait)
        try:
            out = subprocess.run(["herdr", "pane", "list"], capture_output=True, text=True).stdout
            label = next((p.get("label") or "" for p in json.loads(out)["result"]["panes"] if p["pane_id"] == pane), "")
        except Exception:
            return
        if label != name:
            if subprocess.run(["herdr", "pane", "rename", pane, name], capture_output=True).returncode != 0:
                return


def run_task(name, home, state_dir, trust_flag):
    """Run the task NAME of the project of the current folder. With no NAME,
    ask in a terminal, or print the tasks."""
    folder = os.environ.get("HERDR_ACTIVE_PANE_CWD") or os.environ.get("PWD") or os.getcwd()
    match = project_for_dir(home, folder)
    if match is None:
        raise core.Fail(f"No project of a list holds the folder {core.short_path(folder, home)}.")
    path, label = match
    try:
        items = lists.read_list(path, "items")
    except lists.ListError as error:
        print(error, file=sys.stderr)
        raise core.Fail(f"Could not read {path}.")
    tasks = [(f[2], f[3]) for f in (line.split("\x1e") + ["", ""] for line in items) if f[0] == "K" and f[1] == label]
    if not tasks:
        raise core.Fail(f"The project {label} has no tasks. Add tasks to {core.short_path(path, home)}. See {DOCS}")
    if not name:
        if sys.stdin.isatty() and sys.stdout.isatty():
            menu = "\n".join("%s\t%-14s %s" % (task, task, command) for task, command in tasks)
            try:
                name = ui.choose("Run which task", menu)
            except ui.NoItem as error:
                print(f"  [err]  {error}", file=sys.stderr)
                raise SystemExit(1)
            if not name:
                return 0
        else:
            for task, command in tasks:
                print(f"{task}\t{command}")
            return 0
    command = next((c for t, c in tasks if t == name), "")
    if not command:
        names = "".join(task + " " for task, _ in tasks)
        raise core.Fail(f"The project {label} has no task {name}. Its tasks: {names}")
    actions = "\n".join(trust.list_actions(items))
    extra = "\n".join(line for line in items if line.startswith("F\x1e")).encode("utf-8", "surrogateescape")
    if not trust.list_trusted(path, actions, extra, state_dir, trust_flag):
        raise core.Fail("hopen runs a task only from an approved list. Run hopen --task in a terminal to approve "
                        f"{core.short_path(path, home)}, or add --trust.")
    env = env_for(items, label)
    pane = os.environ.get("HERDR_PANE_ID") or os.environ.get("HERDR_ACTIVE_PANE_ID") or ""
    if pane:
        args = ["herdr", "pane", "split", pane, "--direction", "down", "--ratio", "0.65", "--focus"]
        for item in env:
            args += ["--env", item]
        result = subprocess.run(args, capture_output=True, text=True)
        if result.returncode != 0:
            raise core.Fail("Could not split the pane.")
        new = json.loads(result.stdout)["result"]["pane"]["pane_id"]
        subprocess.run(["herdr", "pane", "rename", new, name], stdout=subprocess.DEVNULL)
        subprocess.run(["herdr", "pane", "run", new, f"cd {shlex.quote(folder)} && {command}"], stdout=subprocess.DEVNULL)
        print(f"  [info] Task {name} runs in a new pane: {command}", flush=True)
        keep_pane_name(new, name)
        return 0
    print(f"  [info] Task {name}: {command}", flush=True)
    for item in env:
        key, _, value = item.partition("=")
        os.environ[key] = value
    os.chdir(folder)
    shell = os.environ.get("SHELL") or "/bin/sh"
    os.execvp(shell, [shell, "-c", command])
