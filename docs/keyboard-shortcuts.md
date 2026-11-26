# Keyboard shortcuts

Scope: the keys that the client setup changes, what each key does with herdspace, and how to keep the keys of your terminal.

By default, the client setup changes some keys of Ghostty and macOS. With the change, Herdr and Neovim use the keys of a code editor, for example `Cmd+T` for a new tab. The setup for one machine as both makes the same change.

## The keys that change

| Mac | Linux | Before, in Ghostty or macOS | With herdspace |
|-----|-------|-----------------------------|----------------|
| `Cmd+T` | `Ctrl+Shift+T` | Ghostty: a new Ghostty tab | Herdr: a new tab |
| `Cmd+W` | `Ctrl+Shift+W` | Ghostty: close the terminal | Herdr: close the tab |
| `Cmd+K` | `Ctrl+Shift+K` | Ghostty, on a Mac: clear the screen | Herdr: go to any workspace, tab, or agent |
| `Cmd+E` | `Ctrl+Shift+E` | Ghostty: search for the selected text on a Mac, or split down on Linux | Neovim: go to the file tree. On a Mac, Ghostty still searches when you select text in Ghostty. |
| `Cmd+Shift+G` | `Ctrl+Shift+G` | Ghostty, on a Mac: go to the previous search result | Herdr: open lazygit over the pane. On a Mac, Ghostty still uses it while its search is open. |
| `Cmd+P` | | Ghostty: nothing | Herdr: quick open, a file in the editor of the tab. On Linux, use `Ctrl+B`, then `F`, because `Ctrl+P` stays with the shell and Neovim. |
| `Cmd+Shift+P` | `Ctrl+Shift+P` | Ghostty: the command palette of Ghostty | Herdr: the command palette of `hopen` |
| | `Ctrl+Shift+F` | Ghostty: search | Neovim: search the project |
| `Option` | | macOS: type special characters, for example `å` | Sends `Alt`, for the `Alt` keys of Herdr and Neovim |
| `Ctrl+Left`, `Ctrl+Right` | | macOS: move one Mission Control space to the left or right | Herdr: the previous or next tab |
| `Ctrl+Up`, `Ctrl+Down` | | macOS: Mission Control and the windows of the app | Herdr: the previous or next workspace |

On Linux, the `Ctrl` arrow keys reach Herdr with no change. Herdr also uses `Alt+Up` and `Alt+Down` to move between panes.

Ghostty cannot limit a key to one program. In a Ghostty window with no Herdr, the `Cmd` keys of Herdr do nothing. Use the replacement keys there.

## Replacement keys for Ghostty

The herdspace keys give each Ghostty action that loses its key a replacement key. Herdr and Neovim do not use these keys.

| Ghostty action | Mac | Linux |
|----------------|-----|-------|
| A new tab | `Cmd+Option+T` | `Ctrl+Alt+Shift+T` |
| Close the tab | `Cmd+Option+W` (a default key of Ghostty) | `Ctrl+Alt+Shift+W` closes the split or the tab |
| Clear the screen | `Cmd+Option+K` | |
| The command palette of Ghostty | `Cmd+Option+Shift+P` | `Ctrl+Alt+Shift+P` |
| Search | `Cmd+F` (no change) | `Ctrl+Alt+Shift+F` |
| Split down | | `Ctrl+Alt+Shift+E` |

To close one split on a Mac, type `exit` in it.

## The question about the keys

The first client run asks which keys to use, before it changes any key. It shows each key that Herdr gets, the replacement keys, and that `Option` sends `Alt`. With no terminal, the setup uses the herdspace keys, and it prints the same text. A later run keeps the choice and does not ask again.

## Your Ghostty file

herdspace never replaces `~/.config/ghostty/config.ghostty`. It writes three marked blocks at the top of the file:

