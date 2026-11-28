"""The Agents group of the command palette, with the Herdr integrations of the agent programs."""
import json
import re
import shutil
import sys

from .. import core, panes, ui
from . import then_wait

ORDER = {"blocked": 0, "done": 1, "working": 2, "idle": 3}
STATUS = re.compile(r"^([a-z-]+)( \(experimental\))?: ([^(]*[^ (])( \(v[0-9]+\))?.*$")
PROGRAMS = ["claude", "codex", "opencode", "gemini", "pi", "amp", "aider"]


def integrations():
    """One (name, state) for each Herdr integration, for example
    ("claude", "current (v11)") or ("kimi", "not installed")."""
    out = []
    for line in panes.herdr("integration", "status").split("\n"):
        if not line:
            continue
        match = STATUS.match(line)
        text = f"{match.group(1)}\t{match.group(3)}{match.group(4) or ''}" if match else line
        name, _, state = text.partition("\t")
        out.append((name, state))
    return out


def show_integrations():
    print("  The Herdr integration of each agent program:\n")
    for name, state in integrations():
        print("  %-18s %s" % (name, state))
    print("\n  An agent needs its integration only for the state and the resume of\n"
          "  its conversation. See the agents page of the herdspace docs.")


def agents_sorted():
    """One (pane, agent, state, folder) for each agent, the blocked and done agents first."""
    try:
        agents = json.loads(panes.herdr("agent", "list")).get("result", {}).get("agents", [])
    except ValueError:
        return []
    agents = sorted(agents, key=lambda a: ORDER.get(a.get("agent_status"), 4))
    return [(a.get("pane_id", ""), a.get("agent") or "agent", a.get("agent_status", ""), a.get("cwd", "")) for a in agents]


def items(ctx):
    if ctx.pane:
        found = agents_sorted()
        for pane, kind, state, cwd in found:
            if pane:
                ctx.add(f"agent:{pane}", "Agents", f"Go to {kind} ({state}) in {core.short_path(cwd, ctx.home)}", "Cmd+K")
        if found:
            ctx.add("explain", "Agents", "Explain the state of an agent", "herdr agent explain")
        for kind in PROGRAMS:
            if shutil.which(kind):
                ctx.add(f"start:{kind}", "Agents", f"Start {kind} in a new pane", kind)
    if shutil.which("herdr"):
        ctx.add("integ-status", "Agents", "Show the Herdr integrations", "herdr integration status")
        ctx.add("integ-add", "Agents", "Add the Herdr integration for an agent", "herdr integration install")
        ctx.add("integ-remove", "Agents", "Remove the Herdr integration of an agent", "herdr integration uninstall")


def pick(prompt, rows):
    try:
        return ui.choose(prompt, "\n".join(rows))
    except ui.NoItem as error:
        print(f"  [err]  {error}", file=sys.stderr)
        raise SystemExit(1)


def integ_add(ctx, action):
    name = pick("Integration to add", [f"{n}\t{n}  ({s})" for n, s in integrations() if not s.startswith("current")])
    if not name:
        raise SystemExit(0)
    return then_wait("herdr", "integration", "install", name)


def integ_remove(ctx, action):
    name = pick("Integration to remove", [f"{n}\t{n}  ({s})" for n, s in integrations() if not s.startswith("not installed")])
    if not name:
        raise SystemExit(0)
    if not ui.confirm(f"Remove the Herdr integration of {name}? Herdr then shows its state from the screen only."):
        raise SystemExit(0)
    return then_wait("herdr", "integration", "uninstall", name)


def explain(ctx, action):
    pane = pick("Agent", [f"{p}\t{k} ({s})  {c}" for p, k, s, c in agents_sorted()])
    if pane:
        then_wait("herdr", "agent", "explain", pane)
    return 0


def start(ctx, action):
    program = action[len("start:"):]
    panes.run_at(ctx.place, "right", program, ctx.dir, program)


ACTIONS = {
    "agent:": lambda ctx, action: panes.herdr_run("agent", "focus", action[len("agent:"):]),
    "integ-status": lambda ctx, action: then_wait(show_integrations),
    "integ-add": integ_add,
    "integ-remove": integ_remove,
    "explain": explain,
    "start:": start,
}
