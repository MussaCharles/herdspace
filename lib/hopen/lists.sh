# shellcheck shell=bash
# The project lists: read a VS Code workspace file or a herdspace.toml file, find the lists, and choose one.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# A list is a VS Code workspace file, ~/<name>.code-workspace or
# ~/<name>/<name>.code-workspace, or a herdspace file, ~/<name>/herdspace.toml.
# The session has the name of the file or the folder, unless the list sets one.

# no_list_error NAME stops with a message for a name that has no list. It shows
# the lists that exist, the closest one for a typo, and how to make the list.
no_list_error() {
  local name="$1" names close
  names="$(find_lists 2>/dev/null | cut -f1 | sort -u)"
  {
    printf '  [err]  No list of projects named %s.\n' "$name"
    if [ -n "$names" ]; then
      printf '         Your lists: %s\n' "$(printf '%s\n' "$names" | paste -sd ',' - | sed 's/,/, /g')"
      close="$(printf '%s\n' "$names" | python3 -I -c '
import difflib, sys
names = sys.stdin.read().split()
match = difflib.get_close_matches(sys.argv[1], names, n=1, cutoff=0.6)
print(match[0] if match else "")
' "$name")"
      [ -z "$close" ] || printf '         Did you mean: %s?\n' "$close"
    else
      printf '         You have no list yet.\n'
    fi
    printf '         To create the list %s, write ~/%s/herdspace.toml, for example:\n' "$name" "$name"
    printf '           [[project]]\n           name = "api"\n           path = "~/code/api"\n'
    printf '         To open one folder with no list, run: hopen ~/code/api\n'
  } >&2
  exit 1
}

# HOPEN_LISTS_PY is the Python part of read_list, next to this file.
HOPEN_LISTS_PY="${BASH_SOURCE[0]%/*}/lists.py"

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
# list_python FILE prints the Python that reads FILE. A herdspace.toml list
# needs tomllib, which is in Python 3.11 and later. Some systems have an older
# python3 and a newer python3.N beside it, for example Ubuntu 22.04.
list_python() {
  local py
  if [ "$(basename "$1")" = herdspace.toml ]; then
    for py in python3 python3.14 python3.13 python3.12 python3.11; do
      command -v "$py" >/dev/null 2>&1 || continue
      "$py" -I -c 'import sys; sys.exit(sys.version_info < (3, 11))' 2>/dev/null && { echo "$py"; return 0; }
    done
  fi
  echo python3
}

read_list() {
  "$(list_python "$1")" -I "$HOPEN_LISTS_PY" "$1" "$2" "${TEMPLATE_FLAG:-}"
}

# find_lists prints one "session<TAB>file" line for each project list.
#
# A list can name its session with "session" or "hopen.session". That name
# never takes over a list whose own file or folder has the name of the session:
# a list that only claims a name gets a warning, and hopen skips it. If two
# lists only claim one name, hopen skips both. If a herdspace.toml and a VS Code
# list both have the name, hopen uses herdspace.toml, and it prints a warning.
find_lists() {
  local file name session
  {
    for file in "$HOME"/*/herdspace.toml; do
      [ -f "$file" ] || continue
      name="$(basename "$(dirname "$file")")"
      session="$(read_list "$file" session 2>&1)" || { warn "Skipped ${file}. ${session}"; continue; }
      valid_name "$session" && printf '%s\t%s\t%s\n' "$session" "$file" "$([ "$session" = "$name" ] && echo own || echo claimed)"
    done
    for file in "$HOME"/*.code-workspace "$HOME"/*/*.code-workspace; do
      [ -f "$file" ] || continue
      name="$(basename "$file" .code-workspace)"
      case "$file" in
        "${HOME}/${name}.code-workspace" | "${HOME}/${name}/${name}.code-workspace") ;;
        *) continue ;;
      esac
      session="$(read_list "$file" session 2>&1)" || { warn "Skipped ${file}. ${session}"; continue; }
      valid_name "$session" && printf '%s\t%s\t%s\n' "$session" "$file" "$([ "$session" = "$name" ] && echo own || echo claimed)"
    done
  } | awk -F '\t' '
    { order[NR] = $1; file[NR] = $2; kind[NR] = $3; count[$1 SUBSEP $3]++ }
    END {
      for (i = 1; i <= NR; i++) {
        s = order[i]
        if (done[s]) continue
        if (count[s SUBSEP "own"] > 0) {
          if (kind[i] != "own") continue
          done[s] = 1
          print s "\t" file[i]
          for (j = 1; j <= NR; j++) {
            if (j == i || order[j] != s) continue
            if (kind[j] == "own") printf "  [warn] Session %s has two lists. hopen uses %s.\n", s, file[i] > "/dev/stderr"
            else printf "  [warn] %s claims the session %s, which %s has. hopen skips it.\n", file[j], s, file[i] > "/dev/stderr"
          }
        } else if (count[s SUBSEP "claimed"] > 1) {
          done[s] = 1
          printf "  [warn] Two lists claim the session %s. hopen skips both. Give one another name:\n", s > "/dev/stderr"
          for (j = 1; j <= NR; j++) if (order[j] == s) printf "         %s\n", file[j] > "/dev/stderr"
        } else {
          done[s] = 1
          print s "\t" file[i]
        }
      }
    }'
}

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
