"""The commands of the hopen package.

"internal" commands serve the bash modules of hopen while the move to Python
goes on. Each one prints what the bash function that it replaces printed.
"""
import os
import sys

from . import completion, convert, core, editor, lists, panes, ports, quickopen, search, tasks, templates, trust, ui


def _read_list(args):
    path, what, forced = (args + ["", "", ""])[:3]
    try:
        lines = lists.read_list(path, what, forced)
    except lists.ListError as error:
        print(error, file=sys.stderr)
        return 1
    for line in lines:
        print(line)
    return 0


def _find_lists(args):
    found, warnings = lists.find_lists(os.environ.get("HOME", ""))
    for line in warnings:
        print(line, file=sys.stderr)
    for session, path in found:
        print(f"{session}\t{path}")
    return 0


def _no_list(args):
    found, _ = lists.find_lists(os.environ.get("HOME", ""))
    print(lists.no_list_message(args[0] if args else "", [s for s, _ in found]), file=sys.stderr)
    return 1


def _convert(args):
    session, forced = (args + ["", ""])[:2]
    home = os.environ.get("HOME", "")
    target, source = convert.convert_list(session, home, forced)
    print(f"  [info] Wrote {core.short_path(target, home)}. hopen now uses it in place of {core.short_path(source, home)}.")
    return 0


def _completion(args):
    sys.stdout.write(completion.completion_script(args[0] if args else ""))
    return 0


def _templates(args):
    for line in templates.show_templates(args[0] if args else ""):
        print(line)
    return 0


def _template_lines(args):
    folder, name = (args + ["", ""])[:2]
    try:
        lines = templates.template_lines(folder, name)
    except OSError as error:
        print(f"grep: {templates.template_file(folder, name)}: {error.strerror}", file=sys.stderr)
        return 2
    for line in lines:
        print(line)
    return 0


def _guard(args):
    templates.guard(sys.stdin.read(), args[0] if args else "30")
    return 0


def _ports(args):
    for line in ports.show_ports(ports.project_folders(os.environ.get("HOME", ""))):
        print(line)
    return 0


def _read_fd(fd):
    # A here-string of bash ends with one new line more.
    try:
        with open(fd, "rb", closefd=False) as handle:
            data = handle.read()
    except OSError:
        return b""
    return data[:-1] if data.endswith(b"\n") else data


def _list_actions(args):
    for line in trust.list_actions([line for line in sys.stdin.read().split("\n") if line]):
        print(line)
    return 0


def _trust(args):
    # The values of the env files come on fd 3, and the lines of the question
    # on fd 4, because another user can read the arguments of a process.
    path, trust_flag, state_dir = (args + ["", "0", ""])[:3]
    extra = _read_fd(3)
    actions = _read_fd(4).decode("utf-8", "surrogateescape")
    return 0 if trust.list_trusted(path, actions, extra, state_dir, trust_flag == "1") else 1


def _stdin_items():
    # $(cat) in bash drops the new lines at the end.
    return sys.stdin.read().rstrip("\n")


def _choose(args):
    try:
        key = ui.choose(args[0] if args else "", _stdin_items())
    except ui.NoItem as error:
        print(f"  [err]  {error}", file=sys.stderr)
        return 1
    if key:
        print(key)
    return 0


def _ask_text(args):
    print(ui.ask_text(args[0] if args else ""), end="")
    return 0


def _pick_folders(args):
    try:
        folders = ui.pick_folders(_stdin_items())
    except ui.NoItem as error:
        for folder in error.picked:
            print(folder, flush=True)
        print(f"  [err]  {error}", file=sys.stderr)
        return 1
    for folder in folders:
        print(folder)
    return 0


def _confirm(args):
    return 0 if ui.confirm(args[0] if args else "") else 1


def _project_for_dir(args):
    match = tasks.project_for_dir(os.environ.get("HOME", ""), args[0] if args else "")
    if match is None:
        return 1
    print(f"{match[0]}\t{match[1]}")
    return 0


def _task(args):
    name, trust_flag, state_dir = (args + ["", "0", ""])[:3]
    return tasks.run_task(name, os.environ.get("HOME", ""), state_dir, trust_flag == "1")


def _list_files(args):
    return search.exec_command(search.files_command(args))


def _list_folders(args):
    for folder in search.list_folders():
        print(folder)
    return 0


def _search_text(args):
    return search.exec_command(search.text_command(args[0] if args else "", args[1:]))


def _home():
    return os.environ.get("HOME", "")


def _quick(args):
    return quickopen.quick_open(args[0] if args else "", [search.search_dir(d) for d in args[1:]], _home())


def _find(args):
    return quickopen.find_file(args[0] if args else "", [search.search_dir(d) for d in args[1:]])


def _grep(args):
    folder, text = (args + ["", ""])[:2]
    return quickopen.grep_files(folder, text, [search.search_dir(d) for d in args[2:]], _home())


def _place(args):
    # The first four arguments of a pane command: PANE WORKSPACE TAB WHERE.
    return panes.Place(*(args + ["", "", "", ""])[:4]), args[4:]


def _run_at(args):
    place, rest = _place(args)
    default, label, folder, command = (rest + ["", "", "", ""])[:4]
    panes.run_at(place, default, label, folder, command)
    return 0


def _split_run(args):
    place, rest = _place(args)
    direction, folder, command = (rest + ["", "", ""])[:3]
    panes.split_run(place, direction, folder, command)
    return 0


def _new_tab_run(args):
    place, rest = _place(args)
    label, folder, command = (rest + ["", "", ""])[:3]
    panes.new_tab_run(place, label, folder, command)
    return 0


def _editor_command(args):
    print(editor.editor_command(_home()), end="")
    return 0


def _palette(args):
    from . import palette
    self_path, print_only = (args + ["", "0"])[:2]
    return palette.palette(self_path, _home(), print_only == "1")


def _palette_owner(args):
    from . import palette
    for action in args:
        print(action + "\t" + " ".join(palette.owner(action)))
    return 0


INTERNAL = {
    "palette": _palette,
    "palette-owner": _palette_owner,
    "quick": _quick,
    "find": _find,
    "grep": _grep,
    "run-at": _run_at,
    "split-run": _split_run,
    "new-tab-run": _new_tab_run,
    "editor-command": _editor_command,
    "list-files": _list_files,
    "list-folders": _list_folders,
    "search-text": _search_text,
    "project-for-dir": _project_for_dir,
    "task": _task,
    "choose": _choose,
    "ask-text": _ask_text,
    "pick-folders": _pick_folders,
    "confirm": _confirm,
    "list-actions": _list_actions,
    "trust": _trust,
    "ports": _ports,
    "templates": _templates,
    "template-lines": _template_lines,
    "guard": _guard,
    "completion": _completion,
    "convert": _convert,
    "no-list": _no_list,
    "read-list": _read_list,
    "find-lists": _find_lists,
}


def main(argv):
    # bin/hopen runs "hopen TAG PATH ARGS...": the release tag, its own path,
    # and the arguments of the person.
    if len(argv) >= 3 and argv[0] == "hopen":
        from . import main as hopen
        return hopen.main(argv[1], argv[2], argv[3:])
    if len(argv) >= 2 and argv[0] == "internal" and argv[1] in INTERNAL:
        return INTERNAL[argv[1]](argv[2:])
    print("Usage: python3 -I -B lib/hopen/__main__.py internal COMMAND ARGS", file=sys.stderr)
    return 2
