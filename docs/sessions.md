# Sessions

[Documentation index](README.md) · [Cheat sheet](cheat-sheet.md) · [Words](cheat-sheet.md#words)

Scope: open all projects, start, leave, and return to a session, and stop and delete it.

## Open all projects at once

A list is like a Herdr session, and each project in the list is like a Herdr workspace. The list of the session `my-projects` is `~/my-projects/herdspace.toml`.

| Task | Command |
|------|---------|
| Open all the projects of a list | `hopen my-projects` |
| Choose a list from a menu | `hopen` |
| Open the current folder, with no list | `hopen .` |
| Open every list | `hopen --all` |
| Open every list, and attach to one session | `hopen --all my-projects` |
| Show every list and its state | `hopen --list` |
| Split each new workspace with a template | `hopen my-projects --template code` |
| Show every template | `hopen --templates` |
| Split the current tab with a template | `hopen --apply grid` |
| Add a project | Add a `[[project]]` to the list file, then run `hopen` again. |
| Run a task of the project, for example `test` | `hopen --task test` |
| Show the open ports of the projects | `hopen --ports` |
| Remove a project | Remove the project from the list file, then close its workspace with `ctrl+b`, `shift+d`. |

The list for a session is `~/<session>/herdspace.toml`. A VS Code workspace file, `~/<session>.code-workspace`, also works. `hopen` also adds a workspace with the name of the session, for the folder that holds the list file. Use it to start an agent at the parent level. `hopen` starts a stopped session, adds only the missing projects, and never closes anything. To use a new session, create a list file with the name of the session.

## Start, leave, and return

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
  none(("start")):::step -- " herdr " --> attached["ATTACHED<br/>You see the panes"]:::cmd
  attached -- " ctrl+b, q<br/>or close the terminal " --> detached["DETACHED<br/>Programs keep running"]:::host
  detached -- " herdr " --> attached
  attached -- " herdr server stop " --> stopped["STOPPED<br/>Programs are gone"]:::stop
  detached -- " herdr server stop " --> stopped
  stopped -- " herdr: only the layout returns " --> attached
```

In the Detached state, your programs keep running. In the Stopped state, your programs are gone, and only the layout returns.

| Task | Command or key |
|------|----------------|
| Start or return to the default session | `herdr` |
| Leave, and keep everything running | `ctrl+b`, `q` |
| Leave by closing the terminal window | Close the window. Everything keeps running. |
| Start or return to a named session | `herdr --session my-projects` |
| Return to a named session | `herdr session attach my-projects` |
| List the sessions | `herdr session list` |
| See the state of the server | `herdr status` |

After a reboot, the login service starts the default session. Run `herdr` to attach. Named sessions stay stopped until you run `hopen`.

## Stop and delete

Do not stop a session to leave it. A stop ends every program in that session. Use `ctrl+b`, `q` to leave.

| Task | Command |
|------|---------|
| Stop the default session | `herdr server stop` |
| Stop a named session | `herdr session stop my-projects` |
| Delete a stopped named session | `herdr session delete my-projects` |
| Start the default session again | `herdr` |

After a stop, the workspaces, tabs, panes, and folders return as new shells. Running programs do not return. An agent with an integration that reports its session resumes its conversation. To see the integrations, run `herdr integration status`.

## References

- [Herdr documentation](https://herdr.dev/tui/docs/)
- [Herdr keyboard](https://herdr.dev/tui/docs/keyboard/)
- [Herdr CLI reference](https://herdr.dev/tui/docs/cli-reference/)
