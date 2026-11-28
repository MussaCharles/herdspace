"""The prefix key of Herdr, as the palette and the help show it.

The prefix is in the [keys] table of ~/.config/herdr/config.toml, or in the
file of HERDR_CONFIG_PATH. "herdspace prefix" changes it. With no prefix line,
Herdr uses ctrl+b. lib/herdspace/prefix.sh reads the file the same way.
"""
import os
import re

HERDR_DEFAULT = "ctrl+b"


def config_path(home):
    return os.environ.get("HERDR_CONFIG_PATH") or os.path.join(home, ".config", "herdr", "config.toml")


def current(home):
    """The prefix of the Herdr configuration, as Herdr writes it: ctrl+space."""
    try:
        with open(config_path(home), encoding="utf-8", errors="replace") as handle:
            lines = handle.read().split("\n")
    except OSError:
        return HERDR_DEFAULT
    keys = False
    for line in lines:
        if line.startswith("["):
            keys = line.strip() == "[keys]"
            continue
        match = keys and re.match(r'^prefix\s*=\s*"([^"]*)"', line)
        if match:
            return match.group(1)
    return HERDR_DEFAULT


def label(key):
    """KEY as the docs write it: ctrl+space is Ctrl+Space, cmd+k is Cmd+K."""
    parts = []
    for part in key.split("+"):
        if part in ("cmd", "super"):
            part = "Cmd"
        elif len(part) == 1:
            part = part.upper()
        else:
            part = part[:1].upper() + part[1:]
        parts.append(part)
    return "+".join(parts)


def now(home):
    """The label of the current prefix."""
    return label(current(home))
