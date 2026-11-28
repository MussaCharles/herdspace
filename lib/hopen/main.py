"""The command line of hopen: the options, and the main steps.

hopen opens all the projects of a list in one named Herdr session, with one
Herdr workspace for each folder, and then attaches to it. A list is a VS Code
workspace file or a herdspace.toml file. docs/hopen.md explains both.
bin/hopen starts this module with the release tag, its own path, and the
arguments of the person.
"""
import glob
import os
import re
import sys

from . import completion, convert, core, lists, palette, ports, prefix, quickopen, search, sessions, tasks, templates, ui

USAGE = """Usage: hopen <session> [--template NAME] [--file PATH] [--no-attach] [--trust]
       hopen            (in a terminal: choose a list from a menu)
       hopen <folder>   (for example: hopen .)
       hopen --all [session] [--template NAME]
       hopen --list
       hopen --templates
       hopen --apply NAME
       hopen --convert NAME
       hopen --completion zsh|bash
       hopen --task [NAME]
       hopen --find
       hopen --quick-open
       hopen --grep TEXT
       hopen --find | --quick-open | --grep TEXT --with-ignored FOLDER...
       hopen --ports
       hopen --palette
       hopen --version"""

def in_herdr(home):
    return f"You are in a Herdr pane. Press {prefix.now(home)}, then Q, and run this command again."


BAD_NAME = "A session name can use only letters, numbers, dots, dashes, and underscores."


class Options:
    def __init__(self):
        self.session = self.list_file = self.template = self.apply = self.shell = self.complete = ""
        self.action, self.attach, self.trust, self.print_only = "one", True, False, False
        self.task = self.grep = ""
        self.search_in = []


def usage_error():
    print(USAGE, file=sys.stderr)
    raise SystemExit(2)


def parse(argv, version):
    o = Options()
    args = list(argv)
    while args:
        arg = args.pop(0)
        if arg in ("--file", "--template", "--apply", "--convert", "--completion", "--complete"):
            if not args:
                usage_error()
            value = args.pop(0)
            if arg == "--file":
                o.list_file = value
            elif arg == "--template":
                o.template = value
            elif arg == "--apply":
                o.action, o.apply = "apply", value
            elif arg == "--convert":
                o.action, o.session = "convert", value
            elif arg == "--completion":
                o.action, o.shell = "completion", value
            else:
                o.action, o.complete = "complete", value
        elif arg == "--task":
            o.action = "task"
            if args and not args[0].startswith("-"):
                o.task = args.pop(0)
        elif arg in ("--find", "--ports", "--palette", "--all", "--list", "--templates"):
            o.action = arg[2:]
        elif arg == "--quick-open":
            o.action = "quick"
        elif arg == "--print":
            o.print_only = True
        elif arg == "--grep":
            if not args:
                usage_error()
            o.action, o.grep = "grep", args.pop(0)
        elif arg == "--with-ignored":
            if not args:
                usage_error()
            o.search_in.append(search.search_dir(args.pop(0)))
        elif arg == "--no-attach":
            o.attach = False
        elif arg == "--trust":
            o.trust = True
        elif arg == "--version":
            print(f"hopen {version}")
            raise SystemExit(0)
        elif arg in ("-h", "--help"):
            print(USAGE)
            raise SystemExit(0)
        elif arg.startswith("-"):
            usage_error()
        else:
            if o.session:
                usage_error()
            o.session = arg
    return o


def pick_list(home):
    """Let the person choose a list when hopen gets no name in a terminal."""
    found = sessions.found_lists(home)
    if not found:
        raise core.Fail("No project lists. Create ~/my-projects/herdspace.toml, or run hopen . in a folder.")
    menu = "\n".join("%s\t%-22s %s" % (name, name, core.short_path(path, home)) for name, path in found)
    try:
        name = ui.choose("Open which list", menu)
    except ui.NoItem as error:
        print(f"  [err]  {error}", file=sys.stderr)
        raise SystemExit(1)
    if not name:
        raise SystemExit(0)
    return name


def use_list_file(run, path):
    """Open the list in PATH. A list outside the usual places cannot take the
    session of another list. Its commands and values still need approval."""
    run.list_file = path
    try:
        # Every line, as bash read it, so that a warning before the name makes it invalid.
        run.session = "\n".join(lists.read_list(path, "session"))
    except lists.ListError as error:
        print(error, file=sys.stderr)
        raise core.Fail(f"Could not read {path}.")
    found, _ = lists.find_lists(run.home)
    owner = next((p for name, p in found if name == run.session), "")
    if owner and owner != path:
        raise core.Fail(f"{core.short_path(path, run.home)} uses the session {run.session}, which "
                        f"{core.short_path(owner, run.home)} has. Give the list another session name.")


