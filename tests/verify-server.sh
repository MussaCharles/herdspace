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
contains "$(cat "$HOME/.config/herdspace/env.zsh")" 'BOOTSTRAP_PROMPT_COLOR=30' 'server prompt color'
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
result.confirm = vim.o.confirm
result.netrw_off = vim.g.loaded_netrw == 1
result.flush = vim.api.nvim_get_hl(0, { name = "Normal" }).bg == nil
result.venv = require("lazy.core.config").plugins["venv-selector.nvim"] ~= nil
vim.fn.writefile({ vim.json.encode(result) }, vim.env.RESULT)
vim.cmd("qa!")
LUA
RESULT="$work/result.json" nvim --headless "+luafile $work/test.lua" >/dev/null 2>&1
nv="$(cat "$work/result.json" 2>/dev/null)"
contains "$nv" '"colors":"onedark"' 'neovim theme'
contains "$nv" '"ok":true' 'neo-tree loads'
contains "$nv" '"replaced":true' 'preview replaces the old buffer'
contains "$nv" '"pinned":true' 'pin keeps the buffer'
contains "$nv" '"confirm":true' 'neovim asks before it quits with unsaved changes'
contains "$nv" '"netrw_off":true' 'netrw shows no folder listing in the editor'
contains "$nv" '"flush":true' 'the editor has the background of the terminal'
contains "$nv" '"venv":true' 'the Python venv selector is set up'

# `nvim .` opens the file tree and an empty editor, with no folder buffer.
cat >"$work/tree.lua" <<'LUA'
vim.defer_fn(function()
  local tree, folder = false, false
  local focused = vim.bo[vim.api.nvim_get_current_buf()].filetype == "neo-tree"
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "neo-tree" then tree = true end
    local name = vim.api.nvim_buf_get_name(buf)
    if name ~= "" and vim.fn.isdirectory(name) == 1 then folder = true end
  end
  vim.fn.writefile({ vim.json.encode({ tree = tree, folder = folder, focused = focused }) }, vim.env.RESULT)
  vim.cmd("qa!")
end, 3000)
LUA
tree_out="$(cd "$work" && RESULT="$work/tree.json" python3 "$ROOT/tests/pty_run.py" 12 '' nvim . "+luafile $work/tree.lua" >/dev/null 2>&1; cat "$work/tree.json" 2>/dev/null)"
contains "$tree_out" '"tree":true' 'nvim . opens the file tree'
contains "$tree_out" '"folder":false' 'nvim . keeps no folder buffer in the editor'
contains "$tree_out" '"focused":true' 'nvim . puts the cursor in the file tree'

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
tpl_out="$(hopen hb-test --file "$work/list/t.code-workspace" --template code --no-attach 2>&1)"
contains "$tpl_out" 'splits only new projects' 'hopen says why --template splits no project that exists'
contains "$tpl_out" 'hopen --apply code' 'hopen names hopen --apply for a project that exists'
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

# hopen --find and --grep open a file, or a search result at its line.
mkdir -p "$work/hb-find/src"
printf 'one\ntwo needle()\n' >"$work/hb-find/src/a.txt"
found="$(cd "$work/hb-find" && python3 "$ROOT/tests/pty_run.py" 6 '\r' env TERM=xterm-256color EDITOR='echo OPENED' hopen --find 2>&1)"
contains "$found" 'OPENED src/a.txt' 'hopen --find opens the chosen file in the editor'
found="$(cd "$work/hb-find" && python3 "$ROOT/tests/pty_run.py" 6 '\r' env TERM=xterm-256color EDITOR='echo OPENED' hopen --grep 'needle()' 2>&1)"
contains "$found" 'OPENED +2 src/a.txt' 'hopen --grep opens the file at the line of the result'

# hopen --palette shows the actions, and runs the chosen one.
pal="$(cd "$work" && python3 "$ROOT/tests/pty_run.py" 6 'ports\r' env TERM=dumb hopen --palette 2>&1)"
contains "$pal" 'Find a file' 'the palette offers to find a file'
contains "$pal" 'Open the list' 'outside Herdr, the palette offers each list'
case "$pal" in *PORT*ADDRESS* | *'listens on'*) pass 'the palette runs the chosen action' ;; *) fail "the palette runs the chosen action: ${pal:0:300}" ;; esac
pal="$(cd "$work" && python3 "$ROOT/tests/pty_run.py" 4 '\r' env TERM=dumb HERDR_ACTIVE_PANE_ID=w1:p1 hopen --palette 2>&1)"
contains "$pal" 'with the template code' 'in a Herdr popup, the palette offers the templates'
lacks "$pal" 'Open the list' 'in a Herdr popup, the palette does not offer to attach to a list'
check 'Herdr has the palette key' grep -qF -- 'hopen\" --palette' "$HOME/.config/herdr/config.toml"

