# From VS Code

Scope: find the herdspace command or key for each VS Code action that you use.

herdspace is terminal first. Herdr holds the terminals, `hopen` opens your projects, and Neovim shows the code. Most VS Code actions have a match. This table lists them. On Linux, use `Ctrl+Shift` in place of `Cmd+Shift`.

## Projects and files

| In VS Code | In herdspace |
|------------|--------------|
| A multi-root workspace file | A `herdspace.toml` list, opened with `hopen work`. `hopen` also reads your `.code-workspace` file. See the [hopen guide](hopen.md). |
| Open a folder (`code .`) | `hopen .` |
| Recent workspaces | `hopen` with no name shows a menu of your lists. `z` and `zi` jump to the folders that you used. |
| Quick Open (`Cmd+P`) | `ff` in the shell, or `Ctrl+P` in Neovim |
| Search in files (`Cmd+Shift+F`) | `fif TEXT` in the shell, or `Ctrl+Shift+F` or `/` in Neovim |
| The Explorer | The file tree of Neovim. `Cmd+E` focuses it. |
| The command palette (`Cmd+Shift+P`) | `Cmd+Shift+P` in Herdr opens the palette of `hopen`. See [The command palette](hopen.md#the-command-palette). |

## Run and test

| In VS Code | In herdspace |
|------------|--------------|
| Tasks (`tasks.json`) | `tasks` in a list, run with `hopen --task test`. See [Tasks](hopen.md#tasks). |
| A task that runs at the start | `on_open` in a list |
| Environment values and a `.env` file | `env` and `env_file` in a list |
| The terminal panel | Herdr panes. The [cheat sheet](cheat-sheet.md#panes) has the keys to split a pane. |
| The Ports view | `hopen --ports` |

## Git and agents

| In VS Code | In herdspace |
|------------|--------------|
| Source Control | lazygit. `Cmd+Shift+G` opens it over the pane. |
| Review the changes of an agent | The `review` template: lazygit and Neovim side by side. Run `hopen --apply review` in a new tab. |
| A branch for each task | A git worktree for each agent. See [One worktree for each agent](cheat-sheet.md#one-worktree-for-each-agent). |
| Notifications | The sidebar of Herdr marks each agent that waits for you, and each agent that is done. |

## Neovim for VS Code users

Neovim has modes. You start in Normal mode, where keys move and run commands. Press `i` to type text, and `Esc` to return to Normal mode. The [cheat sheet](cheat-sheet.md#neovim) has the keys that herdspace adds, such as `Ctrl+P` and the file tree.

| In VS Code | In Neovim (Normal mode) |
|------------|-------------------------|
| Type text | `i`, then type. `Esc` stops. |
| Save | `:w`, then `Enter` |
| Close the file | `:q`. `:q!` closes and drops the changes. |
| Undo, redo | `u`, `Ctrl+R` |
| Go to a line | `:42`, then `Enter` |
| Go to the start or the end of the file | `gg`, `G` |
| Find in the file | `g`, then `/`, the text, and `Enter`. `n` goes to the next result. |
| Copy and paste a line | `yy`, then `p` |
| Delete a line | `dd` |
| Go to the definition | `gd`, or `Ctrl`-click |
| Show the documentation of a name | `K` |
| Rename a name | `Space`, `c`, `r` |
| Show all the keys | `Space`, then wait |
| Split the window | `:vsplit` or `:split` |
| Move to the next window | `Ctrl+W`, then `W` |

To learn more:

- Run `:Tutor` in Neovim. It is a 30-minute lesson, inside Neovim.
- The [Neovim user manual](https://neovim.io/doc/user/usr_toc.html) and the [quick reference](https://neovim.io/doc/user/quickref.html) are the official guides.
- The [LazyVim keymaps](https://www.lazyvim.org/keymaps) list each key of the Neovim setup that herdspace installs.

## Keys and settings

| In VS Code | In herdspace |
|------------|--------------|
| Keyboard shortcuts | The [keyboard shortcuts guide](keyboard-shortcuts.md), and the [cheat sheet](cheat-sheet.md) |
| Settings | The configuration of Herdr is `~/.config/herdr/config.toml`. The configuration of Neovim is in `~/.config/nvim`. |
| Settings Sync | Run the setup on each machine. It writes the same configuration on each machine. |
