# The layout of the code

This page is for people who change herdspace. It says what each file of the code does, and how a command loads its modules. It also says where the setup installs them, and how to add an action or a command. A module is a small file of functions. A command loads its modules at its start.

## The commands and their modules

| Command | Main file | Modules | Installed to |
|---------|-----------|---------|--------------|
| `hopen` | `bin/hopen` | `lib/hopen/*.sh` and `lib/hopen/palette/*.sh` | `~/.local/bin/hopen` and `~/.local/lib/hopen/` |
| `herdspace` | `bin/herdspace` | `lib/herdspace/*.sh` | `~/.local/bin/herdspace` and `~/.local/lib/herdspace/` |
| The setup | `bootstrap.sh` and `bootstrap/platforms/*.sh` | `bootstrap/lib/*.sh` | Not installed. The setup runs from the release folder. |

The main file of a command holds the help, the options, and the main steps or the dispatch. A module defines functions and variables. At its load, it runs nothing. So the order of the modules does not matter, and a test can load one module alone.

## How a command finds its modules

`bin/hopen` and `bin/herdspace` find their modules in `../lib/<name>` from their own folder. They follow a symbolic link to the real file first. If the modules are missing, the command stops with a message that says how to fix it.

The setup installs the modules before the command, so that a new command never runs with old modules. `install.sh` does the same for `hopen`. `tools/release.sh` puts the modules of `hopen` in both archives. The uninstall removes the modules, and `herdspace uninstall` removes its own modules last, because it runs from them.

`bootstrap/lib/common.sh` loads the other shared files of the setup from its own folder. It finds the folder with plain bash, with no outside command, because a test can run it with a PATH of stub commands only.

## hopen

| File | What it does |
|------|--------------|
| `lib/hopen/core.sh` | The common helpers: messages, a check for a command, names, and JSON. |
| `lib/hopen/ui.sh` | The look of the menus, like a Herdr popup, and the questions: a choice, a text, and a yes or no. |
| `lib/hopen/lists.sh` | The project lists: find the lists, show them, and choose one. `read_list` runs `lists.py` for each list. |
| `lib/hopen/lists.py` | The reader of one list, a VS Code workspace file or a `herdspace.toml` file, in Python. It prints one line for each workspace, tab, task, and warning. |
| `lib/hopen/trust.sh` | The approval of the commands and environment values of a list. |
| `lib/hopen/sessions.sh` | The Herdr sessions: start one, open the projects of a list, start the programs again, and attach. |
| `lib/hopen/templates.sh` | The layout templates: find, list, and apply one, and the guard of the pane names. |
| `lib/hopen/panes.sh` | The Herdr panes: wait for one, split, open a tab, find the editor of a tab, and open a file in it. |
| `lib/hopen/editor.sh` | Open a file in the editor, and the command that starts the herdspace Neovim. |
| `lib/hopen/tasks.sh` | `hopen --task`, with the environment of the project. |
| `lib/hopen/search.sh` | Find and search the files of a project, also with the files that `.gitignore` names. |
| `lib/hopen/quickopen.sh` | Quick open, like `Ctrl+P` in VS Code. |
| `lib/hopen/ports.sh` | `hopen --ports`, like the Ports view of VS Code. |
| `lib/hopen/convert.sh` | `hopen --convert`: write a `herdspace.toml` file from a VS Code workspace file. |
| `lib/hopen/completion.sh` | The shell completion, for zsh and bash. |
| `lib/hopen/palette.sh` | The menu of the command palette, the recent actions, and `PAL_GROUPS`, the groups in the order of the menu. |
| `lib/hopen/palette/<group>.sh` | One group of actions of the palette, for example `git.sh` or `layout.sh`. |

### Add an action to the palette

1. Open the file of its group in `lib/hopen/palette/`.
2. In `pal_items_<group>`, add a line `pal_add ID GROUP TEXT HINT`. The ID must be new, and it must stay the same later, because the recent list saves the IDs.
3. In the `case` of `pal_run_<group>`, add a branch for the ID.
4. Run `tests/test-palette-groups.sh`. If an action has no group that runs it, the test fails.

