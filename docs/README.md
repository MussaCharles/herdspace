# Documentation

Scope: each guide of herdspace, in groups. Start with the [README](../README.md) for the install commands.

## Set up

- [Setup guide](setup.md): set up a server and a client, every option, and what the setup installs.
- [Update herdspace](setup.md#update-herdspace): `herdspace update`, `herdspace --version`, and the notice of a new release.
- [Uninstall herdspace](setup.md#uninstall-herdspace): `herdspace uninstall --check` and `herdspace uninstall`.
- Your own files: [your ~/.zshrc](setup.md#your-zshrc), [your Ghostty file](keyboard-shortcuts.md#your-ghostty-file), [your Neovim files](setup.md#your-neovim-files), and [exports from your bash files](setup.md#exports-from-your-bash-files).
- [Connect to the server with SSH](ssh.md): what `my-server` means, and how to set up the SSH name and key.
- [Windows with WSL](windows-wsl.md): use a Windows machine as a client.
- [Ask an agent to do the setup](agent-setup.md): what to say to a coding agent.
- [Agent install steps](../install.md): the steps that a coding agent follows to install herdspace.

## Keys and commands by task

- [Move around](navigation.md): workspaces, tabs, the focus between panes, the Goto picker and the keys of the lists, folder jumps, and the mouse.
- [Panes and layout](layout.md): split, swap, resize, zoom, and close panes, templates, and scroll, search, and copy.
- [Files and the editor](files.md): quick open, find and search, Neovim, and Markdown and images.
- [Git and worktrees](git.md): lazygit, and one worktree for each agent.
- [Sessions](sessions.md): open all projects, start, leave, return, stop, and delete.
- [Agents](agents.md): agents in panes.

## Use

- [hopen guide](hopen.md): write a list, its settings, the commands, and how to install, update, or remove `hopen`.
- [Templates and panes](templates.md): each template, how to add your own, and videos of the pane keys.
- [Keyboard shortcuts](keyboard-shortcuts.md): the keys that the setup changes, and how to keep the keys of your terminal.
- [Cheat sheet](cheat-sheet.md): the daily commands, the words, the direct keys, and the problems, with a [table of the task pages](cheat-sheet.md#by-task) and links to the official Herdr docs.
- [From VS Code](vscode.md): the herdspace command or key for each VS Code action.
- [From tmux](tmux.md): the Herdr command or key for each tmux action, and how to run agents side by side.

## Change herdspace

- [Updating](updating.md): update the tools, add something new, and make a release.
- [Code layout](code-layout.md): what each file of the code does, and how to add a palette action or a `herdspace` command.
- [Testing](testing.md): the tests, and how to run them.
- [CI](ci.md): the tests that GitHub Actions runs for each pull request and each release.
- [Repository settings](repository-settings.md): the GitHub settings of this repository, and the reason for each one.
- [Agent instructions](../AGENTS.md): the rules and skills for a coding agent that works in a clone of this repository.

## About

- [Changelog](../CHANGELOG.md): the changes in each release.
- [Credits](credits.md): the projects that herdspace builds on, and the tools that the setup installs.
- [License](../LICENSE): MIT.
