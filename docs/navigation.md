# Move around

[Documentation index](README.md) · [Cheat sheet](cheat-sheet.md) · [Words](cheat-sheet.md#words)

Scope: workspaces, tabs, the focus between panes, the Goto picker and the keys of the lists, folder jumps, and the mouse.

## Workspaces

Use one workspace for each project.

| Action | Keys |
|--------|------|
| New workspace | `ctrl+space`, `shift+n` |
| Rename workspace | `ctrl+space`, `shift+w` |
| Close workspace (Herdr asks first) | `ctrl+space`, `shift+d` |
| Open the workspace list | `ctrl+space`, `w` |
| Go to any workspace, tab, or agent | `ctrl+space`, `g` |
| Show or hide the sidebar | `ctrl+space`, `b` |

In the `ctrl+space`, `g` list, type `/` to search and press `Enter` to go. Press `b`, `w`, `i`, or `d` to show only blocked, working, idle, or done agents. Press `a` to show all. Press `Esc` to leave.

## Tabs

| Action | Keys |
|--------|------|
| New tab | `ctrl+space`, `c` |
| Next or previous tab | `ctrl+space`, `n` or `p` |
| Go to tab 1 to 9 | `ctrl+space`, `1` to `9` |
| Rename tab | `ctrl+space`, `shift+t` |
| Close tab | `ctrl+space`, `shift+x` |

The Auto Title plugin names each tab. A name that you set by hand stays.

## Move between panes

| Action | Keys |
|--------|------|
| Go to the pane on the left, below, above, or right | `ctrl+space`, `h`, `j`, `k`, `l` |
| Next or previous pane | `Alt+Up`, `Alt+Down`, or `ctrl+space`, `tab` or `shift+tab` |
| Go to a pane | Click it |

To move a pane itself to another place in the tab, see [Swap panes](layout.md#swap-panes).

## Move in the lists

The Goto picker of Herdr (`Cmd+K`, or `Ctrl+Shift+K` on Linux) and the lists of herdspace use different keys:

| List | Move down | Move up | Search |
|------|-----------|---------|--------|
| The Goto picker of Herdr | `j` or the down arrow | `k` or the up arrow | Press `/`, then type. While you type, only the arrow keys move. |
| The command palette and quick open of herdspace | `Ctrl+N`, `Ctrl+J`, or the down arrow | `Ctrl+P`, `Ctrl+K`, or the up arrow | Type at once. |

The Goto picker belongs to Herdr, and Herdr has no setting for its keys. In it, `b`, `w`, `i`, and `d` show only the blocked, working, idle, or done agents, and `a` shows all terminals again. The lists of herdspace use fzf, which has the keys of Emacs and of Vim.

## Jump to folders

zoxide knows only the folders that you visited. Use `cd` with the full path the first time.

| Task | Command or key |
|------|----------------|
| Go to the best match | `z project` |
| Choose from a list | `zi` |
| Search the shell history | `Ctrl+R` |
| Insert a file path | `Ctrl+T` |
| Go to a folder from a list | `Alt+C` |
| List files with `eza` | `ls`, `ll`, `tree`. A flag that means something else in `eza`, for example `ls -ltr`, runs the standard `ls` |
| Show a file with `bat` | `cat file` |
| Find a file by name (`hopen --find`) | `ff` |
| Search the files for text (`hopen --grep`) | `fif TEXT` |

## Mouse

| Action | Mouse |
|--------|-------|
| Focus a pane, tab, workspace, or agent | Click it |
| Resize a pane | Drag its border |
| Open a menu | Right-click |
| Scroll | Mouse wheel |
| Open a link | `Ctrl`-click |

## References

- [Herdr documentation](https://herdr.dev/tui/docs/)
- [Herdr keyboard](https://herdr.dev/tui/docs/keyboard/)
- [Herdr CLI reference](https://herdr.dev/tui/docs/cli-reference/)
