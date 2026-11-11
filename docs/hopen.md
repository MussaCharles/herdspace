# hopen

Scope: open your projects in Herdr with `hopen`, and install, update, or remove it.

`hopen` reads a list of projects and opens each folder as a Herdr workspace in one named session. A list is a VS Code workspace file or a `herdspace.toml` file. The server setup installs it. The [templates guide](templates.md) explains how to split each project into named panes.

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
  file["work.code-workspace"]:::data --> hopen["hopen work"]:::cmd
  hopen --> session["Herdr session<br/>work"]:::host
  session --> root["Workspace: work<br/>the folder of the file"]:::data
  session --> w1["Workspace: website"]:::data
  session --> w2["Workspace: api"]:::data
```

Create `~/work.code-workspace`:

```json
{
  "folders": [
    { "name": "website", "path": "./code/website" },
    { "name": "api", "path": "./code/api" }
  ]
}
```

Open it:

```bash
hopen work
```

The first workspace has the name of the session and opens the folder that holds the file. Run `hopen` again after you add a folder. It adds only the new folders.

To open every list at once, run this command:

```bash
hopen --all
```

`hopen --all` starts one session for each list, and it adds the missing workspaces. A terminal can attach to one session at a time, so add a name to attach to that session:

```bash
hopen --all work
```

`hopen` finds a list at `~/<name>.code-workspace` or at `~/<name>/<name>.code-workspace`.

![Herdr with one workspace for each project](media/herdr-sessions.png)

## Commands

| Command | Effect |
|---------|--------|
| `hopen work` | Open the projects of one list, and attach to that session. |
| `hopen work --file <path>` | Read the list from another file. |
| `hopen work --no-attach` | Open the projects, but do not attach. |
| `hopen work --template code` | Split each new project with a template. |
| `hopen --all` | Open every list. |
| `hopen --list` | Show every list and its state. |
| `hopen --templates` | Show every template. |
| `hopen --apply grid` | Split the current tab with a template. |
| `hopen work --trust` | Use the commands and values of the list with no question. See [Commands and values from a list](#commands-and-values-from-a-list). |
| `hopen --convert work` | Write `~/work/herdspace.toml` from the VS Code list `work`. It never replaces a file. |
| `hopen --version` | Show the installed release. |

## Settings in a VS Code list

All settings are optional. They go in the `settings` block of the VS Code workspace file, and VS Code ignores them. A setting for one folder uses the name of the folder, and the parent workspace uses the name of the session.

| Setting | Effect |
|---------|--------|
| `hopen.session` | The name of the session, in place of the file name. |
| `hopen.template` | The template for each folder that has no template of its own. The default is `plain`. |
| `hopen.templates` | A template for each folder, by name. |
| `hopen.parentWorkspace` | `false` to open no workspace for the folder of the list file. The default is `true`. |
| `hopen.onOpen` | A command for each folder. It runs one time, when `hopen` creates the workspace, before the template programs start. |
| `hopen.env` | Environment values for each folder. Each workspace, tab, and pane that `hopen` creates for the folder gets them. |
| `hopen.tabs` | More tabs for each folder. Each tab has a `name`, and an optional `template` and `run` command. |

This example opens the project `website` with the `code` template. It installs the packages one time, sets `PORT`, and adds a tab for the logs:

```json
{
  "folders": [
    { "name": "website", "path": "./code/website" },
    { "name": "api", "path": "./code/api" }
  ],
  "settings": {
    "hopen.session": "work",
    "hopen.template": "agent",
    "hopen.templates": { "website": "code" },
    "hopen.onOpen": { "website": "npm install" },
    "hopen.env": { "website": { "PORT": "3000" } },
    "hopen.tabs": { "website": [ { "name": "logs", "run": "tail -f log/dev.log" } ] }
  }
}
```

`hopen.onOpen`, `hopen.env`, and `hopen.tabs` apply when `hopen` creates a workspace. A workspace that exists does not change. A setting with a wrong value gives a warning, and the other folders still open.

`hopen.onOpen` and `hopen.tabs` run commands, and `hopen.env` sets values. See [Commands and values from a list](#commands-and-values-from-a-list).

## A herdspace.toml list

A `herdspace.toml` file is the list format of herdspace. It holds the same settings, in [TOML](https://toml.io), the format of the Herdr configuration. Put it in a folder: `~/work/herdspace.toml` is the list of the session `work`.

```toml
# ~/work/herdspace.toml
template = "agent"            # the template for each project with no template
parent_template = "plain"     # the template of the parent workspace
parent_workspace = true

[[project]]
name = "website"
path = "~/code/website"       # or a path relative to this folder
template = "code"
on_open = "npm install"
env = { PORT = "3000" }
tabs = [{ name = "logs", run = "tail -f log/dev.log" }]

[[project]]
name = "api"
path = "~/code/api"
```

| Key | Effect |
|-----|--------|
| `session` | The name of the session, in place of the folder name. |
| `template` | The template for each project with no template of its own. |
| `parent_workspace` | `false` to open no workspace for the folder of the file. |
| `parent_template`, `on_open`, `env` | At the top: the template, the command, and the values of the parent workspace. |
| `[[project]]` | One project. It needs a `path`. `name`, `template`, `on_open`, `env`, and `tabs` are optional. |

A `herdspace.toml` file needs Python 3.11 or later. The Python of the macOS Command Line Tools is older. On a Mac, install a newer Python with `brew install python`. If both a `herdspace.toml` and a VS Code list name one session, `hopen` uses `herdspace.toml`, and it prints a warning.

To make a `herdspace.toml` from a VS Code list, run:

```bash
hopen --convert work
```

## Commands and values from a list

A list file can come from another person, for example in a repository that you clone. For that reason, `hopen` asks before it uses the commands and environment values of a list:

1. The first time, `hopen` shows each command and value, and asks "Use them?". The default answer is no.
2. If you answer yes, `hopen` saves a checksum of the list file in `~/.local/state/hopen/trusted.tsv`. A later run uses the commands and values with no question.
3. After each change to the list file, `hopen` asks again.

With no answer, `hopen` still opens the workspaces, but it runs no command and sets no value from the list. With no terminal, for example in a script, add `--trust` to approve the list.

## Session names

The name of the session comes from the file name, or the folder name for `herdspace.toml`. `hopen.session` and `session` can set another name. A list that only claims a name never takes over a list whose own file or folder has that name. `hopen` skips the claiming list, and it prints a warning. If two lists claim one name and no list has it as its own, `hopen` skips both, and it names them.

## Install only hopen

On a machine that has Herdr already, you can install `hopen` and its templates without the rest of the setup. You need Python 3 and curl:

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