A new group needs three things: a new file with both functions, its name in `PAL_GROUPS`, and a `source` line in `bin/hopen`. Put a `# shellcheck source=` line above the `source` line.

## The herdspace command

| File | What it does |
|------|--------------|
| `lib/herdspace/common.sh` | The helpers that more than one command uses: the installed and the latest version, and checksums. |
| `lib/herdspace/version.sh` | `herdspace version`, and the notice of a new release. |
| `lib/herdspace/update.sh` | `herdspace update`, which runs the setup of a release again with the saved options. |
| `lib/herdspace/editor.sh` | `herdspace editor`, the defaults of the herdspace Neovim. |
| `lib/herdspace/keys.sh` | `herdspace keys`, the Ghostty keys of a client. |
| `lib/herdspace/uninstall.sh` | `herdspace uninstall`, which removes what the setup wrote. |

### Add a herdspace command

1. Add a file `lib/herdspace/<command>.sh` with a function `cmd_<command>`.
2. In `bin/herdspace`, add a `source` line with a `# shellcheck source=` line above it.
3. Add a line for the command in the `case` at the end of `bin/herdspace`, and in the help at the top.
4. Add a test to `tests/test-herdspace-cmd.sh`.

## The setup

| File | What it does |
|------|--------------|
| `bootstrap/lib/common.sh` | The shared values and options. It loads the next five files. |
| `bootstrap/lib/ui.sh` | The output: colors, marks, lines, boxes, and progress. |
| `bootstrap/lib/files.sh` | The manifest of the installed files, and the install of files and marked blocks. |
| `bootstrap/lib/ask.sh` | The questions about a file that a person changed. |
| `bootstrap/lib/run.sh` | The parts of a run, the summary table, and the next steps. |
| `bootstrap/lib/tools.sh` | The download of pinned repositories, and Homebrew. |
| `bootstrap/lib/prereqs.sh` | The prerequisites step, which starts each run. |
| `bootstrap/lib/server.sh` | The steps of a server, on Linux and macOS. |
| `bootstrap/lib/client.sh` | The steps of a client, on Linux and macOS. |
| `bootstrap/lib/shell.sh` | zsh, Oh My Zsh, Powerlevel10k, the prompt color, and the `herdspace` command. |
| `bootstrap/lib/linux-tools.sh` | The tools from their release pages on Linux, each with its checksum. |
| `bootstrap/lib/service-linux.sh` and `service-macos.sh` | The service that starts the Herdr server. |

A platform script sources only `common.sh`, and then the step files that it needs. The `herdspace-bootstrap` skill lists the functions that a step uses.

## The Python modules

herdspace moves from bash to Python one module at a time. A Python module is a file next to the bash module that runs it, for example `lib/hopen/lists.py` next to `lists.sh`. These rules hold for each Python module:

- Use only the standard library. A person installs no package, and no `pip`, `pipx`, or `uv`.
- The bash module runs the file with `python3 -I`, so that a file in the current folder cannot change the program.
- The code must run on Python 3.11.
- Each Python module has unit tests in `tests/python/`, with `unittest`.

## Check and test a module

shellcheck reads the modules through the main file of each command, with `external-sources=true` in `.shellcheckrc`. Run the command of CI:

```bash
shellcheck -S warning bin/hopen bin/herdr-update-check bin/herdspace bootstrap.sh bootstrap/lib/*.sh bootstrap/platforms/*.sh tests/*.sh tools/*.sh install.sh
```

A test can load one module with `source`, with the modules that it needs, and call its functions with no Herdr. `tests/test-hopen-list.sh` loads `lib/hopen/core.sh`, `lists.sh`, and `trust.sh` this way. Run the unit tests of the Python modules with `python3 -m unittest discover -s tests/python`. The [testing guide](testing.md) lists each test.
