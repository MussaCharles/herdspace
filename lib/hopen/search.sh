# shellcheck shell=bash
# Find and search the files of a project, also with the files that .gitignore names.
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

# lib/hopen/search.py builds the commands of these three functions.
# list_files prints the files of the current folder. With SEARCH_IN, it prints
# only the files of those folders, with the files that .gitignore names, but
# not the folders of SKIP_DIRS.
list_files() { hopen_py internal list-files ${SEARCH_IN[@]+"${SEARCH_IN[@]}"}; }

# list_folders prints the folders of the current folder, with the folders that
# .gitignore names, but not the folders of SKIP_DIRS.
list_folders() { hopen_py internal list-folders; }

# search_text prints the lines of the files that hold GREP_TEXT, as
# "file:line:text". With SEARCH_IN, it searches only those folders, with the
# files that .gitignore names, but not the folders of SKIP_DIRS.
search_text() { hopen_py internal search-text "$GREP_TEXT" ${SEARCH_IN[@]+"${SEARCH_IN[@]}"}; }
