# shellcheck shell=bash
# The folders of --with-ignored. lib/hopen/search.py finds and searches the files.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# SEARCH_IN holds the folders of --with-ignored. When it has folders, the file
# list and the search read only them, with the files that .gitignore names.
SEARCH_IN=()
# add_search_dir FOLDER adds FOLDER to SEARCH_IN. A name that starts with "-"
# gets "./" in front, so that fd, find, and rg never read it as an option.
add_search_dir() {
  local d="${1%/}"
  case "$d" in -*) d="./$d" ;; esac
  SEARCH_IN+=("$d")
}
