#!/usr/bin/env bash
# update-versions.sh writes tools/versions.tsv and tools/versions.env with the
# latest releases and their checksums. Review the result, test it, and commit it.
# It takes a release or a commit only when it is at least PIN_MIN_AGE_DAYS days
# old (7 by default). Most bad upstream releases are found in the first days.
# For a git pin, the age is the date of the commit. It never moves a pin back
# to an older release or commit.
# Set GITHUB_TOKEN if GitHub limits the number of requests.
set -euo pipefail
cd "$(dirname "$0")"
python3 -I - <<'PY'
import datetime, json, os, re, urllib.error, urllib.request

MIN_AGE = datetime.timedelta(days=int(os.environ.get("PIN_MIN_AGE_DAYS", "7")))
CUTOFF = datetime.datetime.now(datetime.timezone.utc) - MIN_AGE

def api(path):
    request = urllib.request.Request("https://api.github.com/" + path)
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        request.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)

def when(text):
    return datetime.datetime.fromisoformat(text.replace("Z", "+00:00"))

def settled_release(repo):
    """The newest release that is at least MIN_AGE old, with no pre-release."""
    found = [r for r in api(f"repos/{repo}/releases?per_page=50")
             if not r["draft"] and not r["prerelease"] and r.get("published_at")
             and when(r["published_at"]) <= CUTOFF]
    if not found:
        raise SystemExit(f"No release of {repo} is old enough.")
    return max(found, key=lambda r: when(r["published_at"]))

def settled_commit(repo, branch):
    """The newest commit of the branch that is at least MIN_AGE old."""
    until = CUTOFF.strftime("%Y-%m-%dT%H:%M:%SZ")
    found = api(f"repos/{repo}/commits?sha={branch}&until={until}&per_page=1")
    if not found:
        raise SystemExit(f"No commit of {repo} {branch} is old enough.")
    return found[0]["sha"]

TOOLS = [
    ("herdr", "herdrdev/herdr", {"x86_64": r"^herdr-linux-x86_64$", "aarch64": r"^herdr-linux-aarch64$"}),
    ("neovim", "neovim/neovim", {"x86_64": r"^nvim-linux-x86_64\.tar\.gz$", "aarch64": r"^nvim-linux-arm64\.tar\.gz$"}),
    ("lazygit", "jesseduffield/lazygit", {"x86_64": r"_linux_x86_64\.tar\.gz$", "aarch64": r"_linux_arm64\.tar\.gz$"}),
    ("git-delta", "dandavison/delta", {"x86_64": r"x86_64-unknown-linux-gnu\.tar\.gz$", "aarch64": r"aarch64-unknown-linux-gnu\.tar\.gz$"}),
    ("eza", "eza-community/eza", {"x86_64": r"^eza_x86_64-unknown-linux-gnu\.tar\.gz$", "aarch64": r"^eza_aarch64-unknown-linux-gnu\.tar\.gz$"}),
    ("zoxide", "ajeetdsouza/zoxide", {"x86_64": r"x86_64-unknown-linux-musl\.tar\.gz$", "aarch64": r"aarch64-unknown-linux-musl\.tar\.gz$"}),
    ("fzf", "junegunn/fzf", {"x86_64": r"linux_amd64\.tar\.gz$", "aarch64": r"linux_arm64\.tar\.gz$"}),
    # Community packages of Ghostty, for Debian. Ubuntu 26.04 and later have their own.
    ("ghostty-trixie", "mkasberg/ghostty-ubuntu", {"x86_64": r"_amd64_trixie\.deb$", "aarch64": r"_arm64_trixie\.deb$"}),
    ("ghostty-forky", "mkasberg/ghostty-ubuntu", {"x86_64": r"_amd64_forky\.deb$", "aarch64": r"_arm64_forky\.deb$"}),
]

def current(path):
    try:
        return open(path, encoding="utf-8").read().splitlines()
    except FileNotFoundError:
        return []

pinned_lines = {}
for line in current("versions.tsv"):
    pinned_lines.setdefault(line.split("\t")[0], []).append(line)
pinned_refs = dict(l.split("=", 1) for l in current("versions.env") if "=" in l and not l.startswith("#"))

def release_date(repo, version):
    for tag in (version, "v" + version):
        try:
            return when(api(f"repos/{repo}/releases/tags/{tag}")["published_at"])
        except urllib.error.HTTPError:
            pass
    return None

lines = []
for name, repo, patterns in TOOLS:
    release = settled_release(repo)
    old = pinned_lines.get(name)
    if old:
        old_date = release_date(repo, old[0].split("\t")[1])
        if old_date and old_date > when(release["published_at"]):
            lines.extend(old)
            continue
    for arch, pattern in patterns.items():
        match = [a for a in release["assets"] if re.search(pattern, a["name"])]
        if len(match) != 1 or not (match[0].get("digest") or "").startswith("sha256:"):
            raise SystemExit(f"No single asset with a checksum: {name} {arch}")
        lines.append("\t".join([name, release["tag_name"].lstrip("v"), arch,
                                match[0]["browser_download_url"], match[0]["digest"][7:]]))

with open("versions.tsv", "w", encoding="utf-8") as handle:
    handle.write("\n".join(lines) + "\n")

GIT = [
    ("OHMYZSH_REF", "ohmyzsh/ohmyzsh", "master"),
    ("POWERLEVEL10K_REF", "romkatv/powerlevel10k", "master"),
    ("ZSH_AUTOSUGGESTIONS_REF", "zsh-users/zsh-autosuggestions", "master"),
    ("ZSH_SYNTAX_HIGHLIGHTING_REF", "zsh-users/zsh-syntax-highlighting", "master"),
    ("AUTO_TITLE_REF", "kryptamine/herdr-auto-title", "stable"),
]
with open("versions.env", "w", encoding="utf-8") as handle:
    handle.write("# Written by tools/update-versions.sh. Each value is one commit.\n")
    for key, repo, branch in GIT:
        sha = settled_commit(repo, branch)
        old = pinned_refs.get(key)
        # Keep a pinned commit that comes after the settled one.
        if old and old != sha and api(f"repos/{repo}/compare/{sha}...{old}")["status"] == "ahead":
            sha = old
        handle.write(f"{key}={sha}\n")
PY
