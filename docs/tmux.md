# From tmux

Scope: find the Herdr command or key for each tmux action that you use, and run several coding agents side by side.

Herdr works like tmux. After you leave, a server keeps your programs running, and you come back to them later. The prefix key is `ctrl+b`, as in tmux. The words are different, and a few keys are different. On Linux, use `Ctrl+Shift` in place of `Cmd` for the direct keys.

## Words

| In tmux | In Herdr |
|---------|----------|
| Session | Session. One session for each list of projects. |
| No match | Workspace: one project, with its folder. A session holds workspaces. |
| Window | Tab. A workspace holds tabs. |
| Pane | Pane. A tab holds panes. |

## Keys that are different

Do not press `ctrl+b`, `d` to leave. In herdspace, it opens lazygit. Press `ctrl+b`, `q` to leave.

| In tmux | In Herdr |
|---------|----------|
| Detach: `ctrl+b`, `d` | `ctrl+b`, `q` |
| Split right: `ctrl+b`, `%` | `ctrl+b`, `v` |
| Split down: `ctrl+b`, `"` | `ctrl+b`, `-` |
| Kill the pane: `ctrl+b`, `x` | `ctrl+b`, `x` |
| Kill the window: `ctrl+b`, `&` | `ctrl+b`, `shift+x`, or `Cmd+W` |
| Rename the window: `ctrl+b`, `,` | `ctrl+b`, `shift+t` |
| Choose a session or window: `ctrl+b`, `s` or `w` | `ctrl+b`, `g`, or `Cmd+K`: go to any workspace, tab, or agent |

## Keys that are the same

| Action | Keys in tmux and in Herdr |
|--------|---------------------------|
| New window or tab | `ctrl+b`, `c`. In Herdr, `Cmd+T` also works. |
| Next or previous window or tab | `ctrl+b`, `n` or `p`. In Herdr, `Ctrl+Right` and `Ctrl+Left` also work. |
| Go to window or tab 1 to 9 | `ctrl+b`, `1` to `9` |
| Zoom the pane, or return | `ctrl+b`, `z` |
| Copy mode | `ctrl+b`, `[`. Then `v` to select and `y` to copy, as in tmux with vi keys. |

To move between panes, press `ctrl+b`, then `h`, `j`, `k`, or `l`. `Alt+Up` and `Alt+Down` go to the next and the previous pane.

## Sessions

| In tmux | In Herdr |
|---------|----------|
| `tmux` | `herdr` |
| `tmux new -s my-projects` | `herdr --session my-projects`, or `hopen my-projects` to open the projects of a list |
| `tmux attach -t my-projects` | `herdr session attach my-projects` |
| `tmux ls` | `herdr session list` |
| `tmux kill-session -t my-projects` | `herdr session stop my-projects`. Then `herdr session delete my-projects` to remove it. |
| `tmux kill-server` | `herdr server stop` stops the default session |
| tmux-resurrect | Herdr keeps the layout after a stop. The programs start again as new shells. An agent with an integration resumes its conversation. |

A stop ends every program in the session, as `kill-session` does. To leave and keep everything running, press `ctrl+b`, `q`, or close the terminal window.

## Run agents side by side

With tmux, you can open two terminal windows and resume a Claude Code session in each, so that the two sessions can work together. In Herdr, use two panes of one tab. The panes run on the same machine, so the two sessions can work together in the same way:

1. Press `ctrl+b`, `v` to split the tab into two panes.
2. In each pane, run `claude --resume`, and choose a session.
3. Press `ctrl+b`, then `h` or `l`, to move between the panes. Press `ctrl+b`, `z` to zoom one pane.
4. Run `herdr agent list`. It shows the state of each agent: working, blocked, or idle.

The sidebar marks an agent that waits for you, and an agent that is done. When you leave with `ctrl+b`, `q`, both agents keep running. Run `hopen my-projects` or `herdr` to return to them.

If you prefer two terminal windows, run `herdr --session one` in the first window and `herdr --session two` in the second window. Each window then holds its own session.

An agent can also control other panes through Herdr. To make one agent start another agent, mention Herdr in the prompt. See [Agents in panes](cheat-sheet.md#agents-in-panes) for an example prompt. To keep two agents from changing the same files, give each one its own git worktree. See [One worktree for each agent](cheat-sheet.md#one-worktree-for-each-agent).

## Configuration

| In tmux | In Herdr |
|---------|----------|
| `~/.tmux.conf` | `~/.config/herdr/config.toml`. The setup writes it. |
| `tmux source-file ~/.tmux.conf` | `herdr server reload-config` |
| Plugins with TPM | `herdr plugin list`. The setup installs the Auto Title plugin, which names each tab and pane. |

The [cheat sheet](cheat-sheet.md) has every key and command. The [keyboard shortcuts guide](keyboard-shortcuts.md) lists each key that the setup changes.

## References

- [Herdr documentation](https://herdr.dev/tui/docs/)
- [Herdr keyboard](https://herdr.dev/tui/docs/keyboard/)
- [Herdr CLI reference](https://herdr.dev/tui/docs/cli-reference/)
- [tmux manual page](https://man.openbsd.org/tmux)
