#!/usr/bin/env bash
# test-hopen-list.sh tests how hopen reads a list, with no Herdr. It checks the
# settings, the session names, and lists that try to add lines, hide text, or
# load a template from outside the templates folder.
#
# Usage: tests/test-hopen-list.sh
cd "$(dirname "$0")/.." || exit 1
ROOT="$PWD"
bin_hopen() { "$ROOT/bin/hopen" "$@"; }
failures=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }
contains() { case "$1" in *"$2"*) pass "$3" ;; *) fail "$3: ${1:0:300}" ;; esac; }
lacks() { case "$1" in *"$2"*) fail "$3: found [$2]" ;; *) pass "$3" ;; esac; }

RS=$'\x1e'
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# shellcheck disable=SC1090 # The functions come from bin/hopen.
source <(sed -n '/^read_list() {/,/^}/p;/^find_lists() {/,/^}/p;/^valid_name() {/,/^}/p;/^list_actions() {/,/^}/p;/^file_hash() {/,/^}/p;/^list_trusted() {/,/^}/p;/^trust_file() {/p;/^warn() {/p;/^short_path() {/p' bin/hopen)
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

# An env file: comments, export, quotes, and a value that env sets too.
mkdir -p "$tmp/envs/app"
cat >"$tmp/envs/app/.env" <<'ENV'
# A comment
export TOKEN="s3cret value"
PORT=4000 # the port
NAME='single'
not a line
EMPTY=
PROMPT_COMMAND=touch /tmp/owned
LD_PRELOAD=/tmp/evil.so
node_options=--require /tmp/x.js
ENV
printf '{ "folders": [ { "name": "app", "path": "./app" } ], "settings": { "hopen.envFile": { "app": ".env" }, "hopen.env": { "app": { "PORT": "5000" } } } }\n' >"$tmp/envs/envs.code-workspace"
envout="$(read_list "$tmp/envs/envs.code-workspace" items)"
contains "$envout" "F${RS}app${RS}${tmp}/envs/app/.env${RS}TOKEN=(hidden), PORT=4000, NAME=single, EMPTY=${RS}TOKEN=s3cret value"$'\x1f'"PORT=4000"$'\x1f'"NAME=single"$'\x1f'"EMPTY=" 'an env file gives its names and values'
contains "$envout" 'line 5 of' 'a line that is not KEY=VALUE gives a warning'
contains "$(grep -A1 "^F${RS}" <<<"$envout" | tail -n 1 | cut -c1-5)" "P${RS}app" 'the F line comes just before its project'
actions="$(list_actions "$envout")"
contains "$actions" "app: load ${tmp}/envs/app/.env (TOKEN=(hidden), PORT=4000, NAME=single, EMPTY=)" 'the approval question shows the values, and hides a secret'
lacks "$actions" 's3cret' 'the approval question does not show a secret value'
contains "$envout" 'cannot set PROMPT_COMMAND' 'an env file cannot set a name that runs code'
lacks "$(grep "^F" <<<"$envout")" 'LD_PRELOAD' 'an env file cannot set LD_PRELOAD'
lacks "$(grep "^F" <<<"$envout")" 'node_options' 'the risky names match in any case'
contains "$(read_list "$tmp/envs/envs.code-workspace" items 2>&1; printf '{ "folders": [ { "name": "app", "path": "./app" } ], "settings": { "hopen.envFile": { "app": "missing.env" } } }\n' >"$tmp/envs/m.code-workspace"; read_list "$tmp/envs/m.code-workspace" items)" 'cannot read the env file' 'a missing env file gives a warning'

# A change in the env file asks again.
# shellcheck disable=SC2034 # list_trusted reads these.
STATE_DIR="$tmp/state"
TRUST_FLAG=1
list_trusted "$tmp/envs/envs.code-workspace" "$actions" "TOKEN=a" </dev/null
# shellcheck disable=SC2034
TRUST_FLAG=0
if list_trusted "$tmp/envs/envs.code-workspace" "$actions" "TOKEN=a" </dev/null; then pass 'an approved list stays approved'; else fail 'an approved list stays approved'; fi
if list_trusted "$tmp/envs/envs.code-workspace" "$actions" "TOKEN=b" </dev/null; then fail 'a changed env file needs a new approval'; else pass 'a changed env file needs a new approval'; fi

