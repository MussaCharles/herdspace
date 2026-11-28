"""The Files group of the command palette."""
import os
import re
import shlex
import shutil
import subprocess
import sys

from .. import core, editor, panes, prefix, quickopen, search, ui
from . import then_wait


def items(ctx):
    # In Herdr, quick open replaces the find action.
    fzf = bool(shutil.which("fzf"))
    if not ctx.pane and fzf:
        ctx.add("find", "Files", "Find a file, and open it", "ff")
    if ctx.pane and fzf:
        ctx.add("quick", "Files", "Quick open: a file in the editor of this tab", f"Cmd+P, {prefix.now(ctx.home)} F")
    if shutil.which("rg"):
        ctx.add("grep", "Files", "Search in the files, and open a result", "fif TEXT")
        ctx.add("ignored", "Files", "Choose folders, and search them with the ignored files", "hopen --with-ignored")
    if shutil.which("nvim") or os.environ.get("EDITOR"):
        ctx.add("edit", "Files", "Open this folder in the editor", "nvim .")
        ctx.add("read-md", "Files", "Read a Markdown file, rendered", "nvim -R FILE.md")


def stop(status):
    raise SystemExit(status)


def find(ctx, action):
    panes.run_at(ctx.place, "here", "find", ctx.dir, f"{shlex.quote(ctx.self_path)} --find")


def quick(ctx, action):
    return quickopen.quick_open(ctx.dir, [], ctx.home)


def ignored(ctx, action):
    # Only the chosen folders are read, so the search stays fast.
    top = core.run(["git", "-C", ctx.dir, "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    folder = top.stdout.rstrip("\n") if top.returncode == 0 else ctx.dir
    old = os.getcwd()
    os.chdir(folder)
    try:
        names = sorted(search.list_folders(), key=core.collate)
    finally:
        os.chdir(old)
    if not names:
        then_wait(lambda: print(f"  No folder in {folder}."))
        stop(0)
    try:
        picked = ui.pick_folders("\n".join(names))
    except ui.NoItem as error:
        print(f"  [err]  {error}", file=sys.stderr)
        stop(1)
    if not picked:
        stop(0)
    search_in = [search.search_dir(name) for name in picked if name]
    try:
        choice = ui.choose("Search", "open\tOpen a file of these folders\ntext\tSearch the text in these folders")
    except ui.NoItem as error:
        print(f"  [err]  {error}", file=sys.stderr)
        stop(1)
    if choice == "open":
        return quickopen.quick_open(folder, search_in, ctx.home)
    if choice == "text":
        text = ui.ask_text("Search for")
        if not text:
            stop(0)
        return quickopen.grep_files(folder, text, search_in, ctx.home)
    return 0


def grep(ctx, action):
    text = ui.ask_text("Search for")
    if not text:
        stop(0)
    panes.run_at(ctx.place, "here", "search", ctx.dir, f"{shlex.quote(ctx.self_path)} --grep {shlex.quote(text)}")


def edit(ctx, action):
    panes.run_at(ctx.place, "tab", "edit", ctx.dir, f"{editor.editor_command(ctx.home)} .")


def read_md(ctx, action):
    out = core.run(search.files_command([]), cwd=ctx.dir, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                         text=True, errors="surrogateescape").stdout
    names = sorted((quickopen.file_line(line) for line in out.split("\n") if line), key=core.collate)
    names = [name for name in names if re.search(r"\.(md|markdown)$", name, re.I)]
    if not names:
        then_wait(lambda: print(f"  No Markdown file in {ctx.dir}."))
        stop(0)
    try:
        pick = ui.choose("Markdown file", "\n".join(f"{name}\t{name}" for name in names))
    except ui.NoItem as error:
        print(f"  [err]  {error}", file=sys.stderr)
        stop(1)
    if not pick:
        stop(0)
    panes.run_at(ctx.place, "tab", os.path.basename(pick), ctx.dir,
                 f"{editor.editor_command(ctx.home)} -R {shlex.quote(pick)}")


ACTIONS = {
    "find": find,
    "quick": quick,
    "ignored": ignored,
    "grep": grep,
    "edit": edit,
    "read-md": read_md,
}