# hopen with no name shows a menu in a terminal: fzf, or a numbered menu.
# Only Enter: if the keys hold a filter too, fzf can take Enter before the
# filter, and pick the first list.
first="$(hopen --complete lists | head -n 1)"
picked="$(python3 "$ROOT/tests/pty_run.py" 6 '\r' env TERM=xterm-256color hopen --no-attach 2>&1)"
contains "$picked" "Session ${first}" 'hopen with no name opens the list chosen in fzf'
nofzf="$work/nofzf"
mkdir -p "$nofzf"
for tool in hopen herdr python3; do ln -sf "$(command -v "$tool")" "$nofzf/$tool"; done
picked="$(python3 "$ROOT/tests/pty_run.py" 6 'hb-all-one\r' env PATH="$nofzf:/usr/bin:/bin" hopen --no-attach 2>&1)"
contains "$picked" 'Open which list' 'with no fzf, hopen shows a numbered menu'
contains "$picked" 'Session hb-all-one' 'the numbered menu opens the list with that name'
contains "$(python3 "$ROOT/tests/pty_run.py" 6 'no-such\r' env PATH="$nofzf:/usr/bin:/bin" hopen --no-attach 2>&1)" 'No item no-such' 'the numbered menu rejects an unknown name'
contains "$(hopen </dev/null 2>&1; echo "status=$?")" 'status=2' 'with no terminal, hopen with no name prints the usage'
contains "$(python3 "$ROOT/tests/pty_run.py" 6 'hb-all-one\r' env TERM=dumb hopen --no-attach 2>&1)" 'Open which list' 'with TERM=dumb, hopen shows the numbered menu'

# hopen <folder> opens one folder with no list, or the list in the folder.
mkdir -p "$work/hb folder" "$work/hb-listed/app"
(cd "$work/hb folder" && hopen . --no-attach >/dev/null 2>&1)
contains "$(labels_of hb-folder)" 'hb-folder' 'hopen . opens the current folder as a session'
hopen "$work/hb folder" --no-attach >/dev/null 2>&1
if [ "$(labels_of hb-folder)" = "hb-folder" ]; then pass 'hopen . adds nothing on a second run'; else fail 'hopen . adds nothing on a second run'; fi
printf '[[project]]\nname = "app"\npath = "app"\n' >"$work/hb-listed/herdspace.toml"
hopen "$work/hb-listed" --no-attach >/dev/null 2>&1
contains "$(labels_of hb-listed)" 'hb-listed,app' 'hopen <folder> uses the list in the folder'
contains "$(hopen "$work/no-such-folder" 2>&1)" 'No folder' 'hopen <folder> rejects a missing folder'
mkdir -p "$work/hb-claim"
printf 'session = "hb-all-one"\n' >"$work/hb-claim/herdspace.toml"
contains "$(hopen "$work/hb-claim" --no-attach 2>&1)" 'which' 'a list in a folder cannot take the session of another list'
for name in hb-folder hb-listed; do
  herdr session stop "$name" >/dev/null 2>&1
done
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

