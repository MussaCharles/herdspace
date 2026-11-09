#!/usr/bin/env bash
# update-versions.sh writes tools/versions.tsv and tools/versions.env with the
# latest releases and their checksums. Review the result, test it, and commit it.
# Set GITHUB_TOKEN if GitHub limits the number of requests.
set -euo pipefail
cd "$(dirname "$0")"
python3 -I - <<'PY'
import json, os, re, urllib.request

def api(path):
    request = urllib.request.Request("https://api.github.com/" + path)
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        request.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)

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

lines = []
for name, repo, patterns in TOOLS:
    release = api(f"repos/{repo}/releases/latest")
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
        handle.write(f"{key}={api(f'repos/{repo}/commits/{branch}')['sha']}\n")
PY
