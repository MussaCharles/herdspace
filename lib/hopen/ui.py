"""The look of the menus, like a Herdr popup, and the questions: a choice, a
text, a yes or no, and a pick of folders.

A menu uses fzf if it is installed and the terminal can draw it. Else it shows
a numbered menu. The items come on stdin, so each answer comes from the
terminal, /dev/tty.
"""
import os
import re
import shutil
import subprocess
import sys

# The colors of the Herdr theme of the setup: Dracula, with the herdspace
# colors of [theme.custom] in config/herdr/config.toml. ui.sh has the same
# values while the move to Python goes on.
UI_BG = "#282a36"
UI_ROW = "#45475a"
UI_FG = "#f8f8f2"
UI_DIM = "#6272a4"
UI_ACCENT = "#bd93f9"
UI_MATCH = "#ff79c6"
UI_MARK = "#50fa7b"

GROUP_COLORS = {
    "Projects": "#50fa7b",
    "Workspace and tabs": "#8be9fd",
    "Layout": "#f1fa8c",
    "Agents": "#ff79c6",
    "Files": "#ffb86c",
    "Git": "#ff5555",
    "Sessions": "#bd93f9",
    "Herdr": "#4e82ef",
    "herdspace": "#a78bfa",
    "Network": "#a4ffff",
}
RESET = "\033[0m"


def ui_color():
    """True when the menus can use color: not with NO_COLOR."""
    return not os.environ.get("NO_COLOR")


def sgr(color):
    """The terminal code for the text color COLOR, for example #ff79c6."""
    h = color.lstrip("#")
    return "\033[38;2;%d;%d;%dm" % (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def group_color(group):
    """The color of a group of the palette, so that each group is easy to find."""
    return GROUP_COLORS.get(group, UI_FG)


def has_fzf():
    """fzf draws nothing with no TERM, or with TERM=dumb."""
    term = os.environ.get("TERM", "")
    return bool(shutil.which("fzf")) and term not in ("", "dumb")


def fzf_command(label, *args):
    """The fzf command of a menu like a Herdr popup: the colors of the theme,
    and a rounded frame with LABEL at the top. With NO_COLOR, no color."""
    if ui_color():
        colors = ",".join([
            f"bg:{UI_BG}", f"bg+:{UI_ROW}", f"fg:{UI_FG}", f"fg+:{UI_FG}", f"hl:{UI_MATCH}",
            f"hl+:{UI_MATCH}", f"prompt:{UI_ACCENT}", f"pointer:{UI_MATCH}", f"marker:{UI_MARK}",
            f"header:{UI_DIM}", f"info:{UI_DIM}", f"border:{UI_DIM}", f"label:{UI_ACCENT}",
            f"spinner:{UI_ACCENT}", f"gutter:{UI_BG}", f"preview-bg:{UI_BG}", f"preview-border:{UI_DIM}",
        ])
        return ["fzf", "--border", "rounded", "--border-label", f" {label} ", "--padding", "0,1",
                "--color", colors, *args]
    return ["fzf", "--no-color", "--border", "rounded", "--border-label", f" {label} ", "--padding", "0,1", *args]


def run_fzf(label, items, *args):
    """Run fzf on the text ITEMS, and return what it prints. Esc returns ""."""
    result = subprocess.run(fzf_command(label, *args), input=items + "\n", stdout=subprocess.PIPE, text=True)
    return result.stdout


def dim_folders(lines):
    """Show the folder of each path dim and the file name bright, as VS Code
    does. With NO_COLOR, change nothing."""
    if not ui_color():
        return list(lines)
    return [re.sub(r"^(.*/)([^/]*)$", lambda m: sgr(UI_DIM) + m.group(1) + RESET + m.group(2), line) for line in lines]


def _tty_line():
    # The items came on stdin, so the answer comes from the terminal.
    try:
        with open("/dev/tty", encoding="utf-8", errors="replace") as tty:
            return tty.readline().rstrip("\n")
    except OSError:
        return ""


class NoItem(Exception):
    """An answer that names no item. The message says which. PICKED holds the
    items before the bad word, which bash printed before its error."""

    def __init__(self, text, picked=()):
        super().__init__(text)
        self.picked = list(picked)


def choose(prompt, items, read=_tty_line):
    """Show a menu of ITEMS, the text of "key<TAB>text" lines, and return the
    chosen key, or "" if the person cancels. An unknown answer raises NoItem."""
    if has_fzf():
        out = run_fzf(prompt, items, "--delimiter", "\t", "--with-nth", "2..", "--prompt", f"{prompt} > ",
                      "--header", "Esc cancels.", "--height", "40%", "--reverse", "--no-multi")
        return "\n".join(line.split("\t")[0] for line in out.split("\n") if line)
    lines = items.split("\n")
    for number, line in enumerate(lines, 1):
        text = line.split("\t", 1)[1].strip("\t") if "\t" in line else ""
        print("  %2d) %s" % (number, text), file=sys.stderr)
    print(f"  {prompt}? Type a number or a name: ", end="", file=sys.stderr, flush=True)
    answer = read()
    if answer == "":
        return ""
    keys = [line.split("\t")[0] for line in lines]
    if answer.isdigit():
        name = keys[int(answer) - 1] if 0 < int(answer) <= len(keys) else ""
    else:
        name = answer if answer in keys else ""
    if not name:
        raise NoItem(f"No item {answer}.")
    return name


def ask_text(prompt, read=_tty_line):
    """Read one line from the terminal."""
    print(f"  {prompt}: ", end="", file=sys.stderr, flush=True)
    return read()


def pick_folders(items, read=_tty_line):
    """Let the person mark one or more folders of ITEMS, one on each line, and
    return them. With no fzf, ask for the numbers of the folders. A number
    that is not a number raises NoItem."""
    if has_fzf():
        out = run_fzf("Folders with the ignored files", items, "--multi", "--prompt", "Folders > ", "--header",
                      "Tab marks a folder. Enter searches the marked folders, with the ignored files. Esc cancels.",
                      "--height", "60%", "--reverse")
        return [line for line in out.split("\n") if line]
    lines = items.split("\n")
    for number, line in enumerate(lines, 1):
        print("  %2d) %s" % (number, line), file=sys.stderr)
    print("  Folders? Type the numbers, with a space between them: ", end="", file=sys.stderr, flush=True)
    picked = []
    for word in read().split():
        if not word.isdigit():
            raise NoItem(f"No folder {word}.", picked)
        if 0 < int(word) <= len(lines):
            picked.append(lines[int(word) - 1])
    return picked


def confirm(text, read=_tty_line):
    """Ask a yes or no question. The default is no."""
    print(f"  {text} [y/N] ", end="", file=sys.stderr, flush=True)
    return read() in ("y", "Y", "yes")
