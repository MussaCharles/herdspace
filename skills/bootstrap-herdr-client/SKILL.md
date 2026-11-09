---
name: bootstrap-herdr-client
description: Set up Ghostty, the shell, and Herdr keys on the macOS or Linux computer that a person uses for SSH, with the herdr-bootstrap scripts. Use when a person asks to set up the client side of this Herdr environment.
---

# Bootstrap a Herdr client

Run this skill on the computer that the person uses for SSH, from the root folder of the herdr-bootstrap repository.

## Steps

1. Run `uname -s`. Use `bootstrap-client-macos.sh` for `Darwin` and `bootstrap-client-linux.sh` for `Linux`. On Windows, follow `docs/windows-wsl.md` instead.
2. Ask the person for the SSH name of each server, if you do not have them. For each server, run `ssh -o BatchMode=yes <name> true`. If a server fails, tell the person and leave it out.
3. Tell the person what the script changes: Ghostty and shell tools, `~/.zshrc` and `~/.config/ghostty/config.ghostty` (with backups). On macOS, the script also changes four Mission Control shortcuts. Ask if they want to keep those shortcuts. If they do, add `--skip-mission-control`. Wait for the person to agree.
4. Tell the person about this effect: the keys that Herdr uses do nothing in a Ghostty window that has no Herdr.
5. Run the script, with one `--server <name>` for each server. Homebrew or `sudo` can ask for a password. If it asks, stop and ask the person to run the command in their own terminal.
6. For each server, run `ssh <name> -- infocmp -x xterm-ghostty >/dev/null && echo ok`.
7. Tell the person to open a new Ghostty window, connect with SSH, run `herdr`, and press `Cmd+T` on a Mac or `Ctrl+Shift+T` on Linux. You cannot press these keys, so ask the person for the result.

## Rules

- Do not change system settings beyond the steps in the script.
- Do not print the contents of a secret file or of `~/.ssh`.
