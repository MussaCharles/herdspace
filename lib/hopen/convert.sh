# shellcheck shell=bash
# hopen --convert: write a herdspace.toml file from a VS Code workspace file.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# convert_list writes ~/SESSION/herdspace.toml from the VS Code list of SESSION.
# It never replaces a file. lib/hopen/convert.py does the work.
convert_list() { hopen_py internal convert "$SESSION" "${TEMPLATE_FLAG:-}" || exit $?; }
