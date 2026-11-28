"""hopen in Python: one module for each part, with only the standard library.

bin/hopen and the bash modules of lib/hopen/ run this package with
"python3 -I -B lib/hopen/__main__.py". -I keeps out the environment and the
current folder, and -B writes no __pycache__ folder next to the files.
docs/code-layout.md explains the layout.
"""