# The list settings: a session name, no parent workspace, an on-open command,
# and extra tabs. A second run adds nothing.
mkdir -p "$HOME/hb-set/web"
printf 'HB_FILE=from-file\nHB_VALUE=from-file\n' >"$HOME/hb-set/web/.env"
cat >"$HOME/hb-set/hb-set.code-workspace" <<'JSON'
{
  "folders": [ { "name": "web", "path": "./web" } ],
  "settings": {
    "hopen.session": "hb-named",
    "hopen.parentWorkspace": false,
    "hopen.onOpen": { "web": "printf '%s %s' \"$HB_VALUE\" \"$HB_FILE\" > opened.txt" },
    "hopen.env": { "web": { "HB_VALUE": "from-env" } },
    "hopen.envFile": { "web": ".env" },
    "hopen.tasks": { "web": { "mark": "printf %s \"$HB_VALUE\" > task-ran.txt" } },
    "hopen.tabs": { "web": [ { "name": "logs", "run": "printf %s \"$HB_VALUE\" > tab-ran.txt" }, { "name": "side", "template": "agent" }, { "template": "grid" } ] }
  }
}
JSON
set_out="$(hopen hb-named --no-attach --trust 2>&1)"
contains "$(hopen --list 2>&1)" 'hb-named' 'hopen.session names the session'
contains "$(labels_of hb-named)" 'web' 'the session has the project'
if [ "$(labels_of hb-named)" = "web" ]; then pass 'hopen.parentWorkspace false adds no parent workspace'; else fail "hopen.parentWorkspace false adds no parent workspace: $(labels_of hb-named)"; fi
contains "$set_out" 'each tab needs a name' 'a tab with no name gives a clear message'
tabs_of() { HERDR_SESSION="$1" herdr tab list --workspace "$(HERDR_SESSION="$1" herdr workspace list | python3 -c 'import json,sys; print([w["workspace_id"] for w in json.load(sys.stdin)["result"]["workspaces"] if w["label"] == sys.argv[1]][0])' "$2")" | python3 -c 'import json,sys; print(",".join(t["label"] for t in json.load(sys.stdin)["result"]["tabs"]))'; }
contains "$(tabs_of hb-named web)" 'logs,side' 'hopen.tabs adds the named tabs'
sleep 3
contains "$(cat "$HOME/hb-set/web/opened.txt" 2>/dev/null)" 'from-env from-file' 'hopen.onOpen runs with the hopen.env values and the env file, and env wins'
contains "$(cat "$HOME/hb-set/web/tab-ran.txt" 2>/dev/null)" 'from-env' 'a tab runs its command with the hopen.env values' 
contains "$(HERDR_SESSION=hb-named herdr pane list | python3 -c 'import json,sys; print(",".join(sorted(p.get("label") or "" for p in json.load(sys.stdin)["result"]["panes"])))')" 'agent' 'a tab gets its template'
before_tabs="$(tabs_of hb-named web)"
hopen hb-named --no-attach --trust >/dev/null 2>&1
if [ "$(tabs_of hb-named web)" = "$before_tabs" ]; then pass 'a second run adds no tab'; else fail 'a second run adds no tab'; fi

# hopen --task runs a task of the project in a new pane below the current pane.
web_pane="$(HERDR_SESSION=hb-named herdr pane list | python3 -c 'import json,sys; print([p["pane_id"] for p in json.load(sys.stdin)["result"]["panes"] if p["cwd"].endswith("/hb-set/web")][0])')"
task_out="$(cd "$HOME/hb-set/web" && HERDR_SESSION=hb-named HERDR_ENV=1 HERDR_PANE_ID="$web_pane" hopen --task mark --trust 2>&1)"
contains "$task_out" 'runs in a new pane' 'hopen --task opens a pane for the task'
sleep 2
contains "$(cat "$HOME/hb-set/web/task-ran.txt" 2>/dev/null)" 'from-env' 'the task runs in the project folder with the project values'
contains "$(HERDR_SESSION=hb-named herdr pane list | python3 -c 'import json,sys; print(",".join(p.get("label") or "" for p in json.load(sys.stdin)["result"]["panes"]))')" 'mark' 'the task pane has the name of the task'

# hopen --ports shows a port, its program, and its project.
# A random port, so that a program that holds a fixed port cannot break the test.
port=$((20000 + RANDOM % 20000))
(cd "$HOME/hb-set/web" && exec python3 -m http.server "$port" --bind 127.0.0.1 >/dev/null 2>&1) &
server_pid=$!
sleep 2
ports="$(hopen --ports 2>&1)"
contains "$ports" "$port" 'hopen --ports shows a port'
contains "$(grep "^${port} " <<<"$ports")" 'hb-named/web' 'hopen --ports shows the project of the program'
kill "$server_pid" 2>/dev/null

# A list runs its commands only after an approval, and again after a change.
mkdir -p "$HOME/hb-trust/w"
trust_list="$HOME/hb-trust/hb-trust.code-workspace"
printf '{ "folders": [ { "name": "w", "path": "./w" } ], "settings": { "hopen.onOpen": { "w": "touch ran.txt" } } }\n' >"$trust_list"
reset_trust() { herdr session stop hb-trust >/dev/null 2>&1; sleep 1; herdr session delete hb-trust >/dev/null 2>&1; rm -f "$HOME/hb-trust/w/ran.txt"; }
contains "$(hopen hb-trust --no-attach 2>&1 </dev/null)" 'did not use the commands' 'with no terminal, hopen does not run the commands of a new list'
sleep 2
check 'the command did not run' test ! -e "$HOME/hb-trust/w/ran.txt"
reset_trust
hopen hb-trust --no-attach --trust >/dev/null 2>&1 </dev/null
sleep 2
check 'with --trust, the command runs' test -f "$HOME/hb-trust/w/ran.txt"
reset_trust
hopen hb-trust --no-attach >/dev/null 2>&1 </dev/null
sleep 2
check 'an approved list runs its command on a later run' test -f "$HOME/hb-trust/w/ran.txt"
reset_trust
printf '{ "folders": [ { "name": "w", "path": "./w" } ], "settings": { "hopen.onOpen": { "w": "touch ran.txt && echo changed" } } }\n' >"$trust_list"
contains "$(hopen hb-trust --no-attach 2>&1 </dev/null)" 'did not use the commands' 'a changed list needs a new approval'
reset_trust
rm -rf "$HOME/hb-trust" "${XDG_STATE_HOME:-$HOME/.local/state}/hopen/hb-trust.tsv"

