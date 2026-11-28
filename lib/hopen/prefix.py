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


def value(home, table, key):
    """The string value of KEY in TABLE of the Herdr configuration, or ""."""
    try:
        with open(config_path(home), encoding="utf-8", errors="replace") as handle:
            lines = handle.read().split("\n")
    except OSError:
        return ""
    inside = False
    for line in lines:
        if line.startswith("["):
            inside = line.strip() == f"[{table}]"
            continue
        match = inside and re.match(rf'^{re.escape(key)}\s*=\s*"([^"]*)"', line)
        if match:
            return match.group(1)
    return ""


def current(home):
    """The prefix of the Herdr configuration, as Herdr writes it: ctrl+space."""
    return value(home, "keys", "prefix") or HERDR_DEFAULT


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
