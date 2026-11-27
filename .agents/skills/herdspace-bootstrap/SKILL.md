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
| `install_file SRC DEST [MODE]` | `common.sh` | Make a file match the repository version. It updates a file that the script wrote. It asks before it replaces a file that a person changed. The mode is 644 by default. |
| `install_tree SRC_DIR DEST_DIR` | `common.sh` | `install_file` for each file of a folder, for example `config/nvim` and the templates. A file in `SEED_ONLY` goes through `seed_file`, which writes only a missing file. Neovim changes `lazy-lock.json` after the first start, so it is seeded. |
| `ensure_block FILE NAME TEXT` | `common.sh` | Keep a marked block of lines in a file that the person owns, for example `~/.zprofile`. |
| `git_pin URL DIR REF` | `common.sh` | Clone a repository at one pinned commit. |
| `setup_shell ROLE` | `shell.sh` | The shell files and the prompt color. |
| `finish_run NEXT_STEP` | `common.sh` | Print the result. With `--check`, exit 1 if a step is not done. |

The manifest at `~/.local/share/herdspace/manifest.tsv` keeps the checksum of each file that the script wrote. `install_file` uses it to know if a person changed a file. A file with no manifest entry is compared with `bootstrap/known-hashes.tsv`, the hashes of the older versions of each file from `config/` and `bin/`. If you change such a file, run `tools/known-hashes.sh` and commit the list. CI runs `tools/known-hashes.sh --check`.

## Output and questions

Each line of the setup goes through the functions of `bootstrap/lib/common.sh`: `info`, `ok`, `warn`, `die`, `note_todo`, `step`, `ui_item`, `ui_indent`, and `ui_wait`. Do not print a status line with `printf` or `echo` in a step.

- With no terminal, or with `NO_COLOR`, the output stays plain, with the words `[ok]`, `[todo]`, `[warn]`, and `[err]`. The tests, `install.md`, and coding agents read them. At a terminal, the same functions draw boxes, marks, and colors.
- `ui_count WORD N` writes `1 file` and `2 files`. Use it for each count.
- A step that runs a long program in the background shows its progress with `ui_wait PID LABEL TOTAL COUNT_FN`. With no terminal, it prints a line every 30 seconds.
- `brew_install` sets no question of its own: `HOMEBREW_NO_ASK=1` is set, because the person agreed to the setup.
- `finish_run ROLE` prints the summary, the kept files, the backups with the command that puts each file back, and the next steps of ROLE: `server`, `client`, `both`, or `none` for the server part of a run of `both`. The links use `HS_DOC_BASE`, the docs of the release, which `bootstrap.sh` sets.
- Name the default of each question, for example `[Y/n] (Enter = yes)`. The question about a changed file lists the changed files first, from a silent `--check` of the same script.
- `tests/test-ui.sh` tests the output, with `tests/pty_run.py` for the terminal.

## Prerequisites

Each platform script adds its prerequisites with `prereq_add LABEL KIND READY_FN APPLY_FN PASSWORD FIX`, and then calls `run_prereqs`. The functions are in `bootstrap/lib/prereqs.sh`. KIND is `necessary` or `optional`. APPLY_FN is `-` when the setup cannot install the item, and then FIX tells the person what to do. `--yes` installs with no question. With no terminal, the step installs only the items that need no password.

Never add a prerequisite that turns on remote access, installs an SSH server, or copies a key to a server. Remote access is a choice of the owner of the server.

`tests/run-prereqs.sh` tests the step on Linux. `HS_PREREQS_ONLY=1` stops a run after the step.

## Modes

| Option | Effect |
|--------|--------|
| (none) | Do what is missing, and ask about each changed file. With no terminal, keep the file. |
| `--check` | Change nothing. Report each step as `[ok]`, `[todo]`, or `[diff]`. |
| `--keep-existing` | Do what is missing, and change no existing file. |
| `--replace-all` | Replace each changed file, with a backup. |

## Roles

The role goes to `~/.config/herdspace/env.zsh` as `BOOTSTRAP_ROLE`. The `~/.zprofile` block does not keep the role. The block starts `herdr-update-check` only for a server role. For `both`, `bootstrap.sh` sets `HS_ROLE=both`, so that the server script and the client script write the same role. Do not run `server` and then `client` on one machine. Each one undoes a part of the other.

## Keys

`bootstrap/lib/client.sh` keeps two choices: the keys and the look, each `herdspace` (the default) or `terminal`. `--keep-terminal-keys`, `--use-herdspace-keys`, `--keep-terminal-look`, and `--use-herdspace-look` change them, and `load_keys` saves them in `~/.config/herdspace/keys` and `~/.config/herdspace/look`. With no saved key choice, `load_keys` asks at a terminal. `install_ghostty_config` never replaces the Ghostty file of the person: it copies the sections `# herdspace appearance` and `# herdspace keys` of `config/ghostty/*.ghostty` into marked blocks at the top of the file, and removes a block for the `terminal` choice. The macOS client also gives the `Ctrl` arrow keys back to Mission Control for `terminal`. If you add a key, put it in the keys section, give the Ghostty action a replacement key, and add both to `docs/keyboard-shortcuts.md`.

Before you add a Herdr key, compare it with the default keys of Herdr. For example, `prefix+shift+p` renames a pane, and `prefix+shift+t` renames a tab. `prefix+o` opens the target of a notification, and `prefix+shift+g` makes a new worktree. If Ghostty uses a key that Herdr must get, add `keybind = <key>=unbind` to both Ghostty files, between the marks. `tests/run-client-linux.sh` presses the real keys.

## Add a tool or a file

