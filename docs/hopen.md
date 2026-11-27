# hopen

Scope: open your projects in Herdr with `hopen`, and install, update, or remove it.

`hopen` reads a list of projects and opens each project as a Herdr workspace in one named session. A list is a `herdspace.toml` file. If you come from VS Code, `hopen` also reads a VS Code workspace file. See [Use a VS Code workspace file](#use-a-vs-code-workspace-file), and the [From VS Code](vscode.md) guide. The server setup installs `hopen`. The [templates guide](templates.md) explains how to split each project into named panes.

## Write a list

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {
  'fontFamily': 'Menlo, Consolas, Courier New, monospace', 'fontSize': '14px',
  'primaryColor': '#0d1117', 'primaryTextColor': '#e6edf3', 'primaryBorderColor': '#3fb950',
  'textColor': '#e6edf3', 'lineColor': '#58a6ff', 'secondaryColor': '#161b22', 'tertiaryColor': '#0d1117',
  'edgeLabelBackground': '#0b0f14', 'clusterBkg': '#0b0f14', 'clusterBorder': '#30363d', 'titleColor': '#d2a8ff',
  'actorBkg': '#0d1f12', 'actorBorder': '#3fb950', 'actorTextColor': '#7ee787', 'actorLineColor': '#30363d',
  'signalColor': '#58a6ff', 'signalTextColor': '#e6edf3', 'sequenceNumberColor': '#0b0f14'
}, 'flowchart': {'curve': 'basis', 'nodeSpacing': 34, 'rankSpacing': 42, 'wrappingWidth': 340}}}%%
flowchart LR
  classDef cmd fill:#0d1f12,stroke:#3fb950,stroke-width:2px,color:#7ee787
  classDef step fill:#0d1117,stroke:#58a6ff,stroke-width:1.5px,color:#c9e1ff
  classDef ask fill:#2a2000,stroke:#e3b341,stroke-width:2px,color:#f2cc60
  classDef host fill:#1a0f24,stroke:#bc8cff,stroke-width:2px,color:#d2a8ff
  classDef data fill:#082028,stroke:#39c5cf,stroke-width:1.5px,color:#a5f3fc
  classDef stop fill:#2a0f12,stroke:#ff7b72,stroke-width:2px,color:#ffa198
  file["~/my-projects/herdspace.toml"]:::data --> hopen["hopen my-projects"]:::cmd
  hopen --> session["Herdr session<br/>my-projects"]:::host
  session --> root["Workspace: my-projects<br/>the folder of the list"]:::data
  session --> w1["Workspace: website"]:::data
  session --> w2["Workspace: api"]:::data
```

A list is a file that you write yourself. It names the projects of one Herdr session, and `hopen` opens each project as a workspace. The setup does not create a list. Create the folder of the session, and in it the file `herdspace.toml`:

```bash
mkdir -p ~/my-projects
```

Then write `~/my-projects/herdspace.toml`:

```toml
[[project]]
name = "website"
path = "~/code/website"

