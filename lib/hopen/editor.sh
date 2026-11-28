# shellcheck shell=bash
# The editor: open a file in it, and the command that starts the herdspace Neovim.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.
# lib/hopen/editor.py does the work.

# editor_command prints the editor to start, with the herdspace Neovim when the
# person has no Neovim files of their own.
editor_command() { hopen_py internal editor-command; }
