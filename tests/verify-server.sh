#!/usr/bin/env bash
# verify-server.sh checks a finished server setup. It runs after a bootstrap.
# Usage: tests/verify-server.sh <linux|macos>
set -uo pipefail
PLATFORM="${1:?linux or macos}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="${HOME}/.local/bin:${PATH}"
failures=0
pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; failures=$((failures + 1)); }
check() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$name"; else fail "$name"; fi; }
contains() { case "$1" in *"$2"*) pass "$3" ;; *) fail "$3: wanted [$2] in [${1:0:300}]" ;; esac; }
lacks() { case "$1" in *"$2"*) fail "$3: found [$2]" ;; *) pass "$3" ;; esac; }
same() { check "$1" cmp -s "$2" "$3"; }

for tool in herdr nvim lazygit delta eza zoxide fzf rg bat fd hopen herdr-update-check; do
  check "command ${tool}" command -v "$tool"
done
check 'nvim runs' nvim --version
check 'delta runs' delta --version
check 'eza runs' eza --version

same 'herdr configuration' "$ROOT/config/herdr/config.toml" "$HOME/.config/herdr/config.toml"
if [ "$PLATFORM" = linux ]; then lg="$HOME/.config/lazygit"; else lg="$HOME/Library/Application Support/lazygit"; fi
same 'lazygit configuration' "$ROOT/config/lazygit/config.yml" "$lg/config.yml"
same 'neovim keys' "$ROOT/config/nvim/lua/config/keymaps.lua" "$HOME/.config/nvim/lua/config/keymaps.lua"
same 'zshrc' "$ROOT/config/shell/zshrc.zsh" "$HOME/.zshrc"
same 'p10k' "$ROOT/config/shell/p10k.zsh" "$HOME/.p10k.zsh"
contains "$(cat "$HOME/.config/herdr-bootstrap/env.zsh")" 'BOOTSTRAP_PROMPT_COLOR=30' 'server prompt color'
contains "$(cat "$HOME/.zprofile")" 'herdr-update-check' 'zprofile block'

# Shell behavior with and without a real terminal.
plain="$(zsh -i -c 'alias ls; whence z; print -r -- NO_TTY_OK' </dev/null 2>&1)"
contains "$plain" NO_TTY_OK 'zsh starts with no terminal'
lacks "$plain" 'eza' 'agents keep plain ls'
lacks "$plain" 'monitor' 'no gitstatus error'
tty_out="$(python3 "$ROOT/tests/pty_run.py" 25 '' zsh -i -c 'alias ls; whence -w z; whence -w p10k; print -r -- STARTUP_STATUS=$?; print -r -- TTY_OK; exit' 2>&1)"
contains "$tty_out" TTY_OK 'zsh starts in a terminal'
contains "$tty_out" 'STARTUP_STATUS=0' 'zsh startup ends with status 0'
contains "$tty_out" 'ls=eza' 'ls is eza in a terminal'
contains "$tty_out" 'z: function' 'zoxide in a terminal'
contains "$tty_out" 'p10k: function' 'powerlevel10k loaded'
lacks "$tty_out" 'command not found' 'no missing commands at start'
lacks "$tty_out" 'Insecure completion' 'no insecure directory warning'

# lazygit reads its configuration and quits.
work="$(mktemp -d)"
git -C "$work" init -q
git -C "$work" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
lg_out="$(cd "$work" && python3 "$ROOT/tests/pty_run.py" 8 'q' lazygit 2>&1)"
contains "$lg_out" 'Status' 'lazygit opens'
lacks "$lg_out" 'field' 'lazygit accepts its configuration'

# Neovim loads the configuration and the preview logic works.
cat >"$work/test.lua" <<'LUA'
local preview = require("preview")
local a, b = vim.fn.tempname(), vim.fn.tempname()
vim.fn.writefile({ "a" }, a); vim.fn.writefile({ "b" }, b)
preview.open(a)
local first = preview.current()
preview.open(b)
local result = {
  ok = pcall(require, "neo-tree"),
  colors = vim.g.colors_name,
  replaced = not vim.api.nvim_buf_is_valid(first),
  current = preview.current() ~= nil,
}
preview.pin()
result.pinned = preview.current() == nil
vim.fn.writefile({ vim.json.encode(result) }, vim.env.RESULT)
vim.cmd("qa!")
LUA
RESULT="$work/result.json" nvim --headless "+luafile $work/test.lua" >/dev/null 2>&1
nv="$(cat "$work/result.json" 2>/dev/null)"
contains "$nv" '"colors":"onedark"' 'neovim theme'
contains "$nv" '"ok":true' 'neo-tree loads'
contains "$nv" '"replaced":true' 'preview replaces the old buffer'
contains "$nv" '"pinned":true' 'pin keeps the buffer'

# Herdr itself. This server is throwaway, so a stop is safe.
server_up() { case "$(herdr workspace list 2>/dev/null)" in *workspace_list*) return 0 ;; *) return 1 ;; esac; }
if ! server_up; then
  nohup herdr server >/dev/null 2>&1 &
  for _ in $(seq 1 40); do server_up && break; sleep 0.25; done
