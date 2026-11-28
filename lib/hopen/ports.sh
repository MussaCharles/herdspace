# shellcheck shell=bash
# hopen --ports, like the Ports view of VS Code.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# show_ports prints each TCP port that a program of this user listens on, with
# the program, its process ID, and the project that holds its folder.
# lib/hopen/ports.py does the work.
show_ports() { hopen_py internal ports || exit $?; }