1. Read what Herdr and the installed tools already do. If one of them does the job, use it, and install nothing new.
2. Decide where it belongs: `bootstrap/lib/server.sh` for every server, one script in `bootstrap/platforms/` for one system, or `config/` for a configuration file.
3. Add the step with `run_part` and a ready function, so that a second run skips it.
4. Use `install_file` for a file that herdspace owns, and `ensure_block` for lines in a file that the person owns.
5. Pin each download. On macOS, Homebrew installs the tools, and their versions are not pinned. For an old pin, the weekly workflow "Pinned tools" opens an issue. `tools/check-pins.sh` shows the same report on your machine. If you add a tool to `tools/update-versions.sh`, the report covers it. `tools/update-versions.sh` writes the release files and their checksums to `tools/versions.tsv`, and the Git commits to `tools/versions.env`. It takes only a release or a commit that is at least 7 days old, and it never moves a pin back. Review its output before you commit it. If you add a Neovim plugin, add its repository to `tools/nvim-plugins.tsv`. If the person did not agree, do not run `curl | sh` from a new source.
6. Add a check to `tests/verify-server.sh`, or to the test of the client.
7. Add the tool to "What the setup installs" in `docs/setup.md`, and to `docs/credits.md`.
8. Add a line to `CHANGELOG.md`.

## Pitfalls

Each of these mistakes broke the setup one time:

- From `curl ... | bash`, stdin is the script, not the terminal. `bootstrap.sh` runs the downloaded copy with `</dev/tty`, so that the questions about changed files still get an answer. With no terminal, a question takes the safe answer.
- The last command of `~/.zshrc` sets the status of the first prompt. If the file is missing, `[[ -f FILE ]] && source FILE` ends with status 1. Use `if`. `tests/verify-server.sh` checks that a new shell starts with status 0.
- If another account can write to the Oh My Zsh folders, Oh My Zsh warns at each start. The setup runs `chmod -R go-w` on the folder.
- Neovim starts a language server only for a matching file. The setup installs the Mason packages by name, so that the first real start shows no install messages.
- `bootstrap.sh` saves `~/.local/share/herdspace/version` and `last-setup` after each setup that passes, for `bin/herdspace update`. If you add an option for one run only, leave it out in `save_setup`, as `--replace-all` is.
- `move_bash_exports` in `shell.sh` must never print a value of an export. `tests/test-bash-env.sh` fails if a value appears in the output.
- The herdspace Neovim runs with `NVIM_APPNAME=herdspace-nvim`: its files are in `~/.config/herdspace-nvim`, and its data in `~/.local/share/herdspace-nvim`. Start it with `hs_nvim` in `server.sh`. Never write in `~/.config/nvim`. `move_old_nvim` moves that folder to a backup with no question only if it holds only files of an older herdspace. For an own `~/.config/nvim`, `decide_own_nvim` decides: `--keep-existing` keeps it and `--replace-all` replaces it. Else a saved answer in `~/.local/share/herdspace/own-nvim`, or no terminal, keeps it. Else the setup asks: keep, replace (`backup_old_nvim` moves the folder to a backup), or show the difference. `tests/test-ui.sh` tests each answer.
- The setup installs the modules of `hopen` to `~/.local/lib/hopen` before `~/.local/bin/hopen`, so that a new `hopen` never runs with old modules. `.local/lib` is in `SHARED_DIRS` of `bin/herdspace`, so that the uninstall removes `~/.local/lib/hopen` but never `~/.local/lib`, which other programs share.
- After a failed plugin download, `nvim --headless "+Lazy! restore" +qa` can still exit 0. The plugin step looks for `~/.local/share/herdspace-nvim/lazy/LazyVim`, and tries again. With the folder still missing, it writes no done mark. Check the result of a step, not only the exit code of the tool. `tests/test-nvim-plugins.sh` tests it.
- A Linux client has no Cmd key. Each Herdr key that uses `cmd+` also needs a `ctrl+shift+` key in `config/herdr/config.toml`.
- On macOS, `brew install --cask` writes to `/Applications`, so it works only from an admin account. The prerequisites step prints the command for an admin account.
- `server` and then `client` on one machine write two different roles. Use `both`.
- An apt package can conflict with a tool from another source, for example `npm` with the `nodejs` of NodeSource. Then apt stops the whole step with "held broken packages". For each package that is not installed, `skip_other_sources` looks at its commands. If they already work, the package stays out of the list. If you add a package to a list, add its commands to `package_commands` in `linux-tools.sh`.
- `AGENTS` in `server.sh` lists the integrations of Herdr. `agent_commands` uses the command names of the Herdr registry (`src/integration/registry.rs`), for example `cursor-agent`, not `cursor`, the command of the Cursor editor. `agent_folder` uses the folders of the Herdr integration docs. When Herdr adds an integration, add all three, and a case to `tests/test-agents.sh`.
- zsh 5.8 (Ubuntu 22.04) refuses `unset "arr[key]"` for a key with `[` in it, and the error stops the rest of the file. In `config/shell/extras.zsh`, avoid such an unset, and run the extras tests in an `ubuntu:22.04` container.
- zsh reads a whole block before it runs it. So an alias such as the `ls` of Oh My Zsh changes a later `ls() {` definition in the same block. Use `function ls {`.
- `ls` and `ll` are functions that run eza only for flags that mean the same in eza. If you change them, run `tests/test-extras-ls.sh` and the real eza with each flag.
- LazyVim loads `lua/config/keymaps.lua` after startup. Put a Neovim key that must work at once, such as `Ctrl+Q`, in the `keys` of a plugin spec that loads at startup. `config/nvim/lua/plugins/close.lua` is an example.

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
