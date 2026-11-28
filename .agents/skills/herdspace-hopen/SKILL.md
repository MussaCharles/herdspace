---
name: herdspace-hopen
description: Change the hopen command or its pane templates in the herdspace repository. Use when you edit bin/hopen, a module in lib/hopen/, a file in config/templates/, the list file format, the state files, or the Auto Title guard.
---

# Change hopen

`bin/hopen` opens each project of a list as a Herdr workspace in one named Herdr session. A list is a `herdspace.toml` file, or a VS Code workspace file. The [hopen guide](../../../docs/hopen.md) is the user view. This skill is the code view.

## How it works

1. `find_lists` finds a list at `~/<name>.code-workspace`, `~/<name>/<name>.code-workspace`, or `~/<name>/herdspace.toml`. The session has the name of the file or the folder, unless the list sets `hopen.session` or `session`. If two lists name one session, `herdspace.toml` wins, with a warning.
2. `read_list FILE items` reads either format with `read_list` in `lib/hopen/lists.py`, through `hopen_py internal read-list`, and prints one line for each workspace and each extra tab: `R` (the parent workspace), `P` (a project), `T` (a tab), and `W` (a warning). The fields are separated by the byte `0x1e`, which is not white space, so that bash keeps each field in its place. An empty field is `-`, and an empty name is refused. `emit` writes every line and cleans every field, so no field holds a control character. Environment values are `KEY=VALUE` items, separated by the byte `0x1f`. VS Code accepts comments and trailing commas, so the reader removes them before it parses the JSON. `herdspace.toml` needs `tomllib`, so Python 3.11 or later.
3. If the Herdr session is stopped, `start_session` starts it.
4. For each folder with no workspace, `hopen` creates a workspace. The first workspace has the name of the session and opens the folder that holds the list file. A list with `parent_workspace = false` (or `hopen.parentWorkspace: false`) has no such workspace.
5. The `onOpen` command runs in the first pane. Then `apply_template` splits the new workspace into named panes, and it starts the program of each pane. Then each extra tab opens, with its own template and command. `ENV_ARGS` gives the `--env` values to each `workspace create`, `tab create`, and `pane split`.
6. `remember_template` writes one line for each workspace to `~/.local/state/hopen/<session>.tsv`: `label<TAB>template<TAB>id=name id=name`. An extra tab has the label `workspace/tab`.
7. After a stopped session starts again, `restart_programs` starts each template program again in a pane that shows only its shell. Herdr keeps the pane IDs after a restart, so `hopen` finds each pane by its ID. If the ID is gone, it uses the label.

`hopen <folder>` (an argument that is `.`, `..`, or has a `/`) goes through `open_folder`. If the folder has a list, `hopen` uses it. If that list names the session of another list, `hopen` stops with an error. Else `FOLDER` is set, and the session gets the name of the folder. Each character outside `A-Za-z0-9._-` becomes `-`. Then `prepare_session` makes one `R` line for the folder, with no commands or values.

An env file gives an `F` line just before its `R` or `P` line. An env file cannot set a name in `RISKY` (names that make a program run code). The approval question shows its values, but hides a value whose name matches `SECRET`. `file_hash` adds the values to the checksum, so a change to them asks again. A value in `env` wins over the same name in the file.

A task gives a `K` line after its `R` or `P` line. `hopen --task` finds the project with `project_for_dir` (the deepest project folder that holds the current folder), checks the approval of the list, and splits `HERDR_PANE_ID`, or `HERDR_ACTIVE_PANE_ID` in a popup. Outside Herdr, the task runs in the current terminal with `exec`. With no name and no terminal, `hopen --task` prints the tasks. `choose` is the menu for lists and tasks: fzf, or a numbered menu.

`hopen --palette` builds a menu of actions with `choose`, and runs the chosen one with `exec "$0" ...`. `lib/hopen/palette.sh` holds the menu, the recent actions, and `PAL_GROUPS`, the groups in the order of the menu. Each group has a file in `lib/hopen/palette/` with two functions: `pal_items_GROUP DIR` adds its actions with `pal_add`, and `pal_run_GROUP ID DIR` runs one of them, or sets `PAL_MISS=1` for an ID of another group. A new action needs a change in one group file only. A new group needs a file, a word in `PAL_GROUPS`, and a `source` line in `bin/hopen`. Keep each ID the same, because the recent list saves the IDs. `tests/test-palette-groups.sh` makes sure that each action has exactly one group that runs it. In a Herdr popup (`HERDR_ACTIVE_PANE_ID` set, no `HERDR_PANE_ID`), `then_wait` waits for Enter after an action that prints a result, because the popup closes when its command ends. The key is a `[[keys.command]]` popup in `config/herdr/config.toml`.

