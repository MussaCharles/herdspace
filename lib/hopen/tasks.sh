# shellcheck shell=bash
# The tasks of a list: hopen --task, with the environment of the project.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.
# lib/hopen/tasks.py does the work.

# project_for_dir DIR prints "list file<TAB>label" for the project that holds
# DIR. The deepest project folder wins, so a project wins over the parent
# workspace of its list.
project_for_dir() { hopen_py internal project-for-dir "$1"; }

# run_task runs a task of the project of the current folder. In Herdr, it runs
# in a new pane below the current pane. A popup of Herdr has no pane of its
# own, so there it splits the active pane. Outside Herdr, it runs here. Python
# takes the place of hopen, so that the task gives hopen its exit status.
run_task() { exec "$(hopen_python)" -I -B "${HOPEN_LIB}/__main__.py" internal task "$TASK_NAME" "$TRUST_FLAG" "$STATE_DIR"; }