[[project]]
name = "api"
path = "~/code/api"
```

Open it:

```bash
hopen my-projects
```

The name of the folder, `my-projects`, is the name of the session. The first workspace has the name of the session and opens the folder of the list. Run `hopen` again after you add a project. It adds only the new projects.

To choose a list from a menu, run `hopen` with no name. It uses [fzf](https://github.com/junegunn/fzf) if it is installed, and the server setup installs it. With no fzf, or in a terminal with no `TERM`, `hopen` shows a numbered menu. Type a number or a name.

To open every list at once, run this command:

```bash
hopen --all
```

`hopen --all` starts one session for each list, and it adds the missing workspaces. A terminal can attach to one session at a time, so add a name to attach to that session:

```bash
hopen --all my-projects
```

`hopen` finds a list at `~/<name>/herdspace.toml`. A `herdspace.toml` file is in [TOML](https://toml.io), the format of the Herdr configuration. It needs Python 3.11 or later. The server setup installs it on a Mac, and on Debian or Ubuntu when the system has a `python3.11` package. To install it yourself, see [Python for herdspace.toml](#python-for-herdspacetoml).

![Herdr with one workspace for each project](media/herdr-sessions.png)

## Open one folder

To open one folder with no list, as `code .` does in VS Code, run this command in the folder:

```bash
hopen .
```

`hopen` opens the folder as one workspace, in a session with the name of the folder. A path also works, for example `hopen ~/code/api`. A path must have a `/`, or `hopen` reads it as the name of a list. If the folder has a `herdspace.toml` file or a `<folder>.code-workspace` file, `hopen` opens that list. `hopen` asks before it uses the commands and values of that list, as for each list. If the list names a session that another list has, `hopen` stops. In a session name, each character that is not a letter, a number, `.`, `-`, or `_` becomes `-`.

## Commands

| Command | Effect |
|---------|--------|
| `hopen my-projects` | Open the projects of one list, and attach to that session. |
| `hopen` | Choose a list from a menu. |
| `hopen .` | Open the current folder, with no list. See [Open one folder](#open-one-folder). |
| `hopen my-projects --file <path>` | Read the list from another file. |
| `hopen my-projects --no-attach` | Open the projects, but do not attach. |
| `hopen my-projects --template code` | Split each new project with a template. A project that has a workspace already does not change. To split it, run `hopen --apply code` in its tab in Herdr. |
| `hopen my-projects --trust` | Use the commands and values of the list with no question. See [Commands and values from a list](#commands-and-values-from-a-list). |
| `hopen --all` | Open every list. |
| `hopen --list` | Show every list and its state. |
| `hopen --templates` | Show every template. |
| `hopen --apply grid` | Split the current tab with a template. |
| `hopen --convert my-projects` | Write `~/my-projects/herdspace.toml` from the VS Code workspace file `my-projects`. It never replaces a file. |
| `hopen --completion zsh` | Print the shell completion script for zsh or bash. See [Shell completion](#shell-completion). |
| `hopen --task test` | Run the task `test` of the project of the current folder. With no name, choose a task from a menu. See [Tasks](#tasks). |
| `hopen --find` | Choose a file of the current folder with fzf, and open it in the editor. The shell command `ff` does the same. |
| `hopen --grep TEXT` | Search the files of the current folder for TEXT, choose a result, and open the file at that line. The shell command `fif TEXT` does the same. |
| `--with-ignored FOLDER` | With `--find`, `--quick-open`, or `--grep`: search only FOLDER, with the files that `.gitignore` names. Repeat it for more folders. See [Search the ignored files](files.md#search-the-ignored-files). |
| `hopen --ports` | Show each TCP port that your programs listen on, with the program and its project, like the Ports view of VS Code. |
| `hopen --palette` | Choose an action from a menu, like the command palette of VS Code. In Herdr, `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Linux) opens it. See [The command palette](#the-command-palette). |
| `hopen --version` | Show the installed release. |

## Settings

All settings are optional. This example opens `website` with the `code` template. It installs the packages one time, sets `PORT`, and adds a tab for the logs:

```toml
# ~/my-projects/herdspace.toml
template = "agent"            # the template for each project with no template

[[project]]
name = "website"
path = "~/code/website"       # or a path relative to this folder
template = "code"
on_open = "npm install"
env = { PORT = "3000" }
env_file = ".env"
tasks = { test = "npm test", dev = "npm run dev" }
tabs = [{ name = "logs", run = "tail -f log/dev.log" }]

[[project]]
name = "api"
path = "~/code/api"
```

| Key | Effect |
|-----|--------|
| `session` | The name of the session, in place of the folder name. |
| `template` | The template for each project that has no template of its own. The default is `plain`. |
| `parent_workspace` | `false` to open no workspace for the folder of the list. The default is `true`. |
| `parent_template`, `on_open`, `env` | At the top of the file: the template, the command, and the values of the parent workspace. |
| `[[project]]` | One project. It needs a `path`. |
| `name` | The name of the workspace. The default is the name of the folder. |
| `template` | In a project: the template of this project. |
| `on_open` | A command. It runs one time, when `hopen` creates the workspace, before the template programs start. |
| `env` | Environment values. Each workspace, tab, and pane that `hopen` creates for the project gets them. |
| `env_file` | A `.env` file with more environment values. A relative path starts at the folder of the project, or of the list at the top. A value in `env` wins over the same name in the file. |
| `tasks` | Named commands that you run when you want, with `hopen --task`. See [Tasks](#tasks). At the top, the tasks of the parent workspace. |
| `tabs` | More tabs. Each tab has a `name`, and an optional `template` and `run` command. |

A `.env` file has one `KEY=VALUE` on each line. `hopen` skips empty lines and lines that start with `#`. It accepts `export ` in front, and quotes around a value. An env file cannot set a name that can make a program run code, for example `PATH`, `LD_PRELOAD`, `NODE_OPTIONS`, or `PROMPT_COMMAND`. Put such a value in `env`. `on_open`, `env`, `env_file`, and `tabs` apply when `hopen` creates a workspace. A workspace that exists does not change. A setting with a wrong value gives a warning, and the other projects still open. `on_open` and `tabs` run commands, and `env` sets values. See [Commands and values from a list](#commands-and-values-from-a-list).

## Tasks

A task is a named command of a project, such as `test` or `dev`, like a task of `tasks.json` in VS Code. Add the tasks to a project:

```toml
[[project]]
name = "website"
path = "~/code/website"
tasks = { test = "npm test", dev = "npm run dev" }
```

In a folder of the project, run a task:

```bash
hopen --task test
```

`hopen` finds the project that holds the current folder. In Herdr, the task runs in a new pane below the current pane, and the pane has the name of the task. Outside Herdr, the task runs in the current terminal. The task gets the environment values of the project, and it runs in the folder where you started it. With no name, `hopen --task` shows a menu of the tasks. Tab completes the task names.

A task is a command from the list, so it needs the same approval as `on_open`. See [Commands and values from a list](#commands-and-values-from-a-list).

## The command palette

The palette is the place to start an action. In Herdr, press `Cmd+Shift+P` on a Mac or `Ctrl+Shift+P` on Linux. `Ctrl+B`, then `A` also works. Outside Herdr, run `hopen --palette`.

Each action has a group and a name, as in VS Code, and the key or command for it at the right, with the direct key first, for example `Cmd+T, Ctrl+B C`. On Linux, a `Cmd` key is `Ctrl+Shift`, except for quick open, which is `Ctrl+B`, then `F`. Type to filter the list, and press Enter to run an action. Esc closes the palette. With no fzf, the palette shows a numbered menu with a heading for each group.

### Quick open

Press `Cmd+P` in Herdr, as in VS Code. On Linux, press `Ctrl+B`, then `F`, because `Ctrl+P` stays with the shell and Neovim. A popup lists the files of the git project of the focused pane, or of its folder, with a preview. Type to filter, and press Enter:

1. If the focused pane runs Neovim, the file opens there.
2. If the focused pane is a shell at its prompt, Neovim opens the file in that pane. When you close Neovim, the shell comes back.
3. If another pane of the tab runs Neovim, the file opens there, and the focus moves to that pane.
4. In all other cases, Neovim opens the file in a split on the right, with the focus on it. When you close Neovim, the split closes, and the focus returns to the old pane.

To close the file, press `Ctrl+Q` in Neovim. With no other file open, `Ctrl+Q` closes Neovim. With unsaved changes, Neovim asks first.

`Ctrl+V`, `Ctrl+S`, and `Ctrl+T` open a new editor on the right, below, or in a new tab. That editor also closes with Neovim. The palette has the same action: "Files: Quick open". Outside Herdr, `hopen --quick-open` opens the file in the editor in the same terminal.

### Choose where a program opens

In Herdr, an action that starts a program can open it beside the current pane. For example, keep an agent on the left, and open lazygit or the editor on the right. Press one of these keys instead of Enter:

| Key | The program opens |
|-----|-------------------|
| Enter | In the usual place of the action |
| `Ctrl+V` | In a split on the right of the current pane |
| `Ctrl+S` | In a split below the current pane |
| `Ctrl+T` | In a new tab |

The keys work for these actions: open this folder in the editor, read a Markdown file, lazygit, find a file, search in the files, run a task, start an agent, and open a worktree. A worktree opens as a shell in its folder. For another action, the keys work as Enter. In the numbered menu, type the place after the name or the number, for example `edit right`, `3 down`, or `git tab`.

The palette shows only the actions that fit the place. For example, the Git actions show only in a git folder, and the Layout actions only in Herdr.

| Group | Actions |
|-------|---------|
| Recently used | The last 5 actions that you ran. |
| Projects | Open a list. Open this folder in Herdr. Open this folder as its own workspace. Open this session in a new window. Open every list. Show every list. Write a `herdspace.toml` from a VS Code list. |
| Tasks | Run a task of the project of the current folder. |
| Files | Quick open, in Herdr. Find a file (`ff`), outside Herdr. Search in the files (`fif`): in Herdr, the result opens like quick open, at its line. Open this folder in the editor. Read a Markdown file, rendered. Choose folders, and search them with the ignored files. |
| Git | lazygit over the pane, or in a new tab. A new worktree for an agent, on a new branch. Open, show, or remove a worktree. |
| Agents | Go to an agent: the blocked and done agents come first. Explain the state of an agent. Start an agent program in a new pane. Show the Herdr integrations, add one for an agent, or remove one. |
| Layout | Split the tab with a template. Split right or down. Zoom the pane. Show every template. |
| Workspace and tabs | A new tab or workspace. Rename the workspace, the tab, or the pane. Close the tab. |
| Sessions | Show the sessions. Stop a session. |
| Network | Show the ports that your programs listen on. |
| herdspace | Show the version. Update herdspace. Change the Ghostty keys, on a client. Change the editor mode (reader or normal), on a server. |
| Herdr | Check for a new Herdr version. Reload the Herdr configuration. Show the state of the server. |
| Help | Show the keys. Show the links to the cheat sheet and the docs. |

An action that closes or stops something asks first, and the default answer is no. The palette keeps the names of the last actions in `~/.cache/herdspace/palette-recent`. It keeps no paths, and no text that you typed.

### Two monitors

One Herdr session can show in two windows, for example an agent on one monitor and lazygit on the other. Choose "Projects: Open this session in a new window" in the palette. It prints the command to run in the second window. Each window keeps its own workspace and tab. Both windows show the same panes in the same folder, so no copy of the project exists.

Herdr has open issues about two windows on one session. Until they are fixed, keep the two windows on different tabs while an agent runs:

- A second window can stall on the tab of a running Claude Code: [herdr#5749](https://github.com/herdrdev/herdr/issues/5749).
- After a reconnect, a window can come back on the workspace of the other window: [herdr#5508](https://github.com/herdrdev/herdr/issues/5508).

A workspace takes its name from the folder of its first pane, so an agent that you start in another folder shows that first name in the sidebar ([herdr#5628](https://github.com/herdrdev/herdr/issues/5628)). To see each agent under its own folder, choose "Projects: Open this folder as its own workspace".

## Use a VS Code workspace file

If you use VS Code, you can keep one list for VS Code and Herdr. `hopen` reads a VS Code workspace file at `~/<name>.code-workspace` or at `~/<name>/<name>.code-workspace`. Each folder of the file becomes a workspace. The settings go in the `settings` block, and VS Code ignores them:

```json
{
  "folders": [
    { "name": "website", "path": "./code/website" },
    { "name": "api", "path": "./code/api" }
  ],
  "settings": {
    "hopen.template": "agent",
    "hopen.templates": { "website": "code" },
    "hopen.onOpen": { "website": "npm install" },
    "hopen.env": { "website": { "PORT": "3000" } },
    "hopen.tasks": { "website": { "test": "npm test" } },
    "hopen.tabs": { "website": [ { "name": "logs", "run": "tail -f log/dev.log" } ] }
  }
}
```

| VS Code setting | `herdspace.toml` key |
|-----------------|----------------------|
| `hopen.session` | `session` |
| `hopen.template` | `template`, at the top |
| `hopen.templates` | `template`, in a project |
| `hopen.parentWorkspace` | `parent_workspace` |
| `hopen.onOpen` | `on_open` |
| `hopen.env` | `env` |
| `hopen.envFile` | `env_file` |
| `hopen.tasks` | `tasks` |
| `hopen.tabs` | `tabs` |

A setting for one folder uses the name of the folder. A setting for the parent workspace uses the name of the session. A VS Code workspace file also works with a Python 3 that is older than 3.11.

A workspace file in another place, or with a name that is not the name of its folder, opens with its path:

```bash
hopen project-name.code-workspace
```

`hopen .` also uses the workspace file of the current folder, if the folder has only one. With more than one, give the file name.

To change to a `herdspace.toml` list, run this command. `hopen` then uses the new file, and it prints a warning about the old one until you remove it:

```bash
hopen --convert my-projects
```

## Commands and values from a list

A list file can come from another person, for example in a repository that you clone. For that reason, `hopen` asks before it uses the commands and environment values of a list:

1. The first time, `hopen` shows each command and value, and asks "Use them?". The default answer is no. For an env file, it shows the file and its values, but it hides a value whose name looks like a secret, for example `API_TOKEN` or `DB_PASSWORD`.
2. If you answer yes, `hopen` saves a checksum of the list file in `~/.local/state/hopen/trusted.tsv`. A later run uses the commands and values with no question.
3. After each change to the list file or to the values of its env files, `hopen` asks again.

With no answer, `hopen` still opens the workspaces, but it runs no command and sets no value from the list. With no terminal, for example in a script, add `--trust` to approve the list.

## Session names

The name of the session comes from the file name, or the folder name for `herdspace.toml`. `hopen.session` and `session` can set another name. A list that only claims a name never takes over a list whose own file or folder has that name. `hopen` skips the claiming list, and it prints a warning. If two lists claim one name and no list has it as its own, `hopen` skips both, and it names them.

## Shell completion

Press Tab after `hopen` to complete a list name, an option, or a template name after `--template` and `--apply`. The server setup turns it on for zsh. After an install of only `hopen`, add one of these lines to your shell startup file.

For zsh, in `~/.zshrc`, after `compinit` or Oh My Zsh:

```bash
source <(hopen --completion zsh)
```

For bash, in `~/.bashrc`:

```bash
source <(hopen --completion bash)
```

## Python for herdspace.toml

`hopen` reads a `herdspace.toml` list with Python 3.11 or later. It uses `python3` if that is new enough, or else the newest of `python3.14`, `python3.13`, `python3.12`, and `python3.11` that it finds. A VS Code workspace file works with an older Python 3.

| System | Command |
|--------|---------|
| macOS | `brew install python` |
| Debian or Ubuntu, with `sudo` | `sudo apt-get install python3.11` |
| Any Linux, for your account only, with no `sudo` | See the steps below. |

On a shared server, you can install Python for your account only with [uv](https://docs.astral.sh/uv/). It writes only to your home folder, and it does not change the `python3` of the system or of other accounts:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
uv python install 3.12
```

uv puts `python3.12` in `~/.local/bin`, which the herdspace shell adds to the `PATH`, and `hopen` finds it. Open a new shell, and run `hopen --list` to make sure that `hopen` reads your list.

A `hopen` of release 0.6.1 or earlier uses only `python3`. For such a release, also make `python3` and `python` in `~/.local/bin` point to the new Python, for your account only. `--default` is an experimental option of uv, see [Python versions](https://docs.astral.sh/uv/concepts/python-versions/) in the uv docs:

```bash
uv python install 3.12 --default
```

## Install only hopen

On a machine that has Herdr already, you can install `hopen` and its templates without the rest of the setup. You need curl and Python 3.11 or later. A VS Code workspace file also works with an older Python 3:

```bash
curl -fsSL https://github.com/MussaCharles/herdspace/releases/latest/download/install.sh | bash
```

`install.sh` copies `hopen` to `~/.local/bin` and the templates to `~/.config/hopen/templates`, after a checksum check.

## Update hopen

Run the install command again. It installs the newest release. `install.sh` keeps a template that you changed, and it writes the new version next to it as `<name>.layout.new`.

## Remove hopen

Run the install command with `--uninstall`. It keeps your templates:

```bash
curl -fsSL https://github.com/MussaCharles/herdspace/releases/latest/download/install.sh | bash -s -- --uninstall
```
