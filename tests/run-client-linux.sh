#!/usr/bin/env bash
# run-client-linux.sh tests a Linux client with real Ghostty keys. One container
# is a server and one is a client with a virtual display. The test connects them
# with SSH, presses real keys, and saves screenshots in tests/.work/shots.
#
# Usage: tests/run-client-linux.sh
# Set FULL=1 for the Neovim language tools. Set CLIENT_BASE to test another image.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
mkdir -p tests/.work/shots
net="hb-test-net-$$"
srv="hb-test-srv-$$"
cli="hb-test-cli-$$"
# shellcheck disable=SC2329 # The trap calls this function.
cleanup() {
  docker rm -f "$srv" "$cli" >/dev/null 2>&1
  docker network rm "$net" >/dev/null 2>&1
  docker rmi -f hb-test-srv hb-test-cli >/dev/null 2>&1
}
trap cleanup EXIT
status=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; status=1; }

docker network create "$net" >/dev/null || exit 1
docker build -q --build-arg BASE=ubuntu:24.04 -f tests/Dockerfile.linux -t hb-test-srv . >/dev/null || exit 1
docker build -q --build-arg "BASE=${CLIENT_BASE:-ubuntu:26.04}" -f tests/Dockerfile.client -t hb-test-cli . >/dev/null || exit 1
docker run -d --name "$srv" --network "$net" --network-alias my-server --user root hb-test-srv sleep 3000 >/dev/null || exit 1
docker run -d --name "$cli" --network "$net" hb-test-cli sleep 3000 >/dev/null || exit 1

# docker exec can start with no file mask, so set the usual one.
in_mask=(sh -c 'umask 022; exec "$@"' sh)
srv_root() { docker exec "$srv" "${in_mask[@]}" "$@"; }
srv_user() { docker exec -u tester -e LANG=C.UTF-8 -e PATH=/home/tester/.local/bin:/usr/local/bin:/usr/bin:/bin -w /home/tester/repo "$srv" "${in_mask[@]}" "$@"; }
cli_user() { docker exec -e LANG=C.UTF-8 -e DISPLAY=:9 -e LIBGL_ALWAYS_SOFTWARE=1 -e PATH=/home/tester/.local/bin:/usr/local/bin:/usr/bin:/bin -w /home/tester/repo "$cli" "${in_mask[@]}" "$@"; }

srv_root bash -c 'apt-get update -qq >/dev/null; DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends openssh-server >/dev/null; mkdir -p /run/sshd; chmod 755 /run/sshd; /usr/sbin/sshd'
flags="--skip-login-service"
[ "${FULL:-0}" = "1" ] || flags="${flags} --skip-nvim-tools"
srv_user bash -c "./bootstrap-server-linux.sh ${flags}" >tests/.work/client-server.log 2>&1 || fail 'server bootstrap'
srv_user bash tests/demo-projects.sh
srv_user bash -c 'python3 tests/pty_run.py 14 "exit\r" zsh -i' >/dev/null 2>&1

cli_user bash -c 'mkdir -p ~/.ssh && ssh-keygen -q -t ed25519 -N "" -f ~/.ssh/id_ed25519 && printf "Host my-server\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null\n  LogLevel ERROR\n" >~/.ssh/config'
key="$(cli_user cat /home/tester/.ssh/id_ed25519.pub)"
srv_user bash -c "mkdir -p ~/.ssh && echo '${key}' >>~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"

if cli_user ./bootstrap-client-linux.sh --server my-server >tests/.work/client.log 2>&1; then pass 'client bootstrap'; else fail 'client bootstrap'; tail -n 8 tests/.work/client.log; fi
grep -E '\[(warn|err)\]' tests/.work/client.log | cut -c1-160
if cli_user cmp -s config/ghostty/config-linux.ghostty /home/tester/.config/ghostty/config.ghostty; then pass 'ghostty configuration'; else fail 'ghostty configuration'; fi
if srv_user infocmp -x xterm-ghostty >/dev/null 2>&1; then pass 'terminal description on the server'; else fail 'terminal description on the server'; fi
if cli_user grep -q 'BOOTSTRAP_PROMPT_COLOR=166' /home/tester/.config/herdr-bootstrap/env.zsh; then pass 'client prompt color'; else fail 'client prompt color'; fi
cli_user ./bootstrap-client-linux.sh --server my-server >/dev/null 2>&1 || fail 'second client run'
n="$(cli_user bash -c "find ~ -name '*.bak-*' -not -path '*/.cache/*' -not -path '*/.oh-my-zsh/*' -not -path '*/.local/*' | wc -l")"
if [ "$n" = 0 ]; then pass 'second run makes no backups'; else fail "second run makes no backups: ${n}"; fi

# Real Ghostty, real key presses, over SSH.
cli_user bash -c 'Xvfb :9 -screen 0 1400x940x24 +extension GLX >/tmp/x 2>&1 &'
sleep 2
cli_user bash -c 'openbox >/dev/null 2>&1 &'
sleep 1
cli_user bash -c 'nohup dbus-run-session -- ghostty --window-width=150 --window-height=42 --command=/home/tester/repo/tests/open-demo.sh >/tmp/ghostty.log 2>&1 &'
sleep 18
win="$(cli_user xdotool search --class ghostty | tail -n 1)"
[ -n "$win" ] || fail 'ghostty window'
cli_user xdotool windowactivate --sync "$win" >/dev/null 2>&1
key() { cli_user xdotool key --clearmodifiers "$@"; sleep "${WAIT:-2}"; }
type_text() { cli_user xdotool type --delay 40 "$1"; sleep 0.5; cli_user xdotool key Return; sleep "${WAIT:-2}"; }
shot() { cli_user import -window "$win" "/tmp/$1.png"; docker cp "$cli:/tmp/$1.png" "tests/.work/shots/$1.png" >/dev/null; }
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
