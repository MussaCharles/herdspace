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
rm -rf "$work"

printf 'RESULT failures=%s\n' "$failures"
[ "$failures" -eq 0 ]
