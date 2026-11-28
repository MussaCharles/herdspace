# The layout of the code

This page is for people who change herdspace. It says what each file of the code does, and how a command loads its modules. It also says where the setup installs them, and how to add an action or a command. A module is a small file of functions. A command loads its modules at its start.

## The commands and their modules

| Command | Main file | Modules | Installed to |
|---------|-----------|---------|--------------|
| `hopen` | `bin/hopen` | The Python package `lib/hopen/`, with `lib/hopen/palette/` | `~/.local/bin/hopen` and `~/.local/lib/hopen/` |
| `herdspace` | `bin/herdspace` | `lib/herdspace/*.sh` | `~/.local/bin/herdspace` and `~/.local/lib/herdspace/` |
| The setup | `bootstrap.sh` and `bootstrap/platforms/*.sh` | `bootstrap/lib/*.sh` | Not installed. The setup runs from the release folder. |

The main file of `herdspace` holds the help, the options, and the dispatch. `bin/hopen` is a short bash file that starts the Python package. A module defines functions and variables. At its load, it runs nothing. So a test can load one module alone.

## How a command finds its modules

`bin/hopen` and `bin/herdspace` find their modules in `../lib/<name>` from their own folder. They follow a symbolic link to the real file first. If the modules are missing, the command stops with a message that says how to fix it.

The setup installs the modules before the command, so that a new command never runs with old modules. `install.sh` does the same for `hopen`. `tools/release.sh` puts the modules of `hopen` in both archives. The uninstall removes the modules, and `herdspace uninstall` removes its own modules last, because it runs from them.

`bootstrap/lib/common.sh` loads the other shared files of the setup from its own folder. It finds the folder with plain bash, with no outside command, because a test can run it with a PATH of stub commands only.

## hopen

`hopen` is Python, with only the standard library. `bin/hopen` finds `lib/hopen/`, picks Python 3.11 or later, and runs `python3 -I -B lib/hopen/__main__.py hopen TAG PATH ARGS`: the release tag, the path of `bin/hopen`, and the arguments of the person. `-I` keeps out the environment and the current folder, and `-B` writes no `__pycache__` folder next to the installed files.

| File | What it does |
|------|--------------|
| `lib/hopen/__main__.py` | The entry point. It loads the package from its own folder by its path, so that no other package named hopen can take its place. |
| `lib/hopen/cli.py` | It starts `main.py`. Its `internal` commands serve the tests and the background guard. |
| `lib/hopen/main.py` | The options and the main steps of `hopen`, and `hopen <folder>`. |
| `lib/hopen/core.py` | The common helpers: names, paths, messages, and the sort order of the locale. |
| `lib/hopen/lists.py` | `read_list` reads one list, a VS Code workspace file or a `herdspace.toml` file. `find_lists` finds the lists of the home folder, and `no_list_message` helps with a name that has no list. |
| `lib/hopen/trust.py` | The approval of the commands and environment values of a list. |
| `lib/hopen/sessions.py` | The Herdr sessions: start one, open the projects of a list, start the programs again, apply a template, and attach. |
| `lib/hopen/templates.py` | The layout templates: find, list, and read one, and the guard of the pane names. |
| `lib/hopen/panes.py` | The Herdr panes: wait for one, split, open a tab, find the editor of a tab, and open a file in it. |
| `lib/hopen/editor.py` | Open a file in the editor, and the command that starts the herdspace Neovim. |
| `lib/hopen/ui.py` | The look of the menus, like a Herdr popup, and the questions: a choice, a text, a yes or no, and a pick of folders. |
| `lib/hopen/tasks.py` | `hopen --task`, with the environment of the project. |
| `lib/hopen/search.py` | The commands of `fd`, `find`, and `rg` for the file lists and the text search. |
| `lib/hopen/quickopen.py` | Quick open, like `Ctrl+P` in VS Code, and the menus of `hopen --find` and `--grep`. |
| `lib/hopen/ports.py` | `hopen --ports`, like the Ports view of VS Code. |
| `lib/hopen/prefix.py` | The prefix key of Herdr, read from the Herdr configuration, for the palette and the messages. |
| `lib/hopen/convert.py` | `hopen --convert`: write a `herdspace.toml` file from a VS Code workspace file. |
| `lib/hopen/completion.py` | The shell completion scripts, for zsh and bash. |
| `lib/hopen/palette/__init__.py` | The menu of the command palette, the recent actions, and `GROUPS`, the groups in the order of the menu. |
| `lib/hopen/palette/<group>.py` | One group of actions of the palette, for example `git.py` or `layout.py`. |

### Add an action to the palette

1. Open the file of its group in `lib/hopen/palette/`.
2. In `items(ctx)`, add a line `ctx.add(ID, GROUP, TEXT, HINT)`. The ID must be new, and it must stay the same later, because the recent list saves the IDs.
3. In the table `ACTIONS`, add the ID and the function that runs it. An ID that ends with `:` matches each ID that starts with it, for example `open:` for `open:work`.
4. Run `tests/test-palette-groups.sh` and `python3 -B -m unittest discover -s tests/python`. If an action has no group that runs it, the test fails.

A new group needs a new file with `items` and `ACTIONS`, and its name in `GROUPS` in `__init__.py`.

## The herdspace command

| File | What it does |
|------|--------------|
| `lib/herdspace/common.sh` | The helpers that more than one command uses: the installed and the latest version, and checksums. |
| `lib/herdspace/version.sh` | `herdspace version`, and the notice of a new release. |
| `lib/herdspace/update.sh` | `herdspace update`, which runs the setup of a release again with the saved options. |
| `lib/herdspace/editor.sh` | `herdspace editor`, the defaults of the herdspace Neovim. |
| `lib/herdspace/keys.sh` | `herdspace keys`, the Ghostty keys of a client. |
| `lib/herdspace/prefix.sh` | `herdspace prefix`, the prefix key of Herdr. The setup also loads it, to keep a saved prefix in an update. |
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

## The rules of the Python code

- Use only the standard library. A person installs no package, and no `pip`, `pipx`, or `uv`.
- The code must run on Python 3.11.
- Each module has unit tests in `tests/python/`, with `unittest`.
- A new module needs a row in the table of this page.
- If nobody changed a file of `~/.local/lib/hopen/` that a release no longer ships, an update of the setup removes it. `prune_tree` in `bootstrap/lib/files.sh` does it.

## Check and test a module

shellcheck reads the modules through the main file of each command, with `external-sources=true` in `.shellcheckrc`. Run the command of CI:

```bash
shellcheck -S warning bin/hopen bin/herdr-update-check bin/herdspace bootstrap.sh bootstrap/lib/*.sh bootstrap/platforms/*.sh tests/*.sh tools/*.sh install.sh
```

A unit test imports a module of the package, and calls its functions with no Herdr. A stub `herdr` in the PATH answers like Herdr and records each call. Run the unit tests with `python3 -B -m unittest discover -s tests/python`. `tests/test-hopen-list.sh` runs `bin/hopen` and the `internal` commands of the package. The [testing guide](testing.md) lists each test.
