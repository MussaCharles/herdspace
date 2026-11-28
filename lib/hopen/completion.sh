# shellcheck shell=bash
# The shell completion of hopen, for zsh and bash.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# completion_script SHELL prints a completion script for zsh or bash. It asks
# "hopen --complete lists|templates" for the names, so that they stay current.
# lib/hopen/completion.py holds the scripts.
completion_script() { hopen_py internal completion "$1" || exit $?; }