fi
check 'herdr server answers' server_up
contains "$(herdr server reload-config 2>&1)" '"diagnostics":[]' 'herdr accepts its configuration'
contains "$(herdr plugin list 2>&1)" 'herdr.auto-title' 'auto title installed'
for _ in $(seq 1 40); do pgrep -f "$HOME/.config/herdr/plugins" >/dev/null && break; sleep 0.25; done
check 'auto title runs' pgrep -f "$HOME/.config/herdr/plugins"
ints="$(herdr integration status 2>&1)"
contains "$ints" 'claude: current' 'claude integration'
contains "$ints" 'pi: current' 'pi integration'
check 'claude skill' test -s "$HOME/.claude/skills/herdr/SKILL.md"
check 'pi skill' test -s "$HOME/.pi/agent/skills/herdr/SKILL.md"
contains "$(herdr-update-check --now; echo DONE)" DONE 'update check runs'

# hopen creates each project once.
mkdir -p "$work/list/one" "$work/list/two"
cat >"$work/list/t.code-workspace" <<JSON
{
  // comment
  "folders": [ { "name": "first", "path": "./one" }, { "path": "./two" }, { "path": "./gone" }, ],
}
JSON
labels() { HERDR_SESSION=hb-test herdr workspace list | python3 -c 'import json,sys; print(",".join(w["label"] for w in json.load(sys.stdin)["result"]["workspaces"]))'; }
hopen hb-test --file "$work/list/t.code-workspace" --no-attach >/dev/null 2>&1
one="$(labels)"
hopen hb-test --file "$work/list/t.code-workspace" --no-attach >/dev/null 2>&1
contains "$one" 'hb-test,first,two' 'hopen creates the projects'
contains "$(labels)" "$one" 'hopen adds nothing on a second run'
if [ "$(labels)" = "$one" ]; then pass 'hopen list is unchanged'; else fail 'hopen list is unchanged'; fi
attach="$(python3 "$ROOT/tests/pty_run.py" 8 '\x02q' hopen hb-test --file "$work/list/t.code-workspace" 2>&1; echo "status=$?")"
contains "$attach" 'status=0' 'hopen attaches and detach exits'
herdr session stop hb-test >/dev/null 2>&1
sleep 1
herdr session delete hb-test >/dev/null 2>&1

# hopen --all and --list find each list in the home folder.
mkdir -p "$HOME/hb-all-two/app" "$HOME/hb-all-one-dir"
printf '{ "folders": [ { "name": "x", "path": "./hb-all-one-dir" } ] }\n' >"$HOME/hb-all-one.code-workspace"
printf '{ "folders": [ { "name": "app", "path": "./app" } ] }\n' >"$HOME/hb-all-two/hb-all-two.code-workspace"
listed="$(hopen --list 2>&1)"
contains "$listed" 'hb-all-one' 'hopen --list finds a list in the home folder'
contains "$listed" 'hb-all-two' 'hopen --list finds a list in a project folder'
contains "$listed" 'stopped' 'hopen --list shows a stopped session'
hopen --all >/dev/null 2>&1
labels_of() { HERDR_SESSION="$1" herdr workspace list | python3 -c 'import json,sys; print(",".join(w["label"] for w in json.load(sys.stdin)["result"]["workspaces"]))'; }
contains "$(labels_of hb-all-one)" 'hb-all-one,x' 'hopen --all opens the first list'
contains "$(labels_of hb-all-two)" 'hb-all-two,app' 'hopen --all opens the second list'
first="$(labels_of hb-all-one)"
hopen --all >/dev/null 2>&1
if [ "$(labels_of hb-all-one)" = "$first" ]; then pass 'hopen --all adds nothing on a second run'; else fail 'hopen --all adds nothing on a second run'; fi
contains "$(hopen --list 2>&1)" 'running' 'hopen --list shows a running session'
attach_all="$(python3 "$ROOT/tests/pty_run.py" 8 '\x02q' hopen --all hb-all-two 2>&1; echo "status=$?")"
contains "$attach_all" 'status=0' 'hopen --all attaches to the named session'
contains "$(hopen --all no-such-list 2>&1)" 'No project list' 'hopen --all rejects an unknown name'
for name in hb-all-one hb-all-two; do
  herdr session stop "$name" >/dev/null 2>&1
done
sleep 1
for name in hb-all-one hb-all-two; do
  herdr session delete "$name" >/dev/null 2>&1
done
rm -rf "$HOME/hb-all-two" "$HOME/hb-all-one-dir" "$HOME/hb-all-one.code-workspace"

