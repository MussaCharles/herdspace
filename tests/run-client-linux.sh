#!/usr/bin/env bash
# run-client-linux.sh tests a Linux client with real Ghostty keys. One container
# is a server and one is a client with a virtual display. The test connects them
# with SSH, presses real keys, and saves screenshots in tests/.work/shots.
#
# Usage: tests/run-client-linux.sh
# Set FULL=1 for the Neovim language tools. Set CLIENT_BASE to test another image.
# shellcheck source=tests/lib-pair.sh
source "$(dirname "$0")/lib-pair.sh"

pair_setup
grep -E '\[(warn|err)\]' tests/.work/client.log | cut -c1-160
if cli_user cmp -s config/ghostty/config-linux.ghostty /home/tester/.config/ghostty/config.ghostty; then pass 'ghostty configuration'; else fail 'ghostty configuration'; fi
if srv_user infocmp -x xterm-ghostty >/dev/null 2>&1; then pass 'terminal description on the server'; else fail 'terminal description on the server'; fi
if cli_user grep -q 'BOOTSTRAP_PROMPT_COLOR=166' /home/tester/.config/herdr-bootstrap/env.zsh; then pass 'client prompt color'; else fail 'client prompt color'; fi
if cli_user tests/test-idempotent.sh bootstrap-client-linux.sh /home/tester/.config/ghostty/config.ghostty --server my-server >tests/.work/client-idem.log 2>&1; then pass 'idempotent client'; else fail 'idempotent client'; fi
grep -E '^(FAIL|RESULT)' tests/.work/client-idem.log | cut -c1-170

# Real Ghostty, real key presses, over SSH.
open_ghostty
# shellcheck disable=SC2016 # These commands run on the server.
tabs() { srv_user bash -c 'HERDR_SESSION=work herdr tab list --workspace "$(HERDR_SESSION=work herdr workspace list | python3 -c "import json,sys; print([w for w in json.load(sys.stdin)[\"result\"][\"workspaces\"] if w[\"focused\"]][0][\"workspace_id\"])")" | python3 -c "import json,sys; print(len(json.load(sys.stdin)[\"result\"][\"tabs\"]))"'; }
focused() { srv_user bash -c 'HERDR_SESSION=work herdr workspace list | python3 -c "import json,sys; print([w[\"label\"] for w in json.load(sys.stdin)[\"result\"][\"workspaces\"] if w[\"focused\"]][0])"'; }
shot sessions

before="$(tabs)"
key ctrl+shift+t
after="$(tabs)"
if [ "$after" = "$((before + 1))" ]; then pass 'Ctrl+Shift+T opens a Herdr tab'; else fail "Ctrl+Shift+T opens a Herdr tab: ${before} ${after}"; fi
key ctrl+shift+w
now="$(tabs)"
if [ -n "$now" ] && [ "$now" = "$before" ]; then pass 'Ctrl+Shift+W closes a Herdr tab'; else fail "Ctrl+Shift+W closes a Herdr tab: ${before} ${now}"; fi
key super+t
after="$(tabs)"
if [ "$after" = "$((before + 1))" ]; then pass 'Super+T (the Cmd key path) reaches Herdr'; else fail "Super+T reaches Herdr: ${before} ${after}"; fi
key ctrl+shift+w
start="$(focused)"
key ctrl+Down
moved="$(focused)"
if [ -n "$moved" ] && [ "$start" != "$moved" ]; then pass 'Ctrl+Down changes the workspace'; else fail "Ctrl+Down changes the workspace: ${start}"; fi
[ "$moved" = website ] || { echo "focused workspace is ${moved}"; }

key ctrl+b; key v
type_text 'clear; cd src && ls'
key ctrl+b; key h
type_text 'clear; git status --short'
sleep 1
shot panes
WAIT=16 type_text 'clear; nvim .'
key j; key j; WAIT=4 key j
shot neovim
key colon; WAIT=3 type_text 'qa!'
WAIT=5 key ctrl+shift+g
shot lazygit
case "$(srv_user bash -c 'pgrep -c lazygit')" in 0|'') fail 'Ctrl+Shift+G opens lazygit' ;; *) pass 'Ctrl+Shift+G opens lazygit' ;; esac
key q
WAIT=3 key ctrl+shift+k
shot go-to
key Escape
echo "RESULT exit=${status}"
exit "$status"