def open_folder(run):
    """"hopen <folder>": use the list in the folder, if the folder has one:
    herdspace.toml, <folder>.code-workspace, or the only .code-workspace file.
    Else the session and its one workspace get the folder name."""
    if not os.path.isdir(run.session):
        raise core.Fail(f"No folder {run.session}.")
    path = os.path.realpath(run.session)
    if re.search(r"[\x00-\x1f\x7f]", path):
        raise core.Fail("The folder name has a control character.")
    name = os.path.basename(path)
    for candidate in (os.path.join(path, "herdspace.toml"), os.path.join(path, f"{name}.code-workspace")):
        if os.path.isfile(candidate):
            use_list_file(run, candidate)
            return
    others = [p for p in sorted(glob.glob(os.path.join(glob.escape(path), "*.code-workspace")), key=core.collate)
              if os.path.isfile(p)]
    if len(others) == 1:
        use_list_file(run, others[0])
        return
    if len(others) > 1:
        raise core.Fail("The folder has more than one VS Code workspace file. Open one of them, for example: "
                        f"hopen {os.path.basename(others[0])}")
    run.folder = path
    # A session name uses letters, numbers, dots, dashes, and underscores only.
    run.session = re.sub(r"[^A-Za-z0-9._-]", "-", name)
    if run.session in (".", ".."):
        run.session = "-"
    found, _ = lists.find_lists(run.home)
    owner = next((p for n, p in found if n == run.session), "")
    if owner:
        core.warn(f"The list {core.short_path(owner, run.home)} uses the session {run.session}. "
                  "hopen adds the folder to that session.")


def complete(o, home):
    """The completion scripts call this. It prints one name on each line."""
    if o.complete == "lists":
        found, _ = lists.find_lists(home)
        for name, _ in found:
            print(name)
    elif o.complete == "templates":
        run = sessions.Run(home)
        for line in templates.show_templates(run.template_dir)[1:]:
            print(line.split(" ")[0])
    elif o.complete == "tasks":
        match = tasks.project_for_dir(home, os.environ.get("PWD") or os.getcwd())
        if match:
            try:
                for line in lists.read_list(match[0], "items"):
                    fields = line.split("\x1e") + ["", ""]
                    if fields[0] == "K" and fields[1] == match[1]:
                        print(fields[2])
            except Exception:
                pass
    return 0


def here():
    return os.environ.get("HERDR_ACTIVE_PANE_CWD") or os.environ.get("PWD") or os.getcwd()


def main(version, self_path, argv):
    home = os.environ.get("HOME", "")
    o = parse(argv, version)
    run = sessions.Run(home, o.session, o.list_file, "", o.template, o.trust)
    action = o.action
    if action == "completion":
        sys.stdout.write(completion.completion_script(o.shell))
        return 0
    if action == "task":
        return tasks.run_task(o.task, home, run.state_dir, o.trust)
    if action == "ports":
        for line in ports.show_ports(ports.project_folders(home)):
            print(line)
        return 0
    if action == "palette":
        return palette.palette(self_path, home, o.print_only)
    if action == "find":
        return quickopen.find_file(here(), o.search_in) or 0
    if action == "quick":
        return quickopen.quick_open(here(), o.search_in, home)
    if action == "grep":
        return quickopen.grep_files(here(), o.grep, o.search_in, home)
    if action == "complete":
        return complete(o, home)
    if action == "list":
        sessions.show_lists(run)
        return 0
    if action == "convert":
        target, source = convert.convert_list(o.session, home, o.template)
        print(f"  [info] Wrote {core.short_path(target, home)}. hopen now uses it in place of {core.short_path(source, home)}.")
        return 0
    if action == "templates":
        for line in templates.show_templates(run.template_dir):
            print(line)
        return 0
    if action == "apply":
        sessions.apply_here(run, o.apply)
        return 0
    if o.template and not run.template_exists(o.template):
        raise core.Fail(f"No template named {o.template}. Run hopen --templates.")
    if action == "all":
        if run.session and not core.valid_name(run.session):
            raise core.Fail(BAD_NAME)
        sessions.open_all(run)
        return 0
    if not run.session and sys.stdin.isatty() and sys.stdout.isatty():
        if os.environ.get("HERDR_ENV") == "1" and o.attach:
            raise core.Fail(in_herdr(home))
        run.session = pick_list(home)
    if not run.session:
        usage_error()
    # "hopen <file>" opens a list file by its path, for example a VS Code
    # workspace file whose name is not the name of its folder.
    if os.path.isfile(run.session) and (run.session.endswith(".code-workspace") or run.session.endswith("herdspace.toml")):
        if o.list_file:
            raise core.Fail("Give the list file once: as the argument or with --file.")
        if re.search(r"[\x00-\x1f\x7f]", run.session):
            raise core.Fail("The file name has a control character.")
        folder = os.path.realpath(os.path.dirname(run.session) or ".")
        use_list_file(run, os.path.join(folder, os.path.basename(run.session)))
    if run.session in (".", "..") or "/" in run.session:
        if o.list_file:
            raise core.Fail("Use --file with a session name, not with a folder.")
        open_folder(run)
    if not core.valid_name(run.session):
        raise core.Fail(BAD_NAME)
    if os.environ.get("HERDR_ENV") == "1" and o.attach:
        raise core.Fail(in_herdr(home))
    if not run.list_file and not run.folder:
        found, warnings = lists.find_lists(home)
        for line in warnings:
            print(line, file=sys.stderr)
        run.list_file = next((p for n, p in found if n == run.session), "")
    if not run.folder and (not run.list_file or not os.path.isfile(run.list_file)):
        found, _ = lists.find_lists(home)
        print(lists.no_list_message(run.session, [n for n, _ in found]), file=sys.stderr)
        raise SystemExit(1)
    run.prepare_session()
    if o.attach:
        run.attach()
    return 0
