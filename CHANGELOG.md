# Changelog

All notable changes to herdspace are in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Tasks, like `tasks.json` in VS Code: `tasks` in `herdspace.toml`, or `hopen.tasks` in a VS Code workspace file, names the commands of a project. `hopen --task test` runs one in a new Herdr pane, and `hopen --task` shows a menu.
- `hopen --find` (the shell command `ff`) opens a file that you choose with fzf, like Ctrl+P in VS Code. `hopen --grep TEXT` (the shell command `fif`) searches the files and opens a result at its line, like Ctrl+Shift+F.
- `hopen --ports` shows each TCP port that your programs listen on, with the program and its project, like the Ports view of VS Code.
- A command palette, like Ctrl+Shift+P in VS Code: `Cmd+Shift+P` on a Mac or `Ctrl+Shift+P` on Linux opens `hopen --palette` in Herdr. It runs tasks, finds files, searches, shows the ports, applies templates, and opens lazygit. Ghostty no longer opens its own command palette with that key, unless you keep the keys of your terminal.
- The guide `docs/vscode.md` lists the herdspace command or key for each VS Code action, with a Neovim cheat sheet and links to the official Neovim guides.
- The cheat sheet explains how to give each agent its own git worktree with Herdr.

## [0.4.0] - 2026-11-11

### Added

- `hopen` with no name shows a menu of the lists, and opens the one you choose. It uses fzf when it is installed, and a numbered menu when it is not.
- `hopen .` opens the current folder as one workspace, with no list, as `code .` does in VS Code. `hopen <path>` opens another folder. A list in the folder wins.
- Shell completion for `hopen` in zsh and bash. Tab completes list names, options, and template names. The server setup turns it on for zsh, and `hopen --completion zsh|bash` prints the script.
- `env_file` in `herdspace.toml`, and `hopen.envFile` in a VS Code workspace file, load the environment values of a project from a `.env` file. The approval question hides the values whose names look like secrets.
- `tests/bench-hopen.sh` measures how long `hopen` takes with 20 projects, and the testing guide has the numbers of a reference run.

### Fixed

- The Auto Title plugin could replace the name of an extra tab of a list. `hopen` now keeps the tab names for 30 seconds, as it does for template pane names.
- With bash 5, `hopen --list` and the messages of `hopen` showed a path in the home folder in full, in place of `~/...`.

## [0.3.0] - 2026-11-11

### Added

- Each setup run starts with a prerequisites step. It lists the missing items, installs them after one question, and lets you skip the optional ones. `--yes` installs them with no question.
- The setup guide has a "Before you start" list, with the official guides to turn on SSH on a server.
- New list settings for `hopen`: `hopen.session`, `hopen.parentWorkspace`, `hopen.onOpen`, `hopen.env`, and `hopen.tabs`.
- `hopen` reads a `herdspace.toml` list, the TOML list format of herdspace. It needs Python 3.11 or later.
- `hopen --convert` writes a `herdspace.toml` from a VS Code list.
- `hopen` asks before it uses the commands and environment values of a list, and again after the list changes. `--trust` approves a list with no question.
- The testing guide recommends sandboxes for tests: Docker containers for Linux, and Tart VMs for macOS.

### Changed

- The docs present `herdspace.toml` as the list format. A VS Code workspace file still works, for people who come from VS Code.
- On a macOS server, the prerequisites step makes sure that Python 3.11 or later is there, so that `hopen` can read a `herdspace.toml` list.

## [0.2.0] - 2026-11-11

### Added

- The hopen guide, `docs/hopen.md`, has every `hopen` command, and the steps to install, update, and remove it.
- The herdspace skill, `skills/herdspace`, teaches a coding agent to use `hopen` and the setup. Install it with `npx skills add MussaCharles/herdspace --skill herdspace -g`.
- `AGENTS.md` and the skills in `.agents/skills/` give coding agents the rules of this project.
- The keyboard shortcuts guide, `docs/keyboard-shortcuts.md`, lists each key that the client setup changes.
- The client option `--keep-terminal-keys` keeps the keys of Ghostty and macOS. The setup saves the choice, and `--use-herdspace-keys` changes it back.

### Changed

- The install commands in the docs use the newest release. To install a specific release, add `--version <tag>`.
- The Quick start starts with a table of the options, with a link to each one.

### Removed

- The skills `herdspace-server`, `herdspace-client`, and `herdspace-update`. `install.md`, the herdspace skill, and the `herdspace-bootstrap` skill replace them.

## [0.1.1] - 2026-11-11

The first release of herdspace.

### Added

- `hopen` opens each folder of a VS Code workspace file as a Herdr workspace in one named session. It starts the template programs again after a restart.
- Five pane templates: `plain`, `code`, `agent`, `grid`, and `review`. You can add your own.
- `bootstrap.sh server`, `client`, and `both` set up macOS, Debian, Ubuntu, and Windows with WSL with one command. A run does only what is missing, and it asks before it replaces a file that you changed.
- `install.sh` installs only `hopen` on a machine that has Herdr.
- `install.md` has steps that a coding agent follows to do the setup.
- Guides for setup, SSH, templates, WSL, updating, and testing.

[Unreleased]: https://github.com/MussaCharles/herdspace/compare/0.4.0...HEAD
[0.4.0]: https://github.com/MussaCharles/herdspace/compare/0.3.0...0.4.0
[0.3.0]: https://github.com/MussaCharles/herdspace/compare/0.2.0...0.3.0
[0.2.0]: https://github.com/MussaCharles/herdspace/compare/0.1.1...0.2.0
[0.1.1]: https://github.com/MussaCharles/herdspace/releases/tag/0.1.1
