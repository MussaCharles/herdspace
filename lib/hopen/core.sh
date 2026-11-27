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
