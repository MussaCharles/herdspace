"""The common helpers of hopen: messages, names, and paths."""
import locale
import os
import re
import sys

NAME = re.compile(r"[A-Za-z0-9._-]+")


def valid_name(name):
    """A session name uses letters, numbers, dots, dashes, and underscores."""
    return bool(NAME.fullmatch(name or ""))


def collate(text):
    """The sort key of bash globs and sort: the collation of the locale."""
    try:
        locale.setlocale(locale.LC_COLLATE, "")
        return locale.strxfrm(text)
    except locale.Error:
        return text


def short_path(path, home=None):
    """Show a path in the home folder as ~/..."""
    home = home if home is not None else os.environ.get("HOME", "")
    if home and (path == home or path.startswith(home)):
        return "~" + path[len(home):]
    return path


def warn(text):
    print(f"  [warn] {text}", file=sys.stderr)


class Fail(SystemExit):
    """Stop hopen with a message and exit status 1, like die in bash."""

    def __init__(self, text):
        print(f"  [err]  {text}", file=sys.stderr)
        super().__init__(1)


def run(args, **options):
    """subprocess.run that treats a missing program as bash does: a failed
    command with exit status 127, and no exception."""
    import subprocess
    try:
        return subprocess.run(args, **options)
    except OSError:
        text = options.get("text") or options.get("universal_newlines") or "errors" in options or "encoding" in options
        empty = "" if text else b""
        captured = options.get("capture_output") or options.get("stdout") == subprocess.PIPE
        return subprocess.CompletedProcess(args, 127, empty if captured else None, empty if captured else None)


def popen(args, **options):
    """subprocess.Popen that returns None for a missing program."""
    import subprocess
    try:
        return subprocess.Popen(args, **options)
    except OSError:
        return None


def exec_program(args):
    """Run ARGS in the place of this process. A missing program stops hopen
    with exit status 127, as bash does."""
    sys.stdout.flush()
    try:
        os.execvp(args[0], list(args))
    except OSError as error:
        reason = "command not found" if isinstance(error, FileNotFoundError) else error.strerror
        print(f"hopen: {args[0]}: {reason}", file=sys.stderr)
        raise SystemExit(127 if isinstance(error, FileNotFoundError) else 126)
