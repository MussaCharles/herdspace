#!/usr/bin/env bash
# tour-release.sh tries each hopen feature on an installed release, as a person
# would. Run it in a throwaway container or VM after the setup, never on your
# own machine: it starts a Herdr server and makes lists in the home folder.
# tests/run-release-check.sh runs it. pty_run.py must be in the same folder.
# Usage: tour-release.sh [expected-version]
set -u
# The folder of this script, before the cd, so that a relative path works.
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HOME" || exit 1
export PATH="$HOME/.local/bin:$PATH"
PTY="python3 ${HERE}/pty_run.py"
ok=0; bad=0
pass() { echo "PASS $1"; ok=$((ok+1)); }
fail() { echo "FAIL $1"; bad=$((bad+1)); }
has() { case "$1" in *"$2"*) pass "$3" ;; *) fail "$3 :: ${1:0:400}" ;; esac; }
J() { python3 -c "import json,sys; d=json.load(sys.stdin)['result']; print($1)"; }

want="${1:-}"
if [ -n "$want" ]; then has "$(hopen --version)" "$want" "hopen --version is $want"; else has "$(hopen --version)" 'hopen ' 'hopen --version answers'; fi
case "$(herdr workspace list 2>/dev/null)" in *workspace_list*) ;; *) nohup herdr server >/dev/null 2>&1 & sleep 3 ;; esac
has "$(herdr workspace list 2>&1)" workspace_list 'herdr server answers'
has "$(herdr server reload-config 2>&1)" '"diagnostics":[]' 'herdr accepts the configuration'

# A list with two projects, a task, env and env_file.
mkdir -p ~/work ~/code/api/src ~/code/web
printf 'API_NAME=tour-api\nAPI_TOKEN=s3cret-value\n' >~/code/api/.env
printf 'def handler():\n    return "needle-in-code"\n' >~/code/api/src/app.py
printf 'hello\n' >~/code/web/index.html
cat >~/work/herdspace.toml <<'T'
template = "agent"
[[project]]
name = "api"
path = "~/code/api"
env = { MODE = "dev" }
env_file = ".env"
tasks = { show = "echo \"$MODE $API_NAME\" > task-out.txt", other = "true" }
[[project]]
name = "web"
path = "~/code/web"
T
has "$(hopen --list 2>&1)" 'work' 'hopen --list shows the list'
q="$($PTY 6 'n\r' hopen work --no-attach 2>&1)"
has "$q" 'API_NAME' 'the approval question names the env_file values'
case "$q" in *s3cret-value*) fail 'the approval question hides the secret value' ;; *) pass 'the approval question hides the secret value' ;; esac
has "$(hopen work --no-attach --trust >/dev/null 2>&1; HERDR_SESSION=work herdr workspace list | J '",".join(w["label"] for w in d["workspaces"])')" 'work,api,web' 'hopen work opens the list workspaces'

# Completion
has "$(hopen --complete lists)" 'work' 'completion lists the lists'
has "$(cd ~/code/api && hopen --complete tasks)" 'show' 'completion lists the tasks of the project'
has "$(zsh -c 'autoload -Uz compinit; compinit -u; source <(hopen --completion zsh) && echo ZOK' 2>&1)" ZOK 'the zsh completion loads'
has "$(bash -c 'source <(hopen --completion bash) && complete -p hopen' 2>&1)" 'hopen' 'the bash completion loads'

# Task in a Herdr pane
pane="$(HERDR_SESSION=work herdr pane list | J '[p["pane_id"] for p in d["panes"] if p["cwd"].endswith("/code/api")][0]')"
t="$(cd ~/code/api && HERDR_SESSION=work HERDR_ENV=1 HERDR_PANE_ID="$pane" hopen --task show 2>&1)"
has "$t" 'runs in a new pane' 'hopen --task show opens a pane'
sleep 3
has "$(cat ~/code/api/task-out.txt 2>/dev/null)" 'dev tour-api' 'the task gets env and env_file values'
has "$(HERDR_SESSION=work herdr pane list | J '",".join(p.get("label") or "" for p in d["panes"])')" 'show' 'the task pane has the task name'
has "$(cd ~/code/api && $PTY 6 '\r' env TERM=dumb hopen --task 2>&1)" 'other' 'hopen --task with no name shows a menu'

# Find and grep
has "$(cd ~/code/api && $PTY 6 '\r' env TERM=xterm-256color EDITOR='echo OPENED' hopen --find 2>&1)" 'OPENED' 'hopen --find opens a file'
has "$(cd ~/code/api && $PTY 6 '\r' env TERM=xterm-256color EDITOR='echo OPENED' hopen --grep needle-in-code 2>&1)" 'OPENED +2 src/app.py' 'hopen --grep opens the result at its line'
# The shell commands load only in a terminal, so ask a zsh in a pseudo terminal.
has "$($PTY 15 '' zsh -i -c 'whence -w ff fif; exit' 2>&1)" 'ff: alias' 'the ff and fif shell commands exist'

# Ports
port=$((20000 + RANDOM % 20000))
(cd ~/code/web && exec python3 -m http.server "$port" --bind 127.0.0.1 >/dev/null 2>&1) & sp=$!
sleep 2
p="$(hopen --ports 2>&1)"
has "$(grep "^$port " <<<"$p")" 'work/web' 'hopen --ports shows the port and its project'

# Palette
pal="$(cd ~/code/api && $PTY 6 'ports\r' env TERM=dumb hopen --palette 2>&1)"
has "$pal" 'Run the task' 'the palette offers the tasks'
has "$pal" 'Find a file' 'the palette offers find'
has "$pal" "$port" 'the palette runs the chosen action (ports)'
kill $sp 2>/dev/null
has "$(cd ~/code/api && $PTY 4 '\r' env TERM=dumb HERDR_ACTIVE_PANE_ID="$pane" hopen --palette 2>&1)" 'template' 'in a popup, the palette offers templates'
grep -qF 'hopen\" --palette' ~/.config/herdr/config.toml && pass 'Herdr has the palette key' || fail 'Herdr has the palette key'

# Menu, folder, path, templates, convert, attach and detach
has "$($PTY 6 'work\r' env TERM=dumb hopen --no-attach 2>&1)" 'Open which list' 'hopen with no name shows a menu'
has "$(cd ~/code/web && hopen . --no-attach 2>&1; herdr session list 2>&1)" 'web' 'hopen . opens the current folder'
mkdir -p ~/solo; has "$(hopen ~/solo --no-attach 2>&1; herdr session list 2>&1)" 'solo' 'hopen <path> opens a folder'
has "$(hopen --templates 2>&1)" 'code' 'hopen --templates lists the templates'
mkdir -p ~/conv && cat >~/conv/conv.code-workspace <<'W'
{ "folders": [ { "path": "../code/api" } ] }
W
has "$(hopen --convert conv 2>&1; cat ~/conv/herdspace.toml 2>/dev/null)" '[[project]]' 'hopen --convert writes a herdspace.toml'
a="$($PTY 8 '\x02q' hopen work 2>&1; echo "status=$?")"
has "$a" 'status=0' 'hopen work attaches, and the detach key exits'

echo "RESULT pass=$ok fail=$bad"
[ "$bad" -eq 0 ]
