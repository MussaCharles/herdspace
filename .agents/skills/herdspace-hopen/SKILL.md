---
name: herdspace-hopen
description: Change the hopen command or its pane templates in the herdspace repository. Use when you edit bin/hopen, a file in config/templates/, the list file format, the state files, or the Auto Title guard.
---

# Change hopen

`bin/hopen` opens each folder of a VS Code workspace file as a Herdr workspace in one named Herdr session. The [hopen guide](../../../docs/hopen.md) is the user view. This skill is the code view.

## How it works

1. `find_lists` finds a list at `~/<name>.code-workspace`, `~/<name>/<name>.code-workspace`, or `~/<name>/herdspace.toml`. The session has the name of the file or the folder, unless the list sets `hopen.session` or `session`. If two lists name one session, `herdspace.toml` wins, with a warning.
2. `read_list FILE items` reads either format with Python, and prints one line for each workspace and each extra tab: `R` (the parent workspace), `P` (a project), `T` (a tab), and `W` (a warning). The fields are separated by tabs, and an empty field is `-`, because bash joins two tabs in a row. Environment values are `KEY=VALUE` items, separated by the byte `0x1f`. VS Code accepts comments and trailing commas, so the reader removes them before it parses the JSON. `herdspace.toml` needs `tomllib`, so Python 3.11 or later.
3. If the Herdr session is stopped, `start_session` starts it.
4. For each folder with no workspace, `hopen` creates a workspace. The first workspace has the name of the session and opens the folder that holds the list file.
5. The `onOpen` command runs in the first pane. Then `apply_template` splits the new workspace into named panes, and it starts the program of each pane. Then each extra tab opens, with its own template and command. `ENV_ARGS` gives the `--env` values to each `workspace create`, `tab create`, and `pane split`.
6. `remember_template` writes one line for each workspace to `~/.local/state/hopen/<session>.tsv`: `label<TAB>template<TAB>id=name id=name`. An extra tab has the label `workspace/tab`.
7. After a stopped session starts again, `restart_programs` starts each template program again in a pane that shows only its shell. Herdr keeps the pane IDs after a restart, so `hopen` finds each pane by its ID. If the ID is gone, it uses the label.

`hopen` never closes a workspace, a tab, or a pane.

## Templates

A template is a file `config/templates/<name>.layout`. The setup copies it to `~/.config/hopen/templates`. Each line is one pane: `NAME FROM DIRECTION SIZE COMMAND`. The comment at the top of `config/templates/code.layout` explains each field. `plain` is the default, and it has no file.

If you add a template, add it to `docs/templates.md`, and record its image with `tests/capture-media.sh`.

## The Auto Title guard

The Auto Title plugin also names panes. It keeps a name that a person chose, but every session writes its choices to one shared file, and pane IDs repeat across sessions. After a restart, the plugin can rename a template pane. For `HOPEN_GUARD_SECONDS` (30 by default), `guard_names` runs in the background and puts back each template name that changed. `HOPEN_GUARD_SECONDS=0` turns it off. Keep the guard while the plugin uses one shared file for all sessions.

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

Both run `tests/verify-server.sh`, which opens real lists in a throwaway Herdr session and restarts it. Do not test against the Herdr server of the person, and do not close their panes. If you change a template, run `tests/capture-media.sh`. Before you copy the new images to `docs/media`, look at them.