# A list that only claims the name of a session never takes it over.
mkdir -p "$HOME/hb-claim"
printf 'session = "hb-named"\n' >"$HOME/hb-claim/herdspace.toml"
printf '{ "folders": [], "settings": { "hopen.session": "hb-named" } }\n' >"$HOME/hb-claim/hb-claim.code-workspace"
contains "$(hopen --list 2>&1)" 'hopen skips' 'a list that claims a used session name is skipped'
rm -rf "$HOME/hb-claim"

# A template name from a list cannot leave the templates folder, and a control
# character in a command shows as "?" in the approval question.
mkdir -p "$HOME/hb-bad/w"
printf '{ "folders": [ { "name": "w", "path": "./w" } ], "settings": { "hopen.templates": { "w": "../../tmp/evil" }, "hopen.onOpen": { "w": "echo \\u001b[2Jhidden" } } }\n' >"$HOME/hb-bad/hb-bad.code-workspace"
bad_out="$(hopen hb-bad --no-attach 2>&1 </dev/null)"
contains "$bad_out" 'is not valid. hopen uses the default' 'a template name with a path is refused'
contains "$(HERDR_SESSION=hb-bad herdr pane list | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["result"]["panes"]))')" '2' 'the workspaces open with one pane each'
contains "$(printf 'n\n' | python3 "$ROOT/tests/pty_run.py" 6 'n\r' hopen hb-bad --no-attach 2>&1 | cat -v)" 'echo ?[2Jhidden' 'the approval question shows a control character as ?'
herdr session stop hb-bad >/dev/null 2>&1
sleep 1
herdr session delete hb-bad >/dev/null 2>&1
rm -rf "$HOME/hb-bad" "${XDG_STATE_HOME:-$HOME/.local/state}/hopen/hb-bad.tsv"

# herdspace.toml needs Python 3.11 or later.
if python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))'; then
  mkdir -p "$HOME/hb-toml/app"
  cat >"$HOME/hb-toml/herdspace.toml" <<'TOML'
template = "plain"
on_open = "touch parent-opened.txt"

[[project]]
name = "app"
path = "app"
tabs = [{ name = "logs" }]
TOML
  hopen hb-toml --no-attach --trust >/dev/null 2>&1
  # Give Auto Title time to name the new tab. hopen must keep the name.
  sleep 4
  contains "$(labels_of hb-toml)" 'hb-toml,app' 'herdspace.toml opens its projects'
  contains "$(tabs_of hb-toml app)" 'logs' 'herdspace.toml adds the tabs'
  sleep 2
  check 'herdspace.toml runs the on-open command' test -f "$HOME/hb-toml/parent-opened.txt"
  converted="$(hopen --convert hb-named 2>&1)"
  contains "$converted" 'Wrote' 'hopen --convert writes a herdspace.toml'
  contains "$(cat "$HOME/hb-named/herdspace.toml" 2>/dev/null)" 'name = "logs"' 'the converted file has the tabs'
  contains "$(hopen --list 2>&1)" 'claims the session hb-named' 'the converted list wins over the list that only claims its name'
  contains "$(hopen --convert hb-named 2>&1)" 'exists' 'hopen --convert never replaces a file'
  herdr session stop hb-toml >/dev/null 2>&1
  sleep 1
  herdr session delete hb-toml >/dev/null 2>&1
  rm -rf "$HOME/hb-toml" "$HOME/hb-named" "${XDG_STATE_HOME:-$HOME/.local/state}/hopen/hb-toml.tsv"
else
  pass 'herdspace.toml checks skipped: Python is older than 3.11'
fi
herdr session stop hb-named >/dev/null 2>&1
sleep 1
herdr session delete hb-named >/dev/null 2>&1
rm -rf "$HOME/hb-set" "${XDG_STATE_HOME:-$HOME/.local/state}/hopen/hb-named.tsv"

printf 'RESULT failures=%s\n' "$failures"
[ "$failures" -eq 0 ]
