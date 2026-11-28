# shellcheck shell=bash
# The common helpers of hopen: messages, a check for a command, names, and JSON.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# short_path PATH shows a path in the home folder as ~/... The ~ is in a
# variable, because bash 5 expands a ~ in the replacement text.
short_path() { local tilde='~'; printf '%s' "${1/#$HOME/$tilde}"; }
warn() { printf '  [warn] %s\n' "$*" >&2; }
die() { printf '  [err]  %s\n' "$*" >&2; exit 1; }

valid_name() {
  case "$1" in
    "" | *[!A-Za-z0-9._-]*) return 1 ;;
    *) return 0 ;;
  esac
}

# HOPEN_LIB is the folder of the modules. bin/hopen sets it. A test that
# loads a module alone gets the folder of this file.
HOPEN_LIB="${HOPEN_LIB:-${BASH_SOURCE[0]%/*}}"
HOPEN_PYTHON=""

# hopen_python prints the Python that runs the hopen package: Python 3.11 or
# later, which has tomllib for herdspace.toml. Some systems have an older
# python3 and a newer python3.N beside it, for example Ubuntu 22.04. With no
# Python 3.11, it prints python3, which still reads a VS Code workspace file.
hopen_python() {
  local py
  if [ -z "$HOPEN_PYTHON" ]; then
    HOPEN_PYTHON=python3
    for py in python3 python3.14 python3.13 python3.12 python3.11; do
      command -v "$py" >/dev/null 2>&1 || continue
      "$py" -I -c 'import sys; sys.exit(sys.version_info < (3, 11))' 2>/dev/null && { HOPEN_PYTHON="$py"; break; }
    done
  fi
  printf '%s' "$HOPEN_PYTHON"
}

# hopen_py ARGS... runs the Python package of hopen, lib/hopen/__main__.py.
# -I keeps out the environment and the current folder, and -B writes no
# __pycache__ folder.
hopen_py() { "$(hopen_python)" -I -B "${HOPEN_LIB}/__main__.py" "$@"; }

json_get() { python3 -I -c "import json,sys; d=json.load(sys.stdin); print(eval(sys.argv[1], {'d': d}))" "$1"; }

need() { command -v "$1" >/dev/null 2>&1 || die "$2 needs $1. The server setup installs it."; }

# herdr_json ARGS... runs a Herdr command and prints one field of its result,
# for example "herdr_json root_pane.pane_id tab create ...".
herdr_json() {
  local field="$1"
  shift
  herdr "$@" 2>/dev/null | python3 -c '
import json, sys
value = json.load(sys.stdin).get("result", {})
for key in sys.argv[1].split("."):
    value = value.get(key, {}) if isinstance(value, dict) else {}
print(value if isinstance(value, str) else "")' "$field"
}
