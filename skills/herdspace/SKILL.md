---
name: herdspace
description: Use herdspace to open projects in Herdr with hopen, add a project to a list, split a tab with a pane template, see the Herdr integrations of agents, and check or update the setup. Use it for a request to open, add, or arrange projects in Herdr, for hopen or herdspace, for an agent integration in Herdr, or to install or update herdspace.
license: MIT
metadata:
  source: "https://github.com/MussaCharles/herdspace"
---

# Use herdspace

herdspace has two parts. `hopen` opens the projects of a list in one Herdr session. `bootstrap.sh` sets up a machine. A list is a `herdspace.toml` file in a folder, or a VS Code workspace file. Each list becomes one Herdr session, with the name of the folder or the file.

If `hopen --version` fails, herdspace is not installed. Follow the agent install steps at `https://raw.githubusercontent.com/MussaCharles/herdspace/main/install.md`.

## Open projects

| The person wants to | Run |
|---------------------|-----|
| Open the projects of the list `my-projects` | `hopen my-projects --no-attach` |
| Open one folder, with no list | `hopen ~/code/api --no-attach` |
| Open every list | `hopen --all` |
| See every list and its state | `hopen --list` |
| Open new projects with a template | `hopen my-projects --template code --no-attach` |
| See every template | `hopen --templates` |
| See the tasks of the project of the current folder | `hopen --task </dev/null` |
| Run a task of the project | `hopen --task test`. In a Herdr pane, the task opens a new pane. Outside Herdr, it runs in the current terminal. |
| See which programs listen on a TCP port, and their projects | `hopen --ports` |

These commands are for the person, in their own terminal. They open a menu or an editor, so do not run them yourself:

| Command | What it does |
|---------|--------------|
| `hopen --quick-open` | Like Quick Open of VS Code. In Herdr, `Cmd+P` (Mac) or `Ctrl+B`, then `F` (Linux) opens it. The chosen file opens in the focused Neovim or shell first. Else it opens in the Neovim pane of the tab, or in a new split on the right. The focus moves to the file. In Neovim, `Ctrl+Q` closes the file. With no other file open, `Ctrl+Q` closes Neovim. |
| `ff`, or `hopen --find` | Choose a file with fzf, and open it in the editor. |
| `fif TEXT`, or `hopen --grep TEXT` | Search the files, and open a result at its line. From the palette in Herdr, the result opens like quick open. |
| `hopen --find --with-ignored FOLDER`, or `hopen --grep TEXT --with-ignored FOLDER` | Search only FOLDER, with the files that `.gitignore` names, but not `node_modules`, `.venv`, and other folders of dependencies. The palette action "Files: Choose folders, and search them with the ignored files" does the same. |
| `hopen --palette` | A menu of every action, in groups like the command palette of VS Code. The groups are projects, tasks, files, git, agents and their Herdr integrations, layout, tabs, sessions, ports, herdspace, Herdr, and help. In Herdr, `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Linux) opens it. Each action shows its key or its command at the right. In place of Enter, `Ctrl+V` opens a program on the right, `Ctrl+S` below, and `Ctrl+T` in a new tab. A person runs it. An agent uses the commands of each action. |

`ff` and `fif` load only in an interactive zsh. A person who comes from VS Code can read the VS Code guide: `https://github.com/MussaCharles/herdspace/blob/main/docs/vscode.md`. The keys and commands for each task are in the documentation index: `https://github.com/MussaCharles/herdspace/blob/main/docs/README.md`.

When you run `hopen` yourself, add `--no-attach`. You cannot use the session. Tell the person to attach in their own terminal:

```bash
hopen my-projects
```

`hopen` is safe to run again. It starts a stopped session, adds only the folders that have no workspace, and closes nothing.

## Add a project to a list

1. Find the list file with `hopen --list`. A list is at `~/<name>/herdspace.toml`, or, as a VS Code workspace file, at `~/<name>.code-workspace` or `~/<name>/<name>.code-workspace`.
2. Before you change the file, ask the person.
3. In a `herdspace.toml` list, add a `[[project]]` table with `name` and `path`. In a VS Code workspace file, add one entry to `folders`, for example `{ "name": "api", "path": "./code/api" }`. A path is relative to the folder of the list file. Keep the comments and the other entries. The settings for a start command, environment values, and extra tabs are in the hopen guide: `https://github.com/MussaCharles/herdspace/blob/main/docs/hopen.md`.
4. Run `hopen <name> --no-attach`. It adds a workspace only for the new folder.