`hopen --quick-open` (the Herdr key `Cmd+P`, or `Ctrl+B`, then `F`) and a search result from a popup open a file through `open_target PATH ROOT [LINE]`. It tries these places in order:

1. The focused pane runs Neovim. `drop_in` sends `:drop`.
2. The focused pane is a shell at its prompt. `herdr pane run` starts the editor there.
3. Another pane of the tab runs Neovim.
4. A new split on the right, with `exec env EDITOR`, so that the split closes with Neovim.
 `pane_runs PANE editor|shell` reads `herdr pane process-info`. `PAL_PLACE` (`right`, `down`, or `tab`) skips the order and asks `run_at` for a new editor in that place. The palette sets it from `Ctrl+V`, `Ctrl+S`, and `Ctrl+T` (fzf `--expect`), or from a word after the action in the numbered menu.

The fourth argument of `pal_add` is the hint at the right of an action: the direct key first, then the prefix key or the command, for example `Cmd+T, Ctrl+B C`. `pal_add` stores four fields for each action: the ID, the group, the plain line, and the line with colors. fzf shows the line with colors, and the numbered menu the plain line.

`lib/hopen/ui.sh` holds the look of every menu. `ui_fzf` runs fzf with the colors of the Herdr theme, a rounded frame, and a label. `group_color` gives each group of the palette one color, and `dim_folders` shows the folder of a file dim in quick open. With `NO_COLOR` set, `ui_color` fails, and the menus use no color. Use these functions for a new menu, so that it looks like the others.

`--with-ignored FOLDER` calls `add_search_dir`, which adds the folder to `SEARCH_IN`. Then `fd_cmd` and `search_text` search only those folders, with `--no-ignore-vcs`, and `skip_args` leaves out the folders in `SKIP_DIRS`, such as `node_modules` and `.venv`.

The integration actions of the palette read `herdr integration status` through `integrations`, which prints `name<TAB>state`. A line can have ` (experimental)` after the name.

`hopen --completion zsh|bash` prints a completion script. The script calls `hopen --complete lists|templates|tasks` for the names. The bash script must work with bash 3.2, so it uses no `mapfile` and no `compopt`. `tests/test-hopen-list.sh` runs it.

`hopen` never closes a workspace, a tab, or a pane.

## Trust

A list can come from another person, so its commands and environment values are not trusted by default. `list_trusted` asks before `hopen` uses them, and it saves the checksum of an approved file in `~/.local/state/hopen/trusted.tsv`. A changed file needs a new approval. With no terminal, only `--trust` approves a list. `find_lists` keeps a list whose own name is the session over a list that only claims the name with `session` or `hopen.session`. Keep both rules when you change the reader.

## Templates

A template is a file `config/templates/<name>.layout`. The setup copies it to `~/.config/hopen/templates`. Each line is one pane: `NAME FROM DIRECTION SIZE COMMAND`. The comment at the top of `config/templates/code.layout` explains each field. `plain` is the default, and it has no file.

If you add a template, add it to `docs/templates.md`, and record its image with `tests/capture-media.sh`.

## The Auto Title guard

The Auto Title plugin also names panes. It keeps a name that a person chose, but every session writes its choices to one shared file, and pane IDs repeat across sessions. After a restart, the plugin can rename a template pane. For `HOPEN_GUARD_SECONDS` (30 by default), `guard_names` runs in the background and puts back each template pane name and each list tab name (`GUARD_TABS`) that changed. `HOPEN_GUARD_SECONDS=0` turns it off. Keep the guard while the plugin uses one shared file for all sessions.

## Pitfalls

Each of these mistakes broke `hopen` one time:

- In a split of a line, bash joins two tabs in a row, so an empty field moves the fields after it. For this reason, the reader uses the byte `0x1e` and writes `-` for an empty field. Do not go back to tabs.
- Python `splitlines()` also ends a line at the byte `0x1e`. Split the output of the reader at new lines only.
- A template name from a list must match `[A-Za-z0-9][A-Za-z0-9_-]*`. A name such as `../../x` loads a file from outside the templates folder, and runs its programs with no approval.
- A list can hide terminal escape codes or bidi characters in a name. `emit` shows each control, format, and separator character as `?`. Keep each new field in `emit`.
- An automated security review of each change to the list reader or to the approval found a real problem four times in a row. After such a change, ask for a security review before the merge.
- Before you add a feature, read what Herdr and the installed tools already do. Read `herdr --help` and the Herdr docs. If a tool already does it, use that tool, and install nothing new.
- `bin/hopen` loads every module of `lib/hopen/` before it reads the options. Put a new function in the module of its part. A module defines functions and variables, and runs nothing, so that the order of the modules does not matter. A new module needs a `source` line with a `# shellcheck source=` line in `bin/hopen`, and a line in `AGENTS.md`.
- `hopen` finds its modules in `../lib/hopen` from its own folder. The setup, `install.sh`, and `tools/release.sh` install or pack the modules with `hopen`. A new place that installs `hopen` must install the modules too.
- `choose` gets its items on stdin, so it reads the answer from `/dev/tty`. A menu that reads stdin gets an item, not the answer.
- With an empty `TERM`, or `TERM=dumb`, fzf draws nothing. `choose` uses the numbered menu then.
- In bash 5, `${path/#$HOME/~}` expands the `~` again, and prints the full path. Use `short_path`.
- `lib/hopen/` is also a Python package. A Python module sits next to its bash module, for example `lists.py` next to `lists.sh`, with unit tests in `tests/python/`. bash calls the package only through `hopen_py`, which runs `python3 -I -B lib/hopen/__main__.py`. A new bash caller needs an `internal` command in `cli.py`. `install.sh` copies the `.py` files too. `docs/code-layout.md` has the rules of the move to Python.
- A Python function must give the same output as the bash function that it replaces. Compare the old and the new code on the same input before the merge, for example the old `find_lists` and the new one on a home folder with hard cases.
- The Python parts must run on Python 3.11. Python 3.11 refuses a backslash inside the braces of an f-string. Use `.format`.
- The bash completion must run on bash 3.2, the bash of macOS. Do not use `mapfile` or `compopt`.
- On macOS, `/var` is a link to `/private/var`, and `lsof` shows the real path. Compare folders with their real paths.
- Small Linux systems have no `ss` and no `lsof`. `--ports` reads `/proc/net/tcp` and `/proc/net/tcp6` on Linux.
- A command line is visible to each user in `ps`. Send an environment value to a child program on stdin or on another file descriptor, not as an argument. `list_trusted` sends the env file values on fd 3 and the question on fd 4 to `trust.py`, because stdin must stay free for the answer.
- A checksum that is not 64 hexadecimal characters means "not approved". An empty checksum must never match.
- A Herdr popup has `HERDR_ACTIVE_PANE_ID` and no `HERDR_PANE_ID`. Use `${HERDR_PANE_ID:-${HERDR_ACTIVE_PANE_ID:-}}` for the pane to split.
- `herdr pane split` gives the focus to the new pane only with `--focus`. `herdr pane focus` takes a direction, not a pane ID, so `focus_pane` steps from the focused pane toward the target through `herdr pane layout`.
- Herdr has no option to start a split or a tab with a command. Text that comes before the shell starts gets lost. So `split_run` and `new_tab_run` wait for the prompt of the new pane with `pane_ready` before `herdr pane run`.
- A folder or file name can start with a dash, for example `-x`. fd, rg, and Neovim then read it as an option. `add_search_dir` puts `./` in front of such a name, the file lists keep the `./`, and `open_in_editor` refuses a path that starts with a dash. An automated security review found this one.
- A file name can hold any text, also `:` and `$(...)`. For the line of an `rg` result, `hopen` accepts digits only. An automated security review found this one: the line went unquoted into a command for a shell and for Neovim. Quote each value from a file name with `printf '%q'`, and check each number.

## Rules

- `hopen` must be safe to run again. A second run adds only the folders with no workspace.
- `hopen` must never close or rename something that a person made.
- Keep the version line `HOPEN_VERSION="dev"`. `tools/release.sh` writes the release tag into it.
- Use `python3 -I` for every Python part, so that a file in the current folder cannot change the program.

## Test a change

```bash
tests/run-macos.sh server
```

```bash
tests/run-linux.sh
```

Follow the `herdspace-test` skill to find the sandboxes of the machine. Both run `tests/verify-server.sh`, which opens real lists in a throwaway Herdr session and restarts it. Do not test against the Herdr server of the person, and do not close their panes. If you change a template, run `tests/capture-media.sh`. Before you copy the new images to `docs/media`, look at them.
