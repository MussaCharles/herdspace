"""The Herdr sessions of hopen: start one, open the projects of a list,
start the programs again after a restart, apply a template, and attach.

A Run holds what one hopen run knows, where bash used global values: the
session, the list file or the folder, the options, and the names that the
guard keeps.
"""
import json
import os
import subprocess
import sys
import time

from . import core, lists, templates, trust

RS, US = "\x1e", "\x1f"


def info(text):
    print(f"  [info] {text}", flush=True)


class Run:
    def __init__(self, home, session="", list_file="", folder="", template_flag="", trust_flag=False):
        self.home, self.session, self.list_file, self.folder = home, session, list_file, folder
        self.template_flag, self.trust_flag = template_flag, trust_flag
        env = os.environ.get
        self.template_dir = env("HOPEN_TEMPLATES") or os.path.join(
            env("XDG_CONFIG_HOME") or os.path.join(home, ".config"), "hopen", "templates")
        self.state_dir = os.path.join(env("XDG_STATE_HOME") or os.path.join(home, ".local", "state"), "hopen")
        self.guard_pairs, self.guard_tabs = [], []
        self.started = False

    # Herdr, for this session.
    def env(self):
        return {**os.environ, "HERDR_SESSION": self.session}

    def herdr(self, *args, session=True):
        try:
            result = core.run(["herdr", *args], capture_output=True, text=True,
                                    env=self.env() if session else None)
        except OSError:
            return 127, ""
        return result.returncode, result.stdout

    def herdr_quiet(self, *args, session=True):
        try:
            core.run(["herdr", *args], stdout=subprocess.DEVNULL, env=self.env() if session else None)
        except OSError:
            pass

    def result(self, *args, session=True):
        code, out = self.herdr(*args, session=session)
        try:
            return json.loads(out).get("result", {})
        except ValueError:
            return {}

    def session_answers(self):
        code, out = self.herdr("workspace", "list")
        return code == 0 and "workspace_list" in out

    def start_session(self):
        # nohup and disown in bash: the server runs on after hopen ends.
        core.popen(["herdr", "server"], env=self.env(), stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL, start_new_session=True)
        self.started = True
        for _ in range(40):
            if self.session_answers():
                return
            time.sleep(0.25)
        raise core.Fail(f"The session {self.session} did not start.")

    def workspaces(self):
        """(label, workspace id) for each workspace."""
        return [(w["label"], w["workspace_id"]) for w in self.result("workspace", "list").get("workspaces", [])]

    def panes_of(self, workspace):
        """(label, pane id) for each pane of WORKSPACE."""
        return [(p.get("label") or "", p["pane_id"]) for p in self.result("pane", "list").get("panes", [])
                if p.get("workspace_id") == workspace]

    def pane_is_idle(self, pane):
        """True if the pane shows its shell prompt, with no program."""
        for _ in range(20):
            code, out = self.herdr("pane", "process-info", "--pane", pane)
            if code == 0 and "shell_pid" in out:
                try:
                    p = json.loads(out)["result"]["process_info"]
                except (ValueError, KeyError):
                    return False
                return bool(p.get("shell_pid")) and p.get("foreground_process_group_id") == p.get("shell_pid")
            time.sleep(0.25)
        return False

    # The state file: one "label<TAB>template<TAB>id=name id=name" line for each workspace.
    def state_file(self):
        return os.path.join(self.state_dir, f"{self.session}.tsv")

    def remember_template(self, label, template, panes):
        path = self.state_file()
        os.makedirs(self.state_dir, exist_ok=True)
        try:
            with open(path, encoding="utf-8", errors="surrogateescape") as handle:
                rows = handle.read().split("\n")
        except OSError:
            rows = []
        if rows and rows[-1] == "":
            rows.pop()
        keep = [row for row in rows if row.split("\t")[0] != label]
        with open(path + ".tmp", "w", encoding="utf-8", errors="surrogateescape") as handle:
            handle.write("".join(row + "\n" for row in keep) + f"{label}\t{template}\t{panes}\n")
        os.replace(path + ".tmp", path)

    def template_exists(self, name):
        return templates.template_exists(self.template_dir, name)

    def template_panes(self, name):
        """The panes of a template as (pane, from, direction, size, command)."""
        out = []
        for line in templates.template_lines(self.template_dir, name):
            fields = line.split(None, 4)
            fields += [""] * (5 - len(fields))
            fields[4] = fields[4].rstrip()
            out.append(tuple(fields))
        return out

    def restart_programs(self):
        """Start each template program again in a pane that shows only its
        shell. Herdr restores the panes after a stop, but not their programs."""
        try:
            with open(self.state_file(), encoding="utf-8", errors="surrogateescape") as handle:
                rows = handle.read().split("\n")
        except OSError:
            return
        found = self.workspaces()
        restarted = 0
        for row in rows:
            if not row:
                continue
            label, template, saved = (row.split("\t") + ["", "", ""])[:3]
            if not self.template_exists(template) or template == "plain":
                continue
            # A tab of a workspace has the state label "workspace/tab".
            ws = next((wid for wl, wid in found if wl == label.split("/")[0]), "")
            if not ws:
                continue
            panes = self.panes_of(ws)
            ids = [pid for _, pid in panes]
            for pane, _from, _direction, _size, command in self.template_panes(template):
                # The saved ID comes first. The name is for state from older versions.
                pane_id = next((item.split("=", 1)[0] for item in saved.split(" ")
                                if "=" in item and item.split("=", 1)[1] == pane), "")
                if not pane_id or pane_id not in ids:
                    pane_id = next((pid for pl, pid in panes if pl == pane), "")
                if not pane_id:
                    continue
                self.guard_pairs.append((pane_id, pane))
                if not command or command == "-":
                    continue
                if self.pane_is_idle(pane_id):
                    self.herdr_quiet("pane", "run", pane_id, command)
                    restarted += 1
        if restarted:
            info(f"Session {self.session}: {restarted} programs started again.")

    def apply_template(self, name, root, env_args=(), session=True):
        """Split from ROOT with the template NAME, and start each program."""
        made = {}
        for pane, source, direction, size, command in self.template_panes(name):
            if source == "-":
                pane_id = root
            else:
                parent = made.get(source, "")
                if not parent:
                    core.warn(f"Template {name}: the pane {source} comes later or does not exist.")
                    continue
                result = self.result("pane", "split", parent, "--direction", direction, "--ratio", size, "--no-focus",
                                     *env_args, session=session)
                pane_id = result.get("pane", {}).get("pane_id", "")
            self.herdr_quiet("pane", "rename", pane_id, pane, session=session)
            self.guard_pairs.append((pane_id, pane))
            made[pane] = pane_id
            if command and command != "-":
                self.herdr_quiet("pane", "run", pane_id, command, session=session)

    def open_template(self, template, root, state_label, env_args):
        if template == "plain":
            return
        before = len(self.guard_pairs)
        self.apply_template(template, root, env_args)
        panes = " ".join(f"{pid}={name}" for pid, name in self.guard_pairs[before:])
        self.remember_template(state_label, template, panes)

    def guard_names(self, session=True):
        """Start the guard of the names in the background. See templates.guard."""
        seconds = os.environ.get("HOPEN_GUARD_SECONDS", "30")
        if not (self.guard_pairs or self.guard_tabs) or seconds == "0":
            return
        text = "".join(f"{p}\t{n}\n" for p, n in self.guard_pairs) + "\x1e" + "".join(f"{p}\t{n}\n" for p, n in self.guard_tabs)
        main = os.path.join(os.path.dirname(os.path.realpath(__file__)), "__main__.py")
        guard = subprocess.Popen([sys.executable, "-I", "-B", main, "internal", "guard", seconds], stdin=subprocess.PIPE,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
                                 env=self.env() if session else None, text=True)
        guard.stdin.write(text)
        guard.stdin.close()
        self.guard_pairs, self.guard_tabs = [], []

    def items(self):
        if self.folder:
            # A folder with no list: one workspace, with no commands or values.
            return [RS.join(["R", self.session, self.folder, self.template_flag or "plain", "-", "-"])]
        try:
            return lists.read_list(self.list_file, "items", self.template_flag)
        except lists.ListError as error:
            print(error, file=sys.stderr)
            raise core.Fail(f"Could not read {self.list_file}.")

    def prepare_session(self):
        """Start the session, and add each folder that has no workspace. A new
        workspace gets its template, its on-open command, and its extra tabs."""
        self.started = False
        if not self.session_answers():
            self.start_session()
        if self.started:
            self.restart_programs()
        items = self.items()
        actions = "\n".join(trust.list_actions(items))
        trusted = True
        if actions:
            extra = "\n".join(line for line in items if line.startswith("F" + RS)).encode("utf-8", "surrogateescape")
            if not trust.list_trusted(self.list_file, actions, extra, self.state_dir, self.trust_flag):
                trusted = False
                core.warn(f"hopen did not use the commands and values of {core.short_path(self.list_file, self.home)}."
                          " Run hopen in a terminal to approve them, or add --trust.")
        existing = [label for label, _ in self.workspaces()]
        added = 0
        current = current_folder = current_id = file_env = ""
        env_args = []
        for line in items:
            fields = line.split(RS, 5)
            fields += [""] * (6 - len(fields))
            kind, label, folder, template, extra, envs = fields
            if extra == "-" or not trusted:
                extra = ""
            if envs == "-" or not trusted:
                envs = ""
            if kind == "W":
                core.warn(label)
                continue
            if kind == "F":
                # The values of an env file, for the R or P line that comes next.
                file_env = extra
                continue
            if kind == "T":
                # A tab line: label, tab name (in folder), template, command.
                if label != current or not current_id:
                    continue
                if not self.template_exists(template):
                    core.warn(f"{label}/{folder}: no template named {template}. The tab opens with one pane.")
                    template = "plain"
                result = self.result("tab", "create", "--workspace", current_id, "--cwd", current_folder, "--label",
                                     folder, "--no-focus", *env_args)
                root = result.get("root_pane", {}).get("pane_id", "")
                self.guard_tabs.append((root, folder))
                self.open_template(template, root, f"{label}/{folder}", env_args)
                if extra:
                    self.herdr_quiet("pane", "run", root, extra)
                continue
            if kind == "R":
                label = self.session
            elif kind != "P":
                continue
            current, current_folder, current_id = label, folder, ""
            env_args = [arg for item in envs.split(US) if item for arg in ("--env", item)] if envs else []
            # A value from the env file is used only if env does not set the name.
            if file_env:
                own = {item.split("=", 1)[0] for item in envs.split(US) if item} if envs else set()
                env_args += [arg for item in file_env.split(US) if item and item.split("=", 1)[0] not in own
                             for arg in ("--env", item)]
            file_env = ""
            if label in existing:
                continue
            if not os.path.isdir(folder):
                core.warn(f"Skipped {label}: the folder {folder} does not exist.")
                continue
            if not self.template_exists(template):
                core.warn(f"{label}: no template named {template}. It opens with one pane.")
                template = "plain"
            result = self.result("workspace", "create", "--cwd", folder, "--label", label, "--no-focus", *env_args)
            root = result.get("root_pane", {}).get("pane_id", "")
            current_id = result.get("workspace", {}).get("workspace_id", "")
            # The on-open command runs first. The shell then starts the template program.
            if extra:
                self.herdr_quiet("pane", "run", root, extra)
            self.open_template(template, root, label, env_args)
            added += 1
        info(f"Session {self.session}: {added} workspaces added.")
        self.template_note(items, added)
        self.guard_names()

    def template_note(self, items, added):
        """Explain --template when it did not split each project: the template
        applies only to the workspaces that the run creates."""
        if not self.template_flag:
            return
        total = sum(1 for line in items if line.split(RS)[0] in ("R", "P"))
        existing = total - added
        if existing <= 0:
            return
        flag = self.template_flag
        if added == 0:
            info(f"--template {flag} splits only new projects, and each project of {self.session} has a workspace already.")
        else:
            info(f"--template {flag} split the {added} new projects. {existing} projects existed already.")
        print(f"         To split a project that exists, go to its tab in Herdr, and run: hopen --apply {flag}", flush=True)

    def attach(self):
        if os.environ.get("HERDR_ENV") == "1":
            raise core.Fail("You are in a Herdr pane. Press ctrl+b, then q, and run this command again.")
        sys.stdout.flush()
        core.exec_program(["herdr", "session", "attach", self.session])


