# shellcheck shell=bash
# Quick open, like Ctrl+P in VS Code, and the menus of hopen --find and --grep.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.
# lib/hopen/quickopen.py does the work. Python takes the place of hopen.

# quick_open lets the person choose a file of the project, as Cmd+P does in VS
# Code, and opens it with the focus on it.
quick_open() { exec "$(hopen_python)" -I -B "${HOPEN_LIB}/__main__.py" internal quick "$DIR" ${SEARCH_IN[@]+"${SEARCH_IN[@]}"}; }

# find_file lets the person choose a file in the current folder with fzf, and
# opens it.
find_file() { exec "$(hopen_python)" -I -B "${HOPEN_LIB}/__main__.py" internal find "$DIR" ${SEARCH_IN[@]+"${SEARCH_IN[@]}"}; }

# grep_files searches the files of the current folder with ripgrep, lets the
# person choose a result with fzf, and opens the file at that line.
grep_files() { exec "$(hopen_python)" -I -B "${HOPEN_LIB}/__main__.py" internal grep "$DIR" "$GREP_TEXT" ${SEARCH_IN[@]+"${SEARCH_IN[@]}"}; }
