# herdr-bootstrap

Shell scripts that set up [Herdr](https://herdr.dev), a terminal multiplexer for coding agents, on a new computer. A terminal multiplexer keeps your terminals running on a server after you disconnect.

You run one script on each computer. You can run a script again at any time.

| Computer | Script |
|----------|--------|
| The Mac that you use for SSH | `bootstrap-client-macos.sh` |
| A Debian or Ubuntu server | `bootstrap-server-linux.sh` |
| A macOS server | `bootstrap-server-macos.sh` |

## Quick start

On the server, clone this repository and run the script for its system:

```bash
git clone <repository-url> ~/herdr-bootstrap
```

```bash
cd ~/herdr-bootstrap && ./bootstrap-server-linux.sh
```

On your Mac, clone the repository and give the name of each server:

```bash
cd ~/herdr-bootstrap && ./bootstrap-client-macos.sh --server my-server
```

The full steps are in [docs/setup.md](docs/setup.md). The keys and commands for daily use are in [docs/cheat-sheet.md](docs/cheat-sheet.md).

## What you get

| Part | Client | Server |
|------|:------:|:------:|
| Ghostty with keys that reach Herdr | yes | |
| Terminal description for Ghostty on each server | yes | |
| Free `Ctrl` arrow keys in macOS | yes | |
| zsh, Oh My Zsh, Powerlevel10k, with a different color on each side | yes | yes |
| fzf, zoxide, eza, bat, fd | yes | yes |
| Herdr, with keys, colors, and sidebar | | yes |
| Auto Title plugin | | yes |
| Agent skill and integration for each agent program that it finds | | yes |
| Neovim with a file tree, and lazygit with delta | | yes |
| `hopen`, which opens all the projects of a list | | yes |
| A login service that starts Herdr, and a check for new versions | | yes |

The scripts do not install the agent programs. Install them first, or run the server script again after you install one.

## Ask an agent to do the setup

The folder [skills](skills/) has instructions for coding agents. [docs/agent-setup.md](docs/agent-setup.md) shows what to say to an agent.

## Rules that the scripts follow

- A script makes a backup before it replaces a file.
- A script never stops a Herdr server that was already running, because a stop closes every pane.
- Tools from release pages have a pinned version and a checksum. See [docs/updating.md](docs/updating.md).
- Herdr and Neovim do not contact their sites in the background. The update check asks the Homebrew API.

## Tests

`tests/run-linux.sh` runs a full server setup in throwaway containers. `tests/run-macos.sh` tests the macOS scripts on a Mac, with a temporary home folder and stub commands. A container cannot run macOS, so that test does not change the system settings or install Homebrew packages.

## Credits

The idea for this layout of keys, colors, and tools comes from the guide [Herdr setup](https://learn.datalumina.com/docs/herdr) by Dave Ebbelaar. The configuration files in this repository are new files, and they are not copies of the files in that guide.

The Auto Title plugin is [kryptamine/herdr-auto-title](https://github.com/kryptamine/herdr-auto-title).