| Block | What it holds | To leave it out |
|-------|---------------|-----------------|
| `herdspace appearance` | The background, the opacity, the window size, and on a Mac the blur and the tab title bar | `--keep-terminal-look` |
| `herdspace keys` | The keys of the table above, the replacement keys, and on a Mac, `Option` as `Alt` | `--keep-terminal-keys` |
| `herdspace ssh` | `shell-integration-features = ssh-env`, for a [server without herdspace](ssh.md#a-server-without-herdspace) | Put your own `shell-integration-features` line below the blocks |

Put your own lines below the blocks. Ghostty uses the last value of each setting, so your value wins over the herdspace value. For example, a `window-position-x` line of yours stays, and your own `background` replaces the herdspace one. The file of an older herdspace gets this layout after a backup, and its own lines stay below the blocks.

After a change of `background-opacity` or `macos-titlebar-style`, quit Ghostty and start it again. A new window does not load these two settings.

## Every Herdr action has a prefix key too

The prefix key of Herdr is `Ctrl+B`. Press it, release it, and then press the key of the action. These keys work with no change to the terminal:

| Action | Prefix key |
|--------|-----------|
| New tab | `Ctrl+B`, then `C` |
| Close the tab | `Ctrl+B`, then `Shift+X` |
| Go to any workspace, tab, or agent | `Ctrl+B`, then `G` |
| Previous or next tab | `Ctrl+B`, then `P` or `N` |
| Next or previous pane | `Ctrl+B`, then `Tab` or `Shift+Tab` |
| lazygit | `Ctrl+B`, then `D` |
| The command palette of `hopen` | `Ctrl+B`, then `A` |
| Quick open a file | `Ctrl+B`, then `F` |

The [cheat sheet](cheat-sheet.md) has every key for daily use. The [keyboard docs of Herdr](https://herdr.dev/tui/docs/keyboard/) list every key of Herdr, and explain the prefix key.

## Move in the lists

The Goto picker of Herdr and the lists of herdspace use different keys. See [Move in the lists](navigation.md#move-in-the-lists).

## Keep the keys of your terminal

To keep the keys of Ghostty and macOS, add `--keep-terminal-keys` to the client setup:

```bash
curl -fsSL https://github.com/MussaCharles/herdspace/releases/latest/download/bootstrap.sh | bash -s -- client --server my-server --keep-terminal-keys
```

The option works with `both` too. With it, the setup does these things:

- It removes the `herdspace keys` block from your Ghostty file, so Ghostty uses its default keys again.
- On a Mac, `Option` types special characters again.
- On a Mac, if the setup took the `Ctrl` arrow keys before, they go back to Mission Control.

The setup saves the choice in `~/.config/herdspace/keys`. A later run keeps the choice, so you do not need to add the option again.

To use the herdspace keys again, add `--use-herdspace-keys`:

```bash
curl -fsSL https://github.com/MussaCharles/herdspace/releases/latest/download/bootstrap.sh | bash -s -- client --server my-server --use-herdspace-keys
```

## Switch the keys later

Run these commands on the client, the machine where Ghostty runs:

| Command | Effect |
|---------|--------|
| `herdspace keys` | Show the current keys. |
| `herdspace keys normal` | Give the keys back to Ghostty, as `--keep-terminal-keys` does. |
| `herdspace keys herdr` | Send the keys to Herdr again, as `--use-herdspace-keys` does. |

The command runs the setup of the installed version again with the option, and it saves the choice for later updates. Then quit Ghostty and start it again, so that the keys load.

Ghostty cannot change a key only while a program runs. For that reason, the keys cannot switch by themselves when you open or leave Herdr. See [the Ghostty discussion](https://github.com/ghostty-org/ghostty/discussions/9902).

To keep only the Mission Control shortcuts on a Mac, and change the other keys, add `--skip-mission-control` in place of `--keep-terminal-keys`.

## Windows

WSL uses Windows Terminal, not Ghostty. The [Windows with WSL guide](windows-wsl.md) has the steps for its keys.

## References

- [Herdr keyboard](https://herdr.dev/tui/docs/keyboard/): the prefix key, every default key, and the Goto picker.
- [The `config.toml` reference of Herdr](https://herdr.dev/tui/docs/config-reference/): each key that `config.toml` can set.
- [fzf](https://github.com/junegunn/fzf): the keys of the herdspace lists.
