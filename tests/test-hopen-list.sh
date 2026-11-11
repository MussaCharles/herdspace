#!/usr/bin/env bash
# test-hopen-list.sh tests how hopen reads a list, with no Herdr. It checks the
# settings, the session names, and lists that try to add lines, hide text, or
# load a template from outside the templates folder.
#
# Usage: tests/test-hopen-list.sh
cd "$(dirname "$0")/.." || exit 1
failures=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }
contains() { case "$1" in *"$2"*) pass "$3" ;; *) fail "$3: ${1:0:300}" ;; esac; }
lacks() { case "$1" in *"$2"*) fail "$3: found [$2]" ;; *) pass "$3" ;; esac; }

RS=$'\x1e'
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# shellcheck disable=SC1090 # The functions come from bin/hopen.
source <(sed -n '/^read_list() {/,/^}/p;/^find_lists() {/,/^}/p;/^valid_name() {/,/^}/p;/^warn() {/p' bin/hopen)
mkdir -p "$tmp/code/a" "$tmp/code/b"

# Settings.
cat >"$tmp/work.code-workspace" <<'JSON'
{
  // A comment, and a trailing comma.
  "folders": [ { "name": "a", "path": "./code/a" }, { "path": "./code/b" }, ],
  "settings": {
    "hopen.template": "agent",
    "hopen.templates": { "a": "code" },
    "hopen.onOpen": { "a": "make setup" },
    "hopen.env": { "a": { "PORT": 3000, "DEBUG": true } },
    "hopen.tabs": { "a": [ { "name": "logs", "run": "tail -f log" } ] }
  }
}
JSON
out="$(read_list "$tmp/work.code-workspace" items)"
contains "$out" "R${RS}work${RS}${tmp}${RS}agent${RS}-${RS}-" 'the parent workspace uses the default template'
contains "$out" "P${RS}a${RS}${tmp}/code/a${RS}code${RS}make setup${RS}PORT=3000"$'\x1f'"DEBUG=true" 'a project has its template, command, and values'
contains "$out" "P${RS}b${RS}${tmp}/code/b${RS}agent${RS}-${RS}-" 'a project with no settings uses the defaults'
contains "$out" "T${RS}a${RS}logs${RS}plain${RS}tail -f log" 'a tab has its name and command'
contains "$(read_list "$tmp/work.code-workspace" session)" 'work' 'the session has the name of the file'

# A list that tries to add a line, hide text, or load another file.
python3 -I - "$tmp/bad.code-workspace" <<'PY'
import json, sys
data = {
    "folders": [
        {"name": "a", "path": "./code/a"},
        {"name": "b", "path": "./code/b\nP\tinjected\t/tmp\tplain\trm -rf ~\t-"},
    ],
    "settings": {
        "hopen.templates": {"a": "../../tmp/evil"},
        "hopen.env": {"a": {"X\nP\tfake\t/tmp\tplain\tcurl evil\t-": "1", "OK": "v‮hidden"}},
        "hopen.onOpen": {"a": "echo \u001b[2Jsafe‮"},
        "hopen.tabs": {"a": [{"name": "t\nP\tx", "template": "/tmp/x"}]},
    },
}
open(sys.argv[1], "w").write(json.dumps(data))
PY
bad="$(read_list "$tmp/bad.code-workspace" items)"
kinds="$(cut -d "$RS" -f1 <<<"$bad" | sort | uniq -c | tr -s ' ' | tr '\n' ' ')"
contains "$kinds" '1 P' 'a crafted list adds no project line'
lacks "$(grep -v '^W' <<<"$bad")" 'injected' 'a path with a new line is refused'
lacks "$(grep -v '^W' <<<"$bad")" 'curl evil' 'an environment name with a new line adds no line'
contains "$bad" 'the template name ../../tmp/evil is not valid' 'a template name with a path is refused'
contains "$bad" 'the template name /tmp/x is not valid' 'a tab template with a path is refused'
contains "$bad" 'echo ?[2Jsafe?' 'control and bidi characters show as ?'
contains "$bad" 'OK=v?hidden' 'an environment value has no hidden characters'
lacks "$bad" $'\x1b' 'no escape character reaches the output'

# An empty name is refused, so that no field can move to another place.
python3 -I - "$tmp/empty.code-workspace" <<'PY'
import json, sys
data = {
    "folders": [{"name": "\t", "path": "./code/a"}, {"name": "b", "path": "./code/b"}],
    "settings": {
        "hopen.onOpen": {"b": "echo shown"},
        "hopen.env": {"b": {"X": "1"}},
        "hopen.tabs": {"b": [{"name": "\t", "run": "echo hidden"}, {"name": "\u200b", "run": "echo marked"}]},
    },
}
open(sys.argv[1], "w").write(json.dumps(data))
PY
empty="$(read_list "$tmp/empty.code-workspace" items)"
contains "$empty" 'A project has an empty name, so hopen skips it' 'a project with an empty name is refused'
contains "$empty" 'each tab needs a name' 'a tab with an empty name is refused'
contains "$empty" "T${RS}b${RS}?${RS}plain${RS}echo marked" 'a hidden character in a tab name shows as ?'
fields="$(grep "^P${RS}b${RS}" <<<"$empty" | awk -F "$RS" '{print NF}')"
contains "$fields" '6' 'each project line has six fields'
lacks "$empty" 'echo hidden' 'the command of a refused tab is dropped'

# Session names.
home="$tmp/home"
mkdir -p "$home/evil" "$home/x1" "$home/x2" "$home/solo"
echo '{ "folders": [] }' >"$home/work.code-workspace"
printf 'session = "work"\n' >"$home/evil/herdspace.toml"
printf 'session = "dup"\n' >"$home/x1/herdspace.toml"
echo '{ "folders": [], "settings": { "hopen.session": "dup" } }' >"$home/x2/x2.code-workspace"
echo '{ "folders": [], "settings": { "hopen.session": "renamed" } }' >"$home/solo/solo.code-workspace"
lists="$(HOME="$home" find_lists 2>"$tmp/warnings")"
warnings="$(cat "$tmp/warnings")"
contains "$lists" "work	${home}/work.code-workspace" 'the list with the own name keeps its session'
contains "$lists" "renamed	${home}/solo/solo.code-workspace" 'a list can claim a free name'
if python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))'; then
  contains "$warnings" 'claims the session work' 'a list that claims a used name is skipped'
  lacks "$lists" 'dup' 'two lists that claim one name are both skipped'
  contains "$warnings" 'Two lists claim the session dup' 'hopen names the two lists'
else
  pass 'herdspace.toml checks skipped: Python is older than 3.11'
fi

printf 'RESULT failures=%s\n' "$failures"
[ "$failures" -eq 0 ]
