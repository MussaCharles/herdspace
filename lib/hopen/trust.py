"""The trust of a list: hopen uses the commands and the environment values of
a list only after the person approves this version of the file.

trusted.tsv in the state folder holds one "file<TAB>checksum" line for each
approved list. A changed file has another checksum, so it needs a new
approval. With no terminal, only --trust approves a list.
"""
import hashlib
import os
import re
import sys

from . import core

HASH = re.compile(r"[0-9a-f]{64}")


def list_actions(items):
    """One line for each command and environment value of the lines ITEMS of
    read_list, as the approval question shows them."""
    out = []
    for line in items:
        fields = line.split("\x1e")
        kind = fields[0]
        get = lambda i: fields[i] if i < len(fields) else ""  # noqa: E731
        if kind in ("R", "P"):
            if get(4) != "-":
                out.append(f"    {get(1)}: run {get(4)}")
            if get(5) != "-":
                out.append(f"    {get(1)}: set " + get(5).replace("\x1f", ", "))
        elif kind == "T" and get(4) != "-":
            out.append(f"    {get(1)}, tab {get(2)}: run {get(4)}")
        elif kind == "F":
            out.append(f"    {get(1)}: load {get(2)} ({get(3)})")
        elif kind == "K":
            out.append(f"    {get(1)}, task {get(2)}: run {get(3)}")
    return out


def file_hash(path, extra=b""):
    """The checksum of PATH. EXTRA is the values that the list loads from env
    files, so that a change to them asks again."""
    with open(path, "rb") as handle:
        digest = hashlib.sha256(handle.read())
    if extra:
        digest.update(b"\0" + extra)
    return digest.hexdigest()


def trust_file(state_dir):
    return os.path.join(state_dir, "trusted.tsv")


def _rows(state_dir):
    try:
        with open(trust_file(state_dir), encoding="utf-8", errors="surrogateescape") as handle:
            text = handle.read()
    except OSError:
        return []
    rows = text.split("\n")
    if rows and rows[-1] == "":
        rows.pop()
    return rows


def is_trusted(state_dir, path, digest):
    return any(row.split("\t")[:2] == [path, digest] for row in _rows(state_dir))


def save_trust(state_dir, path, digest):
    os.makedirs(state_dir, exist_ok=True)
    keep = [row for row in _rows(state_dir) if row.split("\t")[0] != path]
    new = trust_file(state_dir) + ".new"
    with open(new, "w", encoding="utf-8", errors="surrogateescape") as handle:
        handle.write("".join(row + "\n" for row in keep) + f"{path}\t{digest}\n")
    os.replace(new, trust_file(state_dir))


def list_trusted(path, actions, extra, state_dir, trust_flag, ask=None):
    """True if hopen can use the commands and values of PATH: the person
    approved this version of the file before, approves it now, or gave
    --trust. ASK reads the answer. With no terminal, the answer is no."""
    try:
        digest = file_hash(path, extra)
    except OSError:
        return False
    if not HASH.fullmatch(digest):
        return False
    if is_trusted(state_dir, path, digest):
        return True
    if not trust_flag:
        if ask is None:
            if not sys.stdin.isatty():
                return False
            ask = sys.stdin.readline
        print(f"  [info] {core.short_path(path)} runs these commands and sets these values:\n{actions}")
        print("  Use them? Answer yes only for a list that you trust. [y/N] ", end="", flush=True)
        answer = ask().rstrip("\n")
        if answer not in ("y", "Y", "yes", "Yes"):
            return False
    save_trust(state_dir, path, digest)
    return True
