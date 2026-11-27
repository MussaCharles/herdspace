# Files and the editor

[Documentation index](README.md) · [Cheat sheet](cheat-sheet.md) · [Words](cheat-sheet.md#words)

Scope: quick open, find and search in the files, Neovim, and Markdown and images.

## Quick open, find, and search

| Action | Mac | Linux |
|--------|-----|-------|
| Quick open a file of the project in the editor of the tab | `Cmd+P` | `ctrl+b`, `f` |
| Find a file in the shell, and open it | `ff` | `ff` |
| Search in the files, and open a result | `fif TEXT` | `fif TEXT` |

In Herdr, a result of the search of the palette ("Files: Search in the files") opens like quick open, at its line. See [Quick open](hopen.md#quick-open).

### Search the ignored files

Quick open and the search skip the files that `.gitignore` names, for example a build log or a generated file. To search them, use the palette action "Files: Choose folders, and search them with the ignored files":

1. Press `Tab` on each folder to search, and then press `Enter`. You can type to filter the folders.
2. Choose "Open a file of these folders" or "Search the text in these folders".

Only the chosen folders are read, so the search stays fast. The list of folders and the search always skip the folders of dependencies and caches: `.git`, `node_modules`, `.venv`, `venv`, `__pycache__`, `.mypy_cache`, `.pytest_cache`, `.ruff_cache`, `.tox`, `.next`, `.gradle`, `Pods`, `DerivedData`, and `target`. A `.ignore` file in the project hides more folders, with the format of `.gitignore`. In the shell, `hopen --find --with-ignored FOLDER` and `hopen --grep TEXT --with-ignored FOLDER` do the same. Repeat `--with-ignored` for more folders.

The file tree of Neovim also hides the ignored files. Press `H` in the tree to show them, and `H` again to hide them. In the file picker of Neovim, `Alt+I` shows the ignored files, and `Alt+H` the hidden files.

## Neovim

Run `nvim .` in a project. If you have your own `~/.config/nvim`, run `NVIM_APPNAME=herdspace-nvim nvim .` for the herdspace editor. See [Your Neovim files](setup.md#your-neovim-files). Neovim opens the file tree on the left, with the cursor in it. Move with `j` and `k`, or the arrow keys, to see each file on the right. Neovim is a viewer in this setup, because the agents write the code. Its colors are One Dark, on the background of Ghostty. Folder icons have colors by folder name, for example `src`, `tests`, and `docs`.

The editor shows no warnings of linters and language servers, and no spell marks, because you read the files and do not fix them. Go to a definition and hover still work. To show the warnings, press `Space`, then `u`, then `d`. To show the spell marks, press `Space`, then `u`, then `s`. To keep the defaults of LazyVim in each new Neovim, run `herdspace editor normal` on the server. `herdspace editor reader` hides the warnings again, and `herdspace editor` shows the mode.

In Herdr or over SSH, a copy in the editor, for example `yy` or `3yy`, goes to the clipboard of the computer in front of you. The editor sends the text as OSC 52, a terminal code for the clipboard, and Herdr passes it on to your terminal. `p` pastes the last copy of the editor. To paste text from another app, use `Cmd+V`.

![Neovim with a file tree and a file preview](media/neovim.png)

| Action | Keys |
|--------|------|
| Preview a file | Click it, or move over it with `j` and `k`, or the arrow keys |
| Keep a file open | Double-click it, or press `Enter` |
| Find a file | `Ctrl+P` |
| Search the project | `/` or `Ctrl+Shift+F` |
| Search inside the file | `g`, then `/` |
| Go to a definition | `Ctrl`-click or `Cmd`-click |
| Go back | `Ctrl`-right-click |
| Focus the file tree | `Cmd+E`, or `Ctrl+Shift+E` on Linux |
| Switch the git branch | `Space`, `g`, `c` |
| Show the keys after the leader | `Space` |
| Save | `:w` |
| Close the file. With no other file, close Neovim | `Ctrl+Q`. With unsaved changes, Neovim asks first. |
| Quit | `:q`. With unsaved changes, Neovim asks first. |
| Update the plugins | `:Lazy update` |

In a Python project, Neovim uses the `.venv` or `venv` folder of the project, so that the language server finds its packages.

### Markdown and images

Neovim renders a Markdown file in the editor: headings with an icon in place of `###`, tables, code blocks, and checkboxes. The line with the cursor shows the raw text, so that you can edit it. To read a Markdown file, open the palette and choose "Files: Read a Markdown file, rendered". Press `Ctrl+V` instead of Enter to open it on the right of an agent.

| Action | Keys |
|--------|------|
| Show the raw text, or render again | `Space`, `u`, `m` |
| Preview in a browser (on the machine that runs Neovim) | `Space`, `c`, `p` |

Neovim also shows images: an image in a Markdown file, and an image file that you open. It uses the Kitty graphics protocol. Ghostty supports it, and Herdr 0.9.2 and later pass the images of a pane to Ghostty. With no ImageMagick (`magick`), Neovim shows PNG files only. Run `:checkhealth snacks` to see what works in your terminal.

## References

- [Herdr documentation](https://herdr.dev/tui/docs/)
- [Herdr keyboard](https://herdr.dev/tui/docs/keyboard/)
- [Herdr CLI reference](https://herdr.dev/tui/docs/cli-reference/)