# hopen --convert writes a herdspace.toml with the same projects and settings.
chome="$tmp/convert-home"
mkdir -p "$chome/code/a"
printf 'X=1\n' >"$chome/code/a/.env"
printf '{ "folders": [ { "name": "a", "path": "./code/a" } ], "settings": { "hopen.envFile": { "a": ".env" }, "hopen.templates": { "a": "code" }, "hopen.onOpen": { "a": "make" }, "hopen.env": { "a": { "PORT": "1" } }, "hopen.tabs": { "a": [ { "name": "logs", "run": "tail -f x" } ] } } }\n' >"$chome/w.code-workspace"
contains "$(HOME="$chome" bin/hopen --convert w 2>&1)" 'Wrote' 'hopen --convert writes a file'
converted="$(cat "$chome/w/herdspace.toml" 2>/dev/null)"
contains "$converted" 'template = "code"' 'the converted file has the template'
contains "$converted" 'on_open = "make"' 'the converted file has the command'
contains "$converted" 'env = { PORT = "1" }' 'the converted file has the values'
contains "$converted" 'env_file = ".env"' 'the converted file has the env file'
lacks "$converted" 'X = ' 'the converted file has no value from the env file'
contains "$converted" 'tabs = [{ name = "logs", template = "plain", run = "tail -f x" }]' 'the converted file has the tab'
contains "$(HOME="$chome" bin/hopen --convert w 2>&1)" 'exists' 'hopen --convert never replaces a file'

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

# Tasks, like tasks.json in VS Code. The $ in the commands is text.
thome="$tmp/task-home"
mkdir -p "$thome/tw/api/sub"
# shellcheck disable=SC2016
printf '{ "folders": [ { "name": "api", "path": "./api" } ], "settings": { "hopen.tasks": { "api": { "test": "echo ran-test-$HB_T", "bad name": "x" }, "tw": { "all": "echo parent" } }, "hopen.env": { "api": { "HB_T": "with-env" } } } }\n' >"$thome/tw/tw.code-workspace"
titems="$(read_list "$thome/tw/tw.code-workspace" items)"
contains "$titems" "K${RS}api${RS}test${RS}echo ran-test-\$HB_T" 'a project task is read'
contains "$titems" "K${RS}tw${RS}all${RS}echo parent" 'a task of the parent workspace is read'
contains "$titems" 'the task bad name is not valid' 'a task name with a space is refused'
# shellcheck disable=SC2016
contains "$(list_actions "$titems")" 'api, task test: run echo ran-test-$HB_T' 'the approval question shows each task'
contains "$(cd "$thome/tw/api/sub" && HOME="$thome" bin_hopen --task </dev/null)" 'echo ran-test' 'hopen --task with no terminal lists the tasks of the project of the folder'
contains "$(cd "$thome/tw/api/sub" && HOME="$thome" bin_hopen --task test </dev/null 2>&1)" 'only from an approved list' 'a task of a list that is not approved does not run'
contains "$(cd "$thome/tw/api/sub" && HOME="$thome" bin_hopen --task test --trust </dev/null 2>&1)" 'ran-test-with-env' 'a task runs in the folder with the values of the project'
contains "$(cd "$thome/tw/api" && HOME="$thome" python3 "$ROOT/tests/pty_run.py" 4 '1\r' env TERM=dumb "$ROOT/bin/hopen" --task --trust 2>&1)" 'ran-test-with-env' 'the task menu runs the chosen task'
contains "$(cd "$thome/tw" && HOME="$thome" bin_hopen --task all </dev/null 2>&1)" 'parent' 'the folder of the list runs the tasks of the parent workspace'
contains "$(cd "$thome/tw/api" && HOME="$thome" bin_hopen --task nope </dev/null 2>&1)" 'has no task nope' 'an unknown task gives the names of the tasks'
contains "$(cd "$tmp" && HOME="$thome" bin_hopen --task test </dev/null 2>&1)" 'No project of a list' 'a folder outside each project has no tasks'
HOME="$thome" bin_hopen --convert tw >/dev/null 2>&1
# shellcheck disable=SC2016
contains "$(cat "$thome/tw/herdspace.toml" 2>/dev/null)" 'tasks = { "test" = "echo ran-test-$HB_T" }' 'hopen --convert keeps the tasks'
contains "$(cat "$thome/tw/herdspace.toml" 2>/dev/null)" 'tasks = { "all" = "echo parent" }' 'hopen --convert keeps the tasks of the parent workspace'

