# shellcheck shell=bash
# The command palette, like Ctrl+Shift+P in VS Code.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.
# lib/hopen/palette/ does the work: __init__.py has the menu, and each group
# of actions has its own Python file. Python takes the place of hopen.

# palette shows the actions that fit the current folder and place, and runs
# the one that the person chooses. With --print, it prints the actions only.
palette() { exec "$(hopen_python)" -I -B "${HOPEN_LIB}/__main__.py" internal palette "$0" "${PALETTE_PRINT:-0}"; }
