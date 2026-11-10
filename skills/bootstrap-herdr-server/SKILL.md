---
name: bootstrap-herdr-server
description: Set up Herdr and its tools on a Debian, Ubuntu, or macOS server with the herdr-bootstrap scripts. Use when a person asks to set up, install, or repeat this Herdr environment on a server.
---

# Bootstrap a Herdr server

Run this skill on the server, from the root folder of the herdr-bootstrap repository.

## Steps

1. Use `./bootstrap.sh server`. It finds Linux, WSL, or macOS by itself. On Linux, make sure that `apt-get` exists. If it does not exist, stop and tell the person that only Debian and Ubuntu work.
2. Run `herdr status` if `herdr` exists. Tell the person if a server is running. The script keeps it running.
3. List the agent programs with `command -v claude codex pi opencode hermes`. Tell the person that the script adds an integration only for the programs that it finds.
4. Run the script with `--check` and show the output. It changes nothing. Tell the person what a run changes: missing parts, and on Linux the login shell. Ask what to do with each file that the output marks as different. Wait for the person to agree.
5. Run the script. If the person wants the repository version of every file, add `--replace-all`. Otherwise add `--keep-existing`. It can take more than ten minutes, so run it in the background with its output in a log file, and read the log.
6. If the script asks for a password, stop and ask the person to run it in their own terminal.
7. Run `tests/verify-server.sh linux` or `tests/verify-server.sh macos`. Report each line that starts with `FAIL`.
8. Report any `[warn]` lines from the script, and tell the person how to open a session: `herdr`.

## Rules

- Do not run `herdr server stop`. A stop closes every pane.
- Do not edit the configuration files on the computer. Change them in this repository and run the script again.
- Do not print the contents of a secret file.
- If an integration fails, ask the person to start that agent program one time. Then run the script again.
