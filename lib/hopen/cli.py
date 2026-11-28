"""The commands of the hopen package.

"internal" commands serve the bash modules of hopen while the move to Python
goes on. Each one prints what the bash function that it replaces printed.
"""
import os
import sys

from . import completion, convert, core, lists, templates


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


INTERNAL = {
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
    if len(argv) >= 2 and argv[0] == "internal" and argv[1] in INTERNAL:
        return INTERNAL[argv[1]](argv[2:])
    print("Usage: python3 -I -B lib/hopen/__main__.py internal COMMAND ARGS", file=sys.stderr)
    return 2
