"""hopen --ports, like the Ports view of VS Code."""
import os
import subprocess
import sys

from . import lists


def project_folders(home):
    """One (folder, "session" or "session/label") pair for each project of each list."""
    found, _ = lists.find_lists(home)
    folders = []
    for session, path in found:
        try:
            lines = lists.read_list(path, "items")
        except Exception:
            continue
        for line in lines:
            fields = line.split("\x1e")
            if fields[0] == "R" and len(fields) > 2:
                folders.append((fields[2], session))
            elif fields[0] == "P" and len(fields) > 2:
                folders.append((fields[2], f"{session}/{fields[1]}"))
    return folders


def show_ports(folders):
    """The table of each TCP port that a program of this user listens on, with
    the program, its process ID, and the project that holds its folder."""
    home = os.path.expanduser("~")
    # The real paths, because a folder can have two names, for example /var and
    # /private/var on macOS.
    projects = [(os.path.realpath(path), label) for path, label in folders]

    def run(*args):
        try:
            return subprocess.run(args, capture_output=True, text=True, timeout=10).stdout
        except (OSError, subprocess.SubprocessError):
            return ""

    def project_of(folder):
        folder = os.path.realpath(folder) if folder else folder
        best = ("", "-")
        for path, label in projects:
            if (folder == path or folder.startswith(path + "/")) and len(path) > len(best[0]):
                best = (path, label)
        return best[1]

    ports = {}
    if sys.platform == "darwin":
        pid = name = None
        for line in run("lsof", "-nP", "-a", "-u", str(os.getuid()), "-iTCP", "-sTCP:LISTEN", "-Fpcn").splitlines():
            if line[:1] == "p":
                pid = line[1:]
            elif line[:1] == "c":
                name = line[1:]
            elif line[:1] == "n" and pid:
                address, _, port = line[1:].rpartition(":")
                ports.setdefault((int(port), pid), (name, address))
        def cwd_of(pid):
            out = run("lsof", "-a", "-p", pid, "-d", "cwd", "-Fn")
            return next((line[1:] for line in out.splitlines() if line[:1] == "n"), "")
    else:
        # /proc has the listening sockets and the processes that hold them, so
        # this needs no ss command.
        def address_of(text):
            address, port = text.split(":")
            raw = bytes.fromhex(address)
            if len(raw) == 4:
                host = ".".join(str(b) for b in raw[::-1])
            else:
                words = [raw[i:i + 4][::-1] for i in range(0, 16, 4)]
                host = ":".join(b"".join(words)[i:i + 2].hex() for i in range(0, 16, 2))
                host = {"0000:0000:0000:0000:0000:0000:0000:0000": "::",
                        "0000:0000:0000:0000:0000:0000:0000:0001": "::1"}.get(host, host)
            return host, int(port, 16)
        listening = {}
        for table in ("/proc/net/tcp", "/proc/net/tcp6"):
            try:
                lines = open(table).read().splitlines()[1:]
            except OSError:
                continue
            for line in lines:
                fields = line.split()
                if len(fields) > 9 and fields[3] == "0A":
                    listening[fields[9]] = address_of(fields[1])
        for entry in os.listdir("/proc"):
            if not entry.isdigit():
                continue
            try:
                links = [os.readlink(f"/proc/{entry}/fd/{fd}") for fd in os.listdir(f"/proc/{entry}/fd")]
                name = open(f"/proc/{entry}/comm").read().strip()
            except OSError:
                continue
            for link in links:
                inode = link[8:-1] if link.startswith("socket:[") else None
                if inode in listening:
                    host, port = listening[inode]
                    ports.setdefault((port, entry), (name, host))
        def cwd_of(pid):
            try:
                return os.readlink(f"/proc/{pid}/cwd")
            except OSError:
                return ""

    if not ports:
        return ["No program of yours listens on a TCP port."]
    row = "{:<7} {:<16} {:<16} {:<8} {:<22} {}"
    out = [row.format("PORT", "ADDRESS", "PROGRAM", "PID", "PROJECT", "FOLDER")]
    for (port, pid), (name, address) in sorted(ports.items()):
        folder = cwd_of(pid)
        shown = "~" + folder[len(home):] if folder == home or folder.startswith(home + "/") else folder
        out.append(row.format(port, address.strip("[]"), (name or "-")[:16], pid, project_of(folder), shown or "-"))
    return out
