---
name: herdspace-bootstrap
description: Change the herdspace setup scripts, add a tool or a configuration file to the setup, or update a pinned version. Use when you change bootstrap.sh, bootstrap/lib/, bootstrap/platforms/, bootstrap/service/, config/, or tools/versions.env.
---

# Change the setup

`bootstrap.sh` sets up a server machine, a client machine, or both on one machine. The [setup guide](../../../docs/setup.md) is the user view. This skill is the code view.

## How it works

1. `bootstrap.sh` reads the role (`server`, `client`, or `both`) and the system (`macos`, `linux`, or `wsl`).
2. From `curl`, it downloads the release archive, compares its checksum with `SHA256SUMS`, unpacks it to `~/.local/share/herdspace/<tag>`, and runs the copy there.
3. It runs one script in `bootstrap/platforms/`. For `both`, it runs the server script and then the client script, and it gives each script only its own options.
4. A platform script calls the shared steps in `bootstrap/lib/`.

## The building blocks

| Function | File | Use |
|----------|------|-----|
| `run_part LABEL READY_FN APPLY_FN` | `common.sh` | One step. If `READY_FN` exits 0, the step is done, and the script skips it. |
| `install_file SRC DEST` | `common.sh` | Make a file match the repository version. It updates a file that the script wrote. It asks before it replaces a file that a person changed. |
| `ensure_block FILE NAME TEXT` | `common.sh` | Keep a marked block of lines in a file that the person owns, for example `~/.zprofile`. |
| `git_pin URL DIR REF` | `common.sh` | Clone a repository at one pinned commit. |
| `setup_shell ROLE` | `shell.sh` | The shell files and the prompt color. |
| `finish_run NEXT_STEP` | `common.sh` | Print the result. With `--check`, exit 1 if a step is not done. |

The manifest at `~/.local/share/herdspace/manifest.tsv` keeps the checksum of each file that the script wrote. `install_file` uses it to know if a person changed a file.

## Modes

| Option | Effect |
|--------|--------|
| (none) | Do what is missing, and ask about each changed file. With no terminal, keep the file. |
| `--check` | Change nothing. Report each step as `[ok]`, `[todo]`, or `[diff]`. |
| `--keep-existing` | Do what is missing, and change no existing file. |
| `--replace-all` | Replace each changed file, with a backup. |

## Roles

The role goes to `~/.config/herdspace/env.zsh` and to the `~/.zprofile` block. For `both`, `bootstrap.sh` sets `HS_ROLE=both`, so that the server script and the client script write the same role. Do not run `server` and then `client` on one machine. Each one undoes a part of the other.

## Keys

`bootstrap/lib/client.sh` keeps the key choice: `herdspace` (the default) or `terminal`. `--keep-terminal-keys` and `--use-herdspace-keys` change it, and `load_keys` saves it in `~/.config/herdspace/keys`, so that a later run keeps it. With `terminal`, `install_ghostty_config` removes the lines between `# herdspace keys: start` and `# herdspace keys: end` from the Ghostty file, and the macOS client gives the `Ctrl` arrow keys back to Mission Control. If you add a key, put it between the marks, and add it to `docs/keyboard-shortcuts.md`.

## Add a tool or a file

1. Decide where it belongs: `bootstrap/lib/server.sh` for every server, one script in `bootstrap/platforms/` for one system, or `config/` for a configuration file.
2. Add the step with `run_part` and a ready function, so that a second run skips it.
3. Use `install_file` for a file that herdspace owns, and `ensure_block` for lines in a file that the person owns.
4. Pin each download. `tools/update-versions.sh` writes the release files and their checksums to `tools/versions.tsv`, and the Git commits to `tools/versions.env`. Review its output before you commit it. If the person did not agree, do not run `curl | sh` from a new source.
5. Add a check to `tests/verify-server.sh`, or to the test of the client.
6. Add the tool to "What the setup installs" in `docs/setup.md`, and to the credits in `README.md`.
7. Add a line to `CHANGELOG.md`.

## Rules

- A second run must change nothing. `tests/test-idempotent.sh` proves it.
- Replace a file that a person changed only after the person says yes, or with `--replace-all`.
- Do not change system settings beyond the steps of the script. Do not run `sudo` without a need.
- Read the source of a third-party plugin before you add it, and pin one commit.
- If the license of another project does not allow it, do not copy its configuration file.

## Test a change

```bash
tests/test-install.sh
```

```bash
tests/run-macos.sh
```

```bash
tests/run-linux.sh
```

The Linux tests reuse their apt downloads between runs. Add `NO_CACHE=1` to download every package again, for example after a change to a package list. For a login service change, also run `tests/run-systemd.sh`. For a client change, also run `tests/run-client-linux.sh`, which presses real keys in Ghostty. The macOS test uses a temporary home folder and stub commands, so it does not change the account of the person.
