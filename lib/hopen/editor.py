"""The editor: open a file in it, and the command that starts the herdspace Neovim."""
import os
import sys


def open_in_editor(path, line=""):
    """Open PATH in $VISUAL or $EDITOR, or else Neovim, in the place of this
    process. A name that starts with "-" gets "./" in front, so that the
    editor never reads it as an option."""
    editor = os.environ.get("VISUAL") or os.environ.get("EDITOR") or "nvim"
    if path.startswith("-"):
        path = "./" + path
    words = editor.split()
    if os.path.basename(words[0]) in ("code", "code-insiders", "cursor"):
        args = [*words, "--goto", f"{path}:{line}" if line else path]
    elif line:
        args = [*words, f"+{line}", path]
    else:
        args = [*words, path]
    sys.stdout.flush()
    os.execvp(args[0], args)


def editor_command(home):
    """The editor to start, with the herdspace Neovim when the person has no
    Neovim files of their own."""
    editor = os.environ.get("EDITOR", "")
    if editor and editor != "nvim":
        return editor
    if (not os.environ.get("NVIM_APPNAME") and not os.path.isdir(os.path.join(home, ".config", "nvim"))
            and os.path.isdir(os.path.join(home, ".config", "herdspace-nvim"))):
        return "NVIM_APPNAME=herdspace-nvim nvim"
    return "nvim"
