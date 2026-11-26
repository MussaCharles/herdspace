# Changelog

All notable changes to herdspace are in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- The herdspace skill for agents knows quick open, `Ctrl+Q`, the place keys and the integration actions of the palette, and the Herdr integrations of the server setup. It says that herdspace never installs an agent.
- `docs/setup.md` says plainly that the client setup installs no Herdr, that `--server` installs nothing on a server, and what `both` does, and the table of the parts has a Both column.

## [0.14.0] - 2026-11-27

### Changed

- Each action of the palette shows its key or its command at the right, with the direct key first, for example `Cmd+T, Ctrl+B C`. The header says how to open the palette, and that the `Cmd` keys are `Ctrl+Shift` on Linux.
- The palette shows the Herdr integrations, and adds or removes one for an agent. In Herdr, a result of "Files: Search in the files" opens like quick open, at its line, and "Files: Find a file, and open it" shows only outside Herdr, because quick open replaces it.
- Quick open opens the file in the focused pane when it is a shell at its prompt, and the shell comes back when Neovim closes. A new editor of quick open closes its split when Neovim closes, and the focus returns to the old pane.
- `Ctrl+Q` in Neovim closes the file, as `Cmd+W` in VS Code, and closes Neovim when no other file is open.
- The server setup adds the Herdr integration for each of the 18 agents that Herdr 0.9.5 supports, when the agent command is on the `PATH` and its folder exists. It looks for the same command names as Herdr, for example `cursor-agent`, not the `cursor` command of the Cursor editor. See [Agent programs and integrations](docs/agents.md#agent-programs-and-integrations).
- The README has a "Commands" section with the daily commands: the palette, quick open, `ff`, `fif`, tasks, ports, and the `herdspace` commands.
- The keys and commands have one page for each task: [move around](docs/navigation.md), [panes and layout](docs/layout.md) (with the swap keys `ctrl+b`, `shift+h` to `shift+l`), [files and the editor](docs/files.md), [git and worktrees](docs/git.md), [sessions](docs/sessions.md), and [agents](docs/agents.md). The cheat sheet keeps the daily commands and links each page. The README starts with the links to the docs and the quick start.

## [0.13.0] - 2026-11-26

### Added

- Quick open, like `Cmd+P` in VS Code: `Cmd+P` in Herdr (`Ctrl+B`, then `F` on Linux) lists the files of the project. The chosen file opens in the Neovim pane of the tab, or in a new split on the right, and gets the focus. See [Quick open](docs/hopen.md#quick-open).
- Neovim shows Markdown headings with an icon in place of `###`, and checkboxes as boxes. It shows images in a Markdown file and image files, with the Kitty graphics protocol, in Ghostty and in Herdr 0.9.2 and later. Without ImageMagick, it shows PNG files only.
- The palette action "Files: Read a Markdown file, rendered" opens a Markdown file of the folder read-only in the editor. See [Markdown and images](docs/files.md#markdown-and-images).

### Changed

- `docs/keyboard-shortcuts.md` links the keyboard docs of Herdr, and its new section "Move in the lists" gives the keys of the Goto picker (`j`, `k`, `/`) and of the herdspace lists (`Ctrl+N`, `Ctrl+P`).

### Fixed

- After `Ctrl+V` or `Ctrl+S` in the palette, the new pane gets the focus. Before, the focus stayed on the old pane.

## [0.12.2] - 2026-11-25

### Fixed

- `ls -ltr` and other commands with a flag that means something else in `eza` failed, for example with `invalid value 'rF' for '--time <FIELD>'`. `ls` and `ll` now run `eza` only with the flags `-l`, `-a`, `-A`, `-R`, `-F`, `-d`, `-1`, `-r`, and `-h`, and the standard `ls` with any other flag.

### Changed

- The install jobs of the Release check wait until the files of a new release download, so that they do not fail right after a publish. See `tools/wait-release-files.sh` and [docs/ci.md](docs/ci.md).

## [0.12.1] - 2026-11-25

### Fixed

- On Linux, the "System packages" step no longer fails with `held broken packages` when a tool comes from another source than apt, for example Node.js from NodeSource, where the `npm` package of the system conflicts with the `nodejs` package. If the commands of a package already work, the setup installs no package for them and names them. A package that is held with `apt-mark hold` now counts as installed.

## [0.12.0] - 2026-11-25

### Added

- In the command palette, `Ctrl+V`, `Ctrl+S`, and `Ctrl+T` open a program on the right of the current pane, below it, or in a new tab, instead of its usual place. This works for the editor, lazygit, find, search, tasks, agents, and worktrees. In the numbered menu, a word after the action does the same, for example `edit right`. See [Choose where a program opens](docs/hopen.md#choose-where-a-program-opens).

## [0.11.1] - 2026-11-25

### Changed

- The README and `docs/updating.md` say what an update changes in a running session: the new commands work at once, an open shell needs `exec zsh` for the shell changes, and a new Herdr version needs a restart of the session.

### Fixed

- `tools/known-hashes.sh` also lists a file version that only a merge commit made, for example the `bin/herdspace` of 0.11.0. A setup with no manifest now updates such a file with no question.
- `herdspace update` no longer prints `work: unbound variable` at the end, and it removes its download folder. The cleanup at exit used a local variable of the function.
- With zsh 5.8, for example on Ubuntu 22.04, each new shell printed `extras.zsh:unset:59: _hs_keys[^[c]: invalid parameter name`, and the rest of the shell extras did not load. The extras now save only the keys that have another widget, so they need no `unset` of one key.

## [0.11.0] - 2026-11-25

### Added

- Each release tag has an SSH signature, and `.github/release-signers` lists the release keys. `docs/setup.md` shows how to check a tag with `git tag -v`, and what the checksum, the attestation, and the signature each show.
- `herdspace update --version <tag>` installs one release, also an older one, with the saved role and options. It checks the tag, says when it goes back, and leaves out a saved option that the older release does not know. See [Go back to an older release](docs/updating.md#go-back-to-an-older-release).
- `docs/setup.md` lists the supported systems, and the network use of each part, in "Network use and privacy". herdspace sends no telemetry. `docs/updating.md` has the rules for old options, in "Old options and deprecation".
- `herdspace uninstall` removes what the setup wrote. `herdspace uninstall --check` lists the changes and changes nothing. The command asks once, and it needs `--yes` with no terminal. It removes each file that no person changed, the marked blocks of herdspace, the Herdr login service, and the data of herdspace. On a Mac, it gives the Ctrl arrow shortcuts back to Mission Control. It keeps each file that you changed, and it never removes a project, a Herdr session, Herdr, or a package.

### Fixed

- The move of exports from the bash files to `~/.zshenv` no longer fails when `~/.zshenv` already has a block from an earlier move. The test after the move starts from the environment that zsh has after the old block, and checks only the new lines. If the test fails, the message names the variables that differ, with no value.
- `bootstrap.sh` and `install.sh` keep all their code in a `main` function, and the last line calls it. If a download with `curl` stops in the middle, bash runs nothing.

## [0.10.0] - 2026-11-24

### Changed

- The command palette lists every action in groups, as in VS Code: Projects, Tasks, Files, Git, Agents, Layout, Workspace and tabs, Sessions, Network, herdspace, Herdr, and Help. Each action shows its key or command at the right. The last 5 actions come first. The palette shows only the actions that fit the place, and an action that closes or stops something asks first.
- New palette actions: open this folder as its own workspace, open the session in a new window, lazygit in a new tab, git worktrees, go to an agent (blocked and done first), start an agent in a new pane, split and zoom, rename and new tabs, stop a session, update herdspace, the Ghostty keys, the Herdr checks, and a short table of the keys.

## [0.9.0] - 2026-11-24

### Added

- `herdspace keys normal` gives `Cmd+T`, `Cmd+W`, and `Cmd+K` back to Ghostty on a client, and `herdspace keys herdr` sends them to Herdr again. `herdspace keys` shows the current keys.
- The client setup turns on the `ssh-env` feature of Ghostty in a new `herdspace ssh` block. When you type `ssh` to a server without herdspace, Ghostty sends `TERM=xterm-256color`, so `clear` and other commands work there. It writes nothing on the server.

### Changed

- With the latest release already installed, `herdspace update` says that nothing is new, and runs no setup. To run the setup again anyway, run `herdspace update --force`.

### Fixed

- `herdspace help` no longer prints a line of the script. An unknown command, for example `herdspace --update`, prints one error line, suggests `herdspace update`, and says where the help is, as git and the GNU tools do.
- The move of the bash exports to `~/.zshenv` no longer fails its test when other lines of `~/.zshenv` also change a variable, for example `PATH`. The test now compares only the moved lines in bash and in zsh.
- After an export with a quoted value over more than one line, the scan of the bash files finds the later exports again. Before, it kept each later export as a line to move by hand.

## [0.8.0] - 2026-11-23

### Added

- `herdspace update` updates to the latest release with the role and the options of your last setup, after a checksum test. `herdspace --version` and `herdspace version` show the installed and the latest version. When a new release exists, the herdspace shell prints one line, at most once a day. It asks GitHub in the background, and `HERDSPACE_UPDATE_CHECK=0` turns it off.

- On Linux, when zsh is your login shell, the setup finds the plain `export` lines that are only in `~/.bashrc` or `~/.bash_profile`. At a terminal, it asks whether to move them to a marked block in `~/.zshenv`, so that zsh, the Herdr panes, and the agents have the variables. It never shows a value, backs up each file with mode 600 first, and puts the files back if a test after the move fails.

### Changed

- herdspace keeps its Neovim files in `~/.config/herdspace-nvim`, and never writes in your `~/.config/nvim`. The herdspace shell sets `NVIM_APPNAME=herdspace-nvim` only if you have no `~/.config/nvim`, so `nvim` starts your own Neovim if you have one. The Neovim files of an older herdspace move out of `~/.config/nvim` to a backup folder. A folder with a file that you changed stays.

### Fixed

- An update asks no question about a file that herdspace wrote and you did not change, also for an install from before the manifest. The setup knows the hash of each older herdspace version of each file.

## [0.7.0] - 2026-11-22

### Changed

- herdspace never replaces your `~/.zshrc`. It adds a marked block that loads the herdspace shell from `~/.config/herdspace/zshrc.zsh`. With no `~/.zshrc`, the setup writes a short one with the block, and your own lines go below it. The `~/.zshrc` of an older herdspace gets this layout, after a backup, and your own lines from it stay at its end, each behind `# `.
- For your own `~/.zshrc`, the setup asks whether to add a block that loads the full herdspace shell, a block that loads only the shell extras, or nothing.
- The shell extras add and never replace: an alias, a function, a variable, or a key that you set before them stays yours. `$HERDSPACE_EXTRAS_SKIPPED` lists what they skipped.
- When more than one file differs from the herdspace version, the setup first lists them all, and asks once: review one file at a time, keep all, or replace all. In the review, `d` shows the difference of that file only, and says that `q` comes back to the question.
- Before the setup changes the login shell from bash to zsh, it names your bash files that zsh does not read. The setup guide shows how to share aliases between bash and zsh.
- herdspace never replaces your Ghostty file. It writes two marked blocks at its top, `herdspace appearance` and `herdspace keys`, and your own lines below them win. The Ghostty file of an older herdspace gets this layout after a backup, and its own lines stay.
- `--keep-terminal-look` leaves out the herdspace colors and window size of Ghostty. On Linux, the setup writes no macOS-only Ghostty setting.
- The first client run explains the herdspace keys and asks which keys to use, before it changes any key.
- Ghostty gets replacement keys for the actions that lose their keys, for example `Cmd+Option+T` for a new tab. On a Mac, `Cmd+E` and `Cmd+Shift+G` keep their Ghostty action for a selection or an open search.
- The end of a client run says when Ghostty needs a full restart.

### Fixed

- The setup asks about each changed file of a folder too, for example the Neovim files. Before, it kept them with no question and listed them as kept.

## [0.6.4] - 2026-11-21

### Changed

- When the setup changes `config.toml`, it applies the new configuration to each running Herdr session with `herdr server reload-config`. The panes keep running.
- When a running session uses an older Herdr than the installed one, the setup names it, and says how to restart it with the new version.
- The update guide explains what an update does to running sessions.

## [0.6.3] - 2026-11-21

### Security

- Each release is checked for changes after the build. The "Release check" workflow builds the release again from its tag on a clean runner, and fails if a published file differs from that build. When all files match, it signs each file with a GitHub artifact attestation.
- `tools/release.sh --publish` stops when the commit is not the head of main, when a CI check of its pull request did not pass, or when the tag already has a release. `--preflight` runs only these checks.
- `tools/repo-settings.sh` turns on immutable releases, so that nobody can change the files of a published release.
- `tools/update-versions.sh` takes a release or a commit only when it is at least 7 days old, and it never moves a pin back. `PIN_MIN_AGE_DAYS` changes the wait.
- The weekly pin check also compares the Neovim plugins of `config/nvim/lazy-lock.json` with GitHub. A locked commit that is less than 7 days old opens the issue.
- The setup guide shows how to make sure that a release is genuine, in a browser or with `gh attestation verify`. This step is optional.

## [0.6.2] - 2026-11-20

### Added

- A "From tmux" guide, `docs/tmux.md`: the Herdr key or command for each tmux action, and how to run agents side by side in panes.
- `hopen project-name.code-workspace` opens a list file by its path. `hopen .` uses the only VS Code workspace file of a folder, also when its name is not the name of the folder.
- The cheat sheet starts with a table of daily Herdr commands: start, attach, leave, stop, and delete a session. It links to the official Herdr docs.

### Changed

- Newer pinned versions: delta 0.21.2 on Linux, and newer commits of the Auto Title plugin, Oh My Zsh, and Powerlevel10k.
- The setup output links to the docs on GitHub in place of a path in the repository.
- `hopen` reads `herdspace.toml` with the newest Python 3.11 or later that it finds, for example `python3.11` beside an older `python3`. The Linux server setup installs `python3.11` when `python3` is older, as on Ubuntu 22.04.
- The README and the hopen guide say that you write the list file yourself, and where it goes.
- The hopen guide shows how to install Python 3.11 or later on each system, also for one account with no `sudo`, with uv. The Python hint of `hopen` names uv too.

### Fixed

- The Python hint of `hopen` names `apt-get` on Linux, not `brew`.
- `hopen --task` keeps the name of the task pane when the Auto Title plugin renames the new pane.

## [0.6.1] - 2026-11-20

### Changed

- The setup guide shows the `curl` command in each section, and it moves the clone to one short note. It also says that a machine with no systemd user session skips the login service with no warning.
- The update guide says that the same `curl` command installs the newest release. The cheat sheet lists the command palette key, `ff`, `fif`, `hopen --task`, and `hopen --ports`.
- The setup shows a line before each long action: the package lists, each package that apt sets up, and each download.
- The Linux setup installs only the system packages that are missing, with `--no-upgrade`. It no longer upgrades a package that another account of a shared server can use.

### Fixed

- The templates guide had the keys for the next pane and the previous pane the wrong way around.
- The Linux setup no longer stops with no message when `apt-get update` fails for a package source of the machine that herdspace does not use, for example a local driver repository with no signature. It shows the error, and it goes on. If the install then fails, it says what to do.

## [0.6.0] - 2026-11-13

### Fixed

- The command palette no longer offers "Find a file" with no `fzf` installed. That action needs `fzf`.

### Added

- At a terminal, the setup shows a box for each step, numbered items with marks, and colors. It shows a progress bar for the Neovim plugins and language tools, and a summary table at the end. With no terminal, or with `NO_COLOR`, the output stays plain text.
- The end of a run shows the next steps for the role, with links to the docs of the release. It lists each backup with the command that puts the file back.
- For a changed `~/.zshrc`, two more answers: keep your file and add the herdspace shell extras, or replace it and copy your own lines to `~/.zshrc.local`.
- The shell extras are in their own file, `~/.config/herdspace/extras.zsh`: `ff`, `fif`, the completion of `hopen`, the `fzf` keys, `zoxide`, `eza`, and `bat`.
- lazygit: a clearer layout with less noise, and the count of changed lines of each file. A richer delta view has line numbers, and a second view shows the changed words. A narrow pane uses portrait mode, and the branches of coding agents have their own colors.
- Neovim: `nvim .` opens the file tree with the cursor in it. Folder icons have colors by folder name, and the arrow keys preview a file as `j` and `k` do. The editor has the background of the terminal.
- Neovim: a question before quitting with unsaved changes, and wrapped lines with their indent. A Python project uses its own `.venv`. A failed download of `lazy.nvim` gives a clear message, and the start is faster.

### Changed

- The README and `install.md` say which Herdr `hopen` needs: the terminal program `herdr`. The installer on the first page of herdr.dev installs the Herdr app, a different program.
- The release check runs each option of the Quick start with the command of the README: a server, a client with SSH to a server, one machine as both, and only `hopen`.
- The question about a changed file lists the changed files first. Each answer is on its own line, and the default has a mark. `K` and `R` say how many files they affect, and `R` asks once more before it replaces the other files.
- Show the difference uses `delta` or `git diff` with colors, and first shows the own lines of the person.
- Each yes question names its default: `[Y/n] (Enter = yes)`. Homebrew no longer asks a second time before an install.
- The end of a run no longer advises `--replace-all`, and it says `1 file`, not `1 files`.
- The README starts with the setup. It names the setup script `bootstrap.sh` and the project opener `hopen`, and shows what each option installs.
- The first line of a setup run names the script and its release, for example `herdspace setup (bootstrap.sh 0.5.1): a server on macOS.`
- The docs use `my-projects` as the example list, in place of `work`.
- For a name with no list, `hopen` shows the lists that exist, suggests the closest one, and shows how to create the list.
- If `--template` splits no project, because each project has a workspace already, `hopen` says so and names `hopen --apply`.

## [0.5.1] - 2026-11-12

### Fixed

- After a failed download of the Neovim plugins, the setup still reported the step as done. The step now tries again, warns, and tries again on the next run.
- The links of the contributing guide gave a 404 on the Contributing tab of the repository. They now start at the root of the repository.

### Changed

- The herdspace agent skill knows the tasks, `hopen --ports`, and the commands that only a person runs: `ff`, `fif`, and the command palette.
- The community files `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, and `SECURITY.md` are in the `.github` folder.

## [0.5.0] - 2026-11-12

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

[Unreleased]: https://github.com/MussaCharles/herdspace/compare/0.14.0...HEAD
[0.14.0]: https://github.com/MussaCharles/herdspace/compare/0.13.0...0.14.0
[0.13.0]: https://github.com/MussaCharles/herdspace/compare/0.12.2...0.13.0
[0.12.2]: https://github.com/MussaCharles/herdspace/compare/0.12.1...0.12.2
[0.12.1]: https://github.com/MussaCharles/herdspace/compare/0.12.0...0.12.1
[0.12.0]: https://github.com/MussaCharles/herdspace/compare/0.11.1...0.12.0
[0.11.1]: https://github.com/MussaCharles/herdspace/compare/0.11.0...0.11.1
[0.11.0]: https://github.com/MussaCharles/herdspace/compare/0.10.0...0.11.0
[0.10.0]: https://github.com/MussaCharles/herdspace/compare/0.9.0...0.10.0
[0.9.0]: https://github.com/MussaCharles/herdspace/compare/0.8.0...0.9.0
[0.8.0]: https://github.com/MussaCharles/herdspace/compare/0.7.0...0.8.0
[0.7.0]: https://github.com/MussaCharles/herdspace/compare/0.6.4...0.7.0
[0.6.4]: https://github.com/MussaCharles/herdspace/compare/0.6.3...0.6.4
[0.6.3]: https://github.com/MussaCharles/herdspace/compare/0.6.2...0.6.3
[0.6.2]: https://github.com/MussaCharles/herdspace/compare/0.6.1...0.6.2
[0.6.1]: https://github.com/MussaCharles/herdspace/compare/0.6.0...0.6.1
[0.6.0]: https://github.com/MussaCharles/herdspace/compare/0.5.1...0.6.0
[0.5.1]: https://github.com/MussaCharles/herdspace/compare/0.5.0...0.5.1
[0.5.0]: https://github.com/MussaCharles/herdspace/compare/0.4.0...0.5.0
[0.4.0]: https://github.com/MussaCharles/herdspace/compare/0.3.0...0.4.0
[0.3.0]: https://github.com/MussaCharles/herdspace/compare/0.2.0...0.3.0
[0.2.0]: https://github.com/MussaCharles/herdspace/compare/0.1.1...0.2.0
[0.1.1]: https://github.com/MussaCharles/herdspace/releases/tag/0.1.1
