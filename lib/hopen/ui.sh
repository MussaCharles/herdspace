# shellcheck shell=bash
# The menu of bash: choose. lib/hopen/ui.py has the look of the menus and the
# questions.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# choose PROMPT shows a menu of the lines on stdin, one "key<TAB>text" line for
# each item, and prints the key that the person chose. It uses fzf if it is
# installed, else a numbered menu that takes a number or a key. It prints
# nothing if the person cancels, and it exits 1 for an unknown answer.
choose() { hopen_py internal choose "$1"; }