# --find and --grep need rg and fzf, and a terminal. Stub programs stand in
# for rg and fzf, so that the test does not depend on the tools of the machine.
fakebin="$tmp/fakebin"
mkdir -p "$fakebin"
printf '#!/bin/sh\nexit 0\n' >"$fakebin/rg"
cp "$fakebin/rg" "$fakebin/fzf"
chmod 755 "$fakebin/rg" "$fakebin/fzf"
contains "$(PATH="$fakebin:$PATH" bin_hopen --grep x </dev/null 2>&1)" 'needs a terminal' 'hopen --grep with no terminal stops with a message'
contains "$(PATH="$fakebin:$PATH" bin_hopen --find </dev/null 2>&1)" 'needs a terminal' 'hopen --find with no terminal stops with a message'
rm "$fakebin/rg"
if ! PATH=/usr/bin:/bin command -v rg >/dev/null; then
  contains "$(PATH="$fakebin:/usr/bin:/bin" bin_hopen --grep x </dev/null 2>&1)" 'needs rg' 'hopen --grep with no rg names the missing tool'
fi

# A name with no list shows the lists that exist, and the closest one.
nhome="$tmp/nolist-home"
mkdir -p "$nhome/website" "$nhome/api-team"
printf '[[project]]\nname = "a"\npath = "."\n' >"$nhome/website/herdspace.toml"
cp "$nhome/website/herdspace.toml" "$nhome/api-team/herdspace.toml"
out="$(HOME="$nhome" bin_hopen websit --no-attach 2>&1)"
contains "$out" 'Your lists: api-team, website' 'a missing list shows the lists that exist'
contains "$out" 'Did you mean: website?' 'a missing list suggests the closest list'
contains "$out" "write ~/websit/herdspace.toml" 'a missing list shows how to create it'
out="$(HOME="$tmp/empty-home" bin_hopen work --no-attach 2>&1)"
contains "$out" 'You have no list yet.' 'with no list, hopen says so'

# Shell completion.
complete_bash() {
  HOME="$home" HOPEN_TEMPLATES=config/templates PATH="$PWD/bin:$PATH" bash -c 'eval "$(hopen --completion bash)"; COMP_WORDS=("$@"); COMP_CWORD=$(($# - 1)); _hopen; echo "${COMPREPLY[*]}"' _ "$@"
}
contains "$(complete_bash hopen --template c)" 'code' 'bash completion offers template names'
contains "$(complete_bash hopen --no)" '--no-attach' 'bash completion offers options'
contains "$(complete_bash hopen re)" 'renamed' 'bash completion offers list names'
contains "$(complete_bash hopen ./bi)" './bin' 'bash completion offers folders for a path'
contains "$(cd "$thome/tw/api" && HOME="$thome" HOPEN_TEMPLATES="$ROOT/config/templates" PATH="$ROOT/bin:$PATH" bash -c 'eval "$(hopen --completion bash)"; COMP_WORDS=(hopen --task t); COMP_CWORD=2; _hopen; echo "${COMPREPLY[*]}"')" 'test' 'bash completion offers the task names'
if command -v zsh >/dev/null; then
  if bin/hopen --completion zsh | zsh -n; then pass 'the zsh completion script has no syntax error'; else fail 'the zsh completion script has no syntax error'; fi
fi
contains "$(bin/hopen --completion fish 2>&1)" 'needs zsh or bash' 'hopen --completion refuses another shell'

printf 'RESULT failures=%s\n' "$failures"
[ "$failures" -eq 0 ]