def no_lists_error():
    raise core.Fail("No project lists. Create ~/my-projects.code-workspace or ~/my-projects/herdspace.toml.")


def found_lists(home):
    found, warnings = lists.find_lists(home)
    for line in warnings:
        print(line, file=sys.stderr)
    return found


def open_all(run):
    found = found_lists(run.home)
    if not found:
        no_lists_error()
    wanted = run.session
    if wanted and not any(name == wanted for name, _ in found):
        raise core.Fail(f"No project list for {wanted}.")
    for name, path in found:
        run.session, run.list_file = name, path
        run.prepare_session()
    if wanted:
        run.session = wanted
        run.attach()
    info(f"Run hopen with a session name to attach, for example: hopen {found[0][0]}")


def show_lists(run):
    found = found_lists(run.home)
    if not found:
        no_lists_error()
    print("%-22s %-9s %-11s %s" % ("SESSION", "STATE", "WORKSPACES", "LIST"))
    for name, path in found:
        run.session, run.list_file = name, path
        if run.session_answers():
            state, count = "running", str(len(run.workspaces()))
        else:
            state, count = "stopped", "-"
        print("%-22s %-9s %-11s %s" % (name, state, count, core.short_path(path, run.home)))


def apply_here(run, name):
    """Split the current tab of a Herdr pane with a template. A popup of Herdr
    has no pane of its own, so it applies to the active pane."""
    target = os.environ.get("HERDR_PANE_ID") or os.environ.get("HERDR_ACTIVE_PANE_ID") or ""
    if not target:
        raise core.Fail("Run --apply inside a Herdr pane.")
    if not run.template_exists(name):
        raise core.Fail(f"No template named {name}. Run hopen --templates.")
    if name == "plain":
        return
    panes = run.result("pane", "list", session=False).get("panes", [])
    tab = next((p["tab_id"] for p in panes if p["pane_id"] == target), "")
    count = len([p for p in panes if p["tab_id"] == tab])
    if count != 1:
        raise core.Fail(f"The current tab has {count} panes. Open a new tab, and run --apply there.")
    run.apply_template(name, target, session=False)
    run.guard_names(session=False)
