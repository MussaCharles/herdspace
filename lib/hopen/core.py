"""The common helpers of hopen: messages, names, and paths."""
import os
import re
import sys

NAME = re.compile(r"[A-Za-z0-9._-]+")


def valid_name(name):
    """A session name uses letters, numbers, dots, dashes, and underscores."""
    return bool(NAME.fullmatch(name or ""))


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
