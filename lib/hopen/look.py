"""The theme and the accent color of Herdr, for the palette.

"herdspace theme" and "herdspace color" change them, and
lib/herdspace/theme.sh has the same lists. The palette shows a sample of each
theme and color, so that a person can choose by the look.
"""
from . import prefix, ui

# The built-in themes of Herdr 0.9.5, each with its background and its accent,
# from the public palette of the theme. The terminal theme uses the colors of
# the terminal, so it has no sample.
THEMES = [
    ("catppuccin", "#1e1e2e", "#cba6f7"),
    ("catppuccin-latte", "#eff1f5", "#8839ef"),
    ("terminal", "", ""),
    ("tokyo-night", "#1a1b26", "#7aa2f7"),
    ("tokyo-night-day", "#e1e2e7", "#2e7de9"),
    ("dracula", "#282a36", "#bd93f9"),
    ("nord", "#2e3440", "#88c0d0"),
    ("gruvbox", "#282828", "#fabd2f"),
    ("gruvbox-light", "#fbf1c7", "#b57614"),
    ("one-dark", "#282c34", "#61afef"),
    ("one-light", "#fafafa", "#4078f2"),
    ("solarized", "#002b36", "#268bd2"),
    ("solarized-light", "#fdf6e3", "#268bd2"),
    ("kanagawa", "#1f1f28", "#7e9cd8"),
    ("kanagawa-lotus", "#f2ecbc", "#4d699b"),
    ("rose-pine", "#191724", "#ebbcba"),
    ("rose-pine-dawn", "#faf4ed", "#d7827e"),
    ("vesper", "#101010", "#ffc799"),
]
THEME_DEFAULT = "dracula"
# Herdr uses catppuccin when the configuration names no theme.
HERDR_THEME = "catppuccin"

# The accent colors, as COLORS in lib/herdspace/theme.sh.
COLORS = [
    ("red", "#ef4444"),
    ("orange", "#f97316"),
    ("yellow", "#eab308"),
    ("green", "#22c55e"),
    ("teal", "#14b8a6"),
    ("cyan", "#06b6d4"),
    ("blue", "#3b82f6"),
    ("purple", "#a855f7"),
    ("pink", "#ec4899"),
]


def theme(home):
    return prefix.value(home, "theme", "name") or HERDR_THEME


def accent(home):
    """The accent color, as #rrggbb, or "" for the color of the theme."""
    return prefix.value(home, "theme.custom", "accent")


def color_name(value):
    """The name of a color of the list, or the value. "" is the theme color."""
    if not value:
        return "theme color"
    return next((name for name, hex_value in COLORS if hex_value == value.lower()), value)


def _bg(color):
    h = color.lstrip("#")
    return "\033[48;2;%d;%d;%dm" % (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def sample(background, color, colors):
    """A small sample: the background with the color on it. With no color in
    the menu, or with no value, two spaces."""
    if not colors or not color:
        return "    "
    return (_bg(background) if background else "") + ui.sgr(color) + " ██ " + ui.RESET


def theme_rows(now, colors):
    rows = [f"random\t{sample('', '', colors)} Random     a theme that is not the current one"]
    for name, background, color in THEMES:
        mark = "  (now)" if name == now else ""
        rows.append(f"{name}\t{sample(background, color, colors)} {name}{mark}")
    return "\n".join(rows)


def color_rows(now, colors):
    rows = [f"random\t{sample('', '', colors)} Random     a color that is not the current one",
            f"default\t{sample('', '', colors)} Default    the color of the theme" + ("  (now)" if not now else "")]
    for name, value in COLORS:
        mark = "  (now)" if value == now else ""
        rows.append(f"{name}\t{sample('', value, colors)} %-10s %s{mark}" % (name, value))
    return "\n".join(rows)


def menu_colors():
    """The samples need fzf with color. The numbered menu shows plain text."""
    return ui.has_fzf() and ui.ui_color()
