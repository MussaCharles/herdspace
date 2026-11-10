---
name: bootstrap-herdr-client
description: Set up Ghostty, the shell, and Herdr keys on the macOS or Linux computer that a person uses for SSH, with the herdr-bootstrap scripts. Use when a person asks to set up the client side of this Herdr environment.
---

# Bootstrap a Herdr client

Run this skill on the computer that the person uses for SSH, from the root folder of the herdr-bootstrap repository.

## Steps

1. Use `./bootstrap.sh client`. It finds macOS, Linux, or WSL by itself. On Windows, work inside WSL, and follow `docs/windows-wsl.md` for the Windows Terminal steps.
2. Ask the person for the SSH name of each server, if you do not have them. For each server, run `ssh -o BatchMode=yes <name> true`. If a server fails, tell the person and leave it out.
3. Run the script with `--check` and show the output. It changes nothing. Tell the person what a run changes: Ghostty and shell tools, `~/.zshrc` and `~/.config/ghostty/config.ghostty` (with backups). On macOS, the script also changes four Mission Control shortcuts. Ask if they want to keep those shortcuts. If they do, add `--skip-mission-control`. Wait for the person to agree.
4. Tell the person about this effect: the keys that Herdr uses do nothing in a Ghostty window that has no Herdr.
5. Run the script, with one `--server <name>` for each server. If the person wants the repository version of every file, add `--replace-all`. Otherwise add `--keep-existing`. Homebrew or `sudo` can ask for a password. If it asks, stop and ask the person to run the command in their own terminal.
6. For each server, run `ssh <name> -- infocmp -x xterm-ghostty >/dev/null && echo ok`.
7. Tell the person to open a new Ghostty window, connect with SSH, run `herdr`, and press `Cmd+T` on a Mac or `Ctrl+Shift+T` on Linux. You cannot press these keys, so ask the person for the result.

## Rules

- Do not change system settings beyond the steps in the script.
- Do not print the contents of a secret file or of `~/.ssh`.
