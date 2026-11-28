# shellcheck shell=bash
# The trust of the commands of a list: hopen runs a command of a list only after the person trusts it.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# list_actions ITEMS prints each command and environment value of a list.
# lib/hopen/trust.py does the work.
list_actions() { hopen_py internal list-actions <<<"$1"; }

# list_trusted FILE ACTIONS [EXTRA] exits 0 if hopen can use the commands and values of
# FILE: the person approved this version of the file before, approves it now,
# or gave --trust. A changed file needs a new approval. EXTRA, the values of
# the env files, goes on fd 3 and ACTIONS on fd 4, because another user can
# read the arguments of a process. stdin stays free for the answer.
list_trusted() {
  hopen_py internal trust "$1" "$TRUST_FLAG" "$STATE_DIR" 3<<<"${3:-}" 4<<<"$2"
}
