"""Find and search the files of a project, also with the files that .gitignore names.

SEARCH_IN, the folders of --with-ignored, comes as arguments. When it has
folders, the file list and the search read only them, with the files that
.gitignore names, but not the folders of SKIP_DIRS. Python builds the command
and runs it in its own place with exec, so a long list does not pass through
Python.
"""
import os
import shutil
import subprocess
import sys

from . import core

# Folders of dependencies and caches. The search with the ignored files never reads them.
SKIP_DIRS = [".git", "node_modules", ".venv", "venv", "__pycache__", ".mypy_cache", ".pytest_cache",
             ".ruff_cache", ".tox", ".next", ".gradle", "Pods", "DerivedData", "target"]


def search_dir(folder):
    """A folder of --with-ignored. A name that starts with "-" gets "./" in
    front, so that fd, find, and rg never read it as an option."""
    folder = folder[:-1] if folder.endswith("/") else folder
    return "./" + folder if folder.startswith("-") else folder


def fd_command():
    """fd, or fdfind on Debian, or None."""
    for name in ("fd", "fdfind"):
        if shutil.which(name):
            return name
    return None


def skip_args():
    return [arg for folder in SKIP_DIRS for arg in ("--exclude", folder)]


def files_command(search_in):
    """The command that prints the files of the current folder, or of SEARCH_IN."""
    fd = fd_command()
    if search_in:
        if fd is None:
            return ["find", *search_in, "-type", "f", "!", "-path", "*/.git/*"]
        return [fd, "--type", "f", "--hidden", "--no-ignore-vcs", *skip_args(), ".", *search_in]
    if fd:
        return [fd, "--type", "f", "--hidden", "--exclude", ".git"]
    return ["find", ".", "-type", "f", "!", "-path", "*/.git/*"]


def list_folders():
    """The folders of the current folder, with the folders that .gitignore
    names, but not the folders of SKIP_DIRS."""
    fd = fd_command()
    if fd:
        out = core.run([fd, "--type", "d", "--hidden", "--no-ignore-vcs", *skip_args()],
                             stdout=subprocess.PIPE, text=True, errors="surrogateescape").stdout
        return [line[:-1] if line.endswith("/") else line for line in out.split("\n") if line]
    out = core.run(["find", ".", "-mindepth", "1", "-type", "d", "!", "-path", "*/.git*"],
                         stdout=subprocess.PIPE, text=True, errors="surrogateescape").stdout
    return [line[2:] if line.startswith("./") else line for line in out.split("\n") if line]


def text_command(text, search_in):
    """The rg command that prints the lines that hold TEXT, as "file:line:text"."""
    base = ["rg", "--line-number", "--no-heading", "--color=always", "--smart-case", "--fixed-strings"]
    if search_in:
        globs = [arg for folder in SKIP_DIRS for arg in ("--glob", f"!{folder}/")]
        return [*base, "--hidden", "--no-ignore-vcs", *globs, "--", text, *search_in]
    return [*base, "--", text]


def exec_command(command):
    """Run COMMAND in the place of this process, as bash ran it."""
    sys.stdout.flush()
    try:
        core.exec_program(command)
    except OSError as error:
        print(f"hopen: {command[0]}: {error.strerror}", file=sys.stderr)
        return 127