## Split a tab with a template

`hopen --apply grid` splits the current tab with the `grid` template. It works only inside Herdr, in a tab that has only one pane. The templates are in `~/.config/hopen/templates`. Each line of a template file is one pane: `NAME FROM DIRECTION SIZE COMMAND`.

## Agents and their Herdr integrations

herdspace never installs or updates an agent program. The person installs each agent. The server setup adds the Herdr integration and the Herdr skill for each agent that it finds. To find an agent, the setup looks for a command of the agent on the `PATH`, for example `claude`, `codex`, or `cursor-agent`. The folder where the agent keeps its files must exist too. The agent makes that folder at its first start. Herdr supports 18 integrations. Gemini CLI has none: Herdr shows its state from the screen only.

| The person wants to | Run |
|---------------------|-----|
| See the integrations | `herdr integration status` |
| Add the integration of one agent | `herdr integration install NAME`, for example `herdr integration install codex`. Ask the person first, because it changes the files of the agent. |
| Add the integrations of all agents found | Run the server setup again, as in the next section. |

The list of agents, commands, and folders is in `https://github.com/MussaCharles/herdspace/blob/main/docs/agents.md#agent-programs-and-integrations`.

## Check or update the setup

The client setup prepares the machine that the person uses: Ghostty, its keys, and the shell. It installs no Herdr there. `--server NAME` of the client setup tests the SSH connection, and copies the terminal description of Ghostty to the server. The server setup installs Herdr, `hopen`, and Neovim, and it runs on the server itself. The herdspace Neovim shows no warnings and no spell marks, because the person reads the files. `Space`, `u`, `d` shows the warnings. `herdspace editor normal` keeps the LazyVim defaults in each new Neovim. With an own `~/.config/nvim`, the server setup asks once at a terminal: keep it (the answer stays saved), use the herdspace editor (the folder goes to a backup), or show the difference.

On a server machine, a client machine, or one machine as both, `--check` reports what is done and what is missing. It changes nothing in the setup. From `curl`, it only downloads the release files first. If an item is not done, it exits with status 1:

```bash
curl -fsSL https://github.com/MussaCharles/herdspace/releases/latest/download/bootstrap.sh | bash -s -- server --check
```

Use `client --server <name>` or `both` in place of `server`, for the role of the machine. If the person does not want the editor keys of herdspace, add `--keep-terminal-keys` to a client or `both` run. The setup saves the choice. Show the person the output of `--check` first, and ask before an update.

To update a machine that has herdspace 0.8.0 or later, run `herdspace update`. It runs the setup of the latest release with the role and the options of the last setup. Add an option after `update` for one run, for example `herdspace update --keep-existing`. If the latest release is already installed, it changes nothing. To run the setup again anyway, add `--force`. To go back to an older release after a bad update, run `herdspace update --version <tag>`, for example `herdspace update --version 0.9.0`. The tag has no `v` in front. Tell the person that the setup leaves out each saved option that the older release does not know. To see the installed and the latest version, run `herdspace --version`. On an older version, run the `curl` command above with no `--check`.

To remove herdspace, run `herdspace uninstall --check` first. It lists what the uninstall changes, and it changes nothing. Then run `herdspace uninstall`. It asks once. With no terminal, add `--yes`, and only after the person asks for the uninstall. It removes the files that the setup wrote and no person changed, and the marked blocks of herdspace. It never removes a project, a Herdr session, Herdr, or a package.

To update only `hopen`:

```bash
curl -fsSL https://github.com/MussaCharles/herdspace/releases/latest/download/install.sh | bash
```

## Rules

- Do not stop the Herdr server, and do not close a workspace, a tab, or a pane of the person.
- Before you change a list file or a template, ask the person.
- A list can run commands and set environment values. With no terminal, `hopen` uses them only with `--trust`. Show the person the entries of the list that run commands or set values. In a `herdspace.toml` list, they are `on_open`, `tabs`, `tasks`, `env`, and `env_file`. In a VS Code workspace file, they are `hopen.onOpen`, `hopen.tabs`, `hopen.tasks`, `hopen.env`, and `hopen.envFile`. Add `--trust` only after the person agrees. Do not print the values of an env file, because they can be secrets.
- If a command asks for a password, stop. Give the command to the person to run in their own terminal.
- Do not print the contents of `~/.ssh` or of another secret file.