# Templates split each new workspace into named panes.
if [ ! -f "$HOME/.config/herdr-auto-title/config.env" ]; then pass 'auto title has its default settings'; else fail 'auto title has its default settings'; fi
tlist="$(hopen --templates 2>&1)"
for t in plain code agent grid review; do contains "$tlist" "$t" "template ${t} is listed"; done
mkdir -p "$HOME/hb-tpl/one" "$HOME/hb-tpl/two" "$HOME/hb-tpl/three"
cat >"$HOME/hb-tpl/hb-tpl.code-workspace" <<'JSON'
{
  "folders": [ { "name": "one", "path": "./one" }, { "name": "two", "path": "./two" }, { "name": "three", "path": "./three" } ],
  "settings": { "hopen.template": "agent", "hopen.templates": { "one": "code", "three": "plain", "hb-tpl": "plain" } }
}
JSON
pane_labels() {
  HERDR_SESSION=hb-tpl herdr pane list | python3 -c '
import json, sys
ws = {w["label"]: w["workspace_id"] for w in json.load(open(sys.argv[2]))["result"]["workspaces"]}
print(",".join(sorted(p.get("label") or "-" for p in json.load(sys.stdin)["result"]["panes"] if p["workspace_id"] == ws[sys.argv[1]])))
' "$1" <(HERDR_SESSION=hb-tpl herdr workspace list)
}
hopen hb-tpl --no-attach >/dev/null 2>&1
# Auto Title starts with the session and renames panes it thinks are its own.
sleep 15
contains "$(pane_labels one)" 'agent,editor,git' 'template code makes three named panes'
contains "$(pane_labels two)" 'agent,shell' 'the default template applies to the other folders'
if [ "$(pane_labels three)" = '-' ] || [ "$(pane_labels three | tr ',' '\n' | wc -l | tr -d ' ')" = 1 ]; then pass 'plain keeps one pane'; else fail "plain keeps one pane: $(pane_labels three)"; fi
git_pane() { HERDR_SESSION=hb-tpl herdr pane list | python3 -c '
import json, sys
ws = {w["label"]: w["workspace_id"] for w in json.load(open(sys.argv[1]))["result"]["workspaces"]}
print([p["pane_id"] for p in json.load(sys.stdin)["result"]["panes"] if p["workspace_id"] == ws["one"] and p.get("label") == "git"][0])
' <(HERDR_SESSION=hb-tpl herdr workspace list); }
fg_of() { HERDR_SESSION=hb-tpl herdr pane process-info --pane "$1" | python3 -c 'import json,sys; print(" ".join(p["name"] for p in json.load(sys.stdin)["result"]["process_info"]["foreground_processes"]))'; }
sleep 2
contains "$(fg_of "$(git_pane)")" 'lazygit' 'template starts lazygit'
hopen hb-tpl --no-attach >/dev/null 2>&1
contains "$(pane_labels one)" 'agent,editor,git' 'a second run adds no panes'
contains "$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/hopen/hb-tpl.tsv")" '=editor' 'hopen saves the pane IDs'
# A second session writes the same pane IDs to the shared Auto Title file. That
# made Auto Title forget the names of the first session after a restart.
mkdir -p "$HOME/hb-other/one"
cat >"$HOME/hb-other/hb-other.code-workspace" <<'JSON'
{ "folders": [ { "name": "one", "path": "./one" } ], "settings": { "hopen.templates": { "one": "review" } } }
JSON
hopen hb-other --no-attach >/dev/null 2>&1
sleep 8
herdr session stop hb-tpl >/dev/null 2>&1
sleep 1
restart_out="$(hopen hb-tpl --no-attach 2>&1)"
contains "$restart_out" 'programs started again' 'hopen reports the restarted programs'
sleep 3
contains "$(fg_of "$(git_pane)")" 'lazygit' 'lazygit runs again after a stop'
sleep 12
contains "$(pane_labels one)" 'agent,editor,git' 'pane names stay after a stop'
contains "$(hopen hb-tpl --template nope --no-attach 2>&1)" 'No template named nope' 'unknown template is refused'
# --apply runs inside a pane. A new workspace with one pane stands in for it.
newroot="$(HERDR_SESSION=hb-tpl herdr workspace create --cwd "$HOME/hb-tpl" --label applied --no-focus | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["root_pane"]["pane_id"])')"
HERDR_SESSION=hb-tpl HERDR_ENV=1 HERDR_PANE_ID="$newroot" hopen --apply grid >/dev/null 2>&1
sleep 8
contains "$(pane_labels applied)" 'agent-1,agent-2,shell,tests' 'apply splits the current tab'
contains "$(HERDR_SESSION=hb-tpl HERDR_ENV=1 HERDR_PANE_ID="$newroot" hopen --apply code 2>&1)" 'has 4 panes' 'apply refuses a tab with many panes'
herdr session stop hb-tpl >/dev/null 2>&1
sleep 1
herdr session delete hb-tpl >/dev/null 2>&1
herdr session stop hb-other >/dev/null 2>&1
sleep 1
herdr session delete hb-other >/dev/null 2>&1
rm -rf "$HOME/hb-other" "${XDG_STATE_HOME:-$HOME/.local/state}/hopen/hb-other.tsv"
rm -rf "$HOME/hb-tpl" "${XDG_STATE_HOME:-$HOME/.local/state}/hopen/hb-tpl.tsv"
rm -rf "$work"

printf 'RESULT failures=%s\n' "$failures"
[ "$failures" -eq 0 ]
