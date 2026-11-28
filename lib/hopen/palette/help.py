"""The Help group of the command palette."""
from . import then_wait

# The keys that a person uses most.
KEYS = r'''  Herdr (Mac / Linux)
    New tab, close tab           Cmd+T, Cmd+W      / Ctrl+Shift+T, Ctrl+Shift+W
    Go to anything               Cmd+K             / Ctrl+Shift+K
    Command palette              Cmd+Shift+P       / Ctrl+Shift+P
    lazygit over the pane        Cmd+Shift+G       / Ctrl+Shift+G
    Previous or next tab         Ctrl+Left, Ctrl+Right
    Previous or next workspace   Ctrl+Up, Ctrl+Down
    Next or previous pane        Alt+Up, Alt+Down
    Split right, split down      Ctrl+B V, Ctrl+B -
    Zoom the pane                Ctrl+B Z
    Leave, keep everything       Ctrl+B Q
  Shell
    Find a file, search text     ff, fif TEXT
    Jump to a folder             z NAME, zi
  Ghostty (outside Herdr)
    New tab, clear the screen    Cmd+Option+T, Cmd+Option+K / Ctrl+Alt+Shift+T'''

DOCS = ("  The cheat sheet:  https://github.com/MussaCharles/herdspace/blob/main/docs/cheat-sheet.md\n"
        "  The docs:         https://github.com/MussaCharles/herdspace/blob/main/docs/README.md")


def items(ctx):
    ctx.add("keys-help", "Help", "Show the keys")
    ctx.add("docs", "Help", "Show the links to the cheat sheet and the docs", "herdspace help")


ACTIONS = {
    "keys-help": lambda ctx, action: then_wait(lambda: print(KEYS)),
    "docs": lambda ctx, action: then_wait(lambda: print(DOCS)),
}
