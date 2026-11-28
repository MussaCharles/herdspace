# shellcheck shell=bash
# The project lists: read a VS Code workspace file or a herdspace.toml file, find the lists, and choose one.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# A list is a VS Code workspace file, ~/<name>.code-workspace or
# ~/<name>/<name>.code-workspace, or a herdspace file, ~/<name>/herdspace.toml.
# The session has the name of the file or the folder, unless the list sets one.

# no_list_error NAME stops with a message for a name that has no list. It shows
# the lists that exist, the closest one for a typo, and how to make the list.
no_list_error() { hopen_py internal no-list "$1"; exit 1; }

# read_list FILE WHAT prints facts about one list. WHAT is one of:
#   session  the session name
#   items    one line for each workspace and each extra tab. The fields are
#            separated by the byte 0x1e (RS below), which is not white space,
#            so that bash keeps each field in its place:
#            R RS label RS path RS template RS on_open RS env   (the parent workspace)
#            P RS label RS path RS template RS on_open RS env   (a project)
#            T RS label RS tab name RS template RS command
#            F RS label RS file RS names RS env  (the values of an env file;
#                                                 it comes before its R or P line)
#            K RS label RS task name RS command   (a task; it comes after its R or P line)
#            W RS message                                       (a warning)
#            env is KEY=VALUE items, separated by the byte 0x1f. An empty
#            field is "-". No field holds a control character.
# lib/hopen/lists.py reads the list.
read_list() { hopen_py internal read-list "$1" "$2" "${TEMPLATE_FLAG:-}"; }

# find_lists prints one "session<TAB>file" line for each project list.
#
# A list can name its session with "session" or "hopen.session". That name
# never takes over a list whose own file or folder has the name of the session:
# a list that only claims a name gets a warning, and hopen skips it. If two
# lists only claim one name, hopen skips both. If a herdspace.toml and a VS Code
# list both have the name, hopen uses herdspace.toml, and it prints a warning.
# lib/hopen/lists.py finds the lists.
find_lists() { hopen_py internal find-lists; }

find_list_for() {
  find_lists | awk -F '\t' -v n="$1" '$1 == n {print $2}'
}

show_lists() {
  local lists name state count
  lists="$(find_lists)"
  [ -n "$lists" ] || die "No project lists. Create ~/my-projects.code-workspace or ~/my-projects/herdspace.toml."
  printf '%-22s %-9s %-11s %s\n' SESSION STATE WORKSPACES LIST
  while IFS=$'\t' read -r name LIST_FILE; do
    SESSION="$name"
    if session_answers; then
      state="running"
      count="$(workspaces | wc -l | tr -d ' ')"
    else
      state="stopped"
      count="-"
    fi
    printf '%-22s %-9s %-11s %s\n' "$name" "$state" "$count" "$(short_path "$LIST_FILE")"
  done <<<"$lists"
}

# pick_list lets the person choose a list when hopen gets no name in a
# terminal.
pick_list() {
  local lists name file
  lists="$(find_lists)"
  [ -n "$lists" ] || die "No project lists. Create ~/my-projects/herdspace.toml, or run hopen . in a folder."
  SESSION="$(while IFS=$'\t' read -r name file; do printf '%s\t%-22s %s\n' "$name" "$name" "$(short_path "$file")"; done <<<"$lists" | choose "Open which list")" || exit 1
  [ -n "$SESSION" ] || exit 0
}

# use_list_file FILE opens the list in FILE. The same rule as find_lists: a list
# outside the usual places cannot take the session of another list. Its
# commands and values still need approval.
use_list_file() {
  local list="$1" owner
  LIST_FILE="$list"
  SESSION="$(read_list "$list" session)" || die "Could not read ${list}."
  owner="$(find_list_for "$SESSION" 2>/dev/null)"
  if [ -n "$owner" ] && [ "$owner" != "$list" ]; then
    die "$(short_path "$list") uses the session ${SESSION}, which $(short_path "$owner") has. Give the list another session name."
  fi
}

# open_folder handles "hopen <folder>". It uses the list in the folder, if the
# folder has one: herdspace.toml, <folder>.code-workspace, or the only
# .code-workspace file. Else the session and its one workspace get the folder name.
open_folder() {
  local path name list others=()
  path="$(cd "$SESSION" 2>/dev/null && pwd -P)" || die "No folder ${SESSION}."
  [[ "$path" != *[[:cntrl:]]* ]] || die "The folder name has a control character."
  name="$(basename "$path")"
  for list in "${path}/herdspace.toml" "${path}/${name}.code-workspace"; do
    if [ -f "$list" ]; then
      use_list_file "$list"
      return 0
    fi
  done
  for list in "$path"/*.code-workspace; do
    [ -f "$list" ] && others+=("$list")
  done
  if [ "${#others[@]}" -eq 1 ]; then
    use_list_file "${others[0]}"
    return 0
  fi
  if [ "${#others[@]}" -gt 1 ]; then
    die "The folder has more than one VS Code workspace file. Open one of them, for example: hopen $(basename "${others[0]}")"
  fi
  FOLDER="$path"
  # A session name uses letters, numbers, dots, dashes, and underscores only.
  SESSION="$(printf '%s' "$name" | tr -c 'A-Za-z0-9._-' '-')"
  [ "$SESSION" != "." ] && [ "$SESSION" != ".." ] || SESSION="-"
  list="$(find_list_for "$SESSION" 2>/dev/null)"
  [ -z "$list" ] || warn "The list $(short_path "$list") uses the session ${SESSION}. hopen adds the folder to that session."
}
