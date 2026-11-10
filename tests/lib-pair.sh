#!/usr/bin/env bash
# lib-pair.sh starts two throwaway containers: a server and a Linux client with
# a virtual display. Scripts in tests/ source it. It needs Docker.
#
# Set OPEN_CMD to the command that the Ghostty window runs on the client.
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
# shellcheck disable=SC2034 # The scripts that source this file read status.
fail() { echo "FAIL $1"; status=1; }

docker network create "$net" >/dev/null || exit 1
docker build -q --build-arg BASE=ubuntu:24.04 -f tests/Dockerfile.linux -t hb-test-srv . >/dev/null || exit 1
docker build -q --build-arg "BASE=${CLIENT_BASE:-ubuntu:26.04}" -f tests/Dockerfile.client -t hb-test-cli . >/dev/null || exit 1
docker run -d --name "$srv" --network "$net" --network-alias my-server --user root hb-test-srv sleep 7200 >/dev/null || exit 1
docker run -d --name "$cli" --network "$net" hb-test-cli sleep 7200 >/dev/null || exit 1

# docker exec can start with no file mask, so set the usual one.
in_mask=(sh -c 'umask 022; exec "$@"' sh)
srv_root() { docker exec "$srv" "${in_mask[@]}" "$@"; }
srv_user() { docker exec -u tester -e LANG=C.UTF-8 -e PATH=/home/tester/.local/bin:/usr/local/bin:/usr/bin:/bin -w /home/tester/repo "$srv" "${in_mask[@]}" "$@"; }
cli_user() { docker exec -e LANG=C.UTF-8 -e DISPLAY=:9 -e LIBGL_ALWAYS_SOFTWARE=1 -e PATH=/home/tester/.local/bin:/usr/local/bin:/usr/bin:/bin -w /home/tester/repo "$cli" "${in_mask[@]}" "$@"; }


# pair_setup bootstraps both machines and connects them with an SSH key.
pair_setup() {
  srv_root bash -c 'apt-get update -qq >/dev/null; DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends openssh-server >/dev/null; mkdir -p /run/sshd; chmod 755 /run/sshd; /usr/sbin/sshd'
  flags="--skip-login-service"
  [ "${FULL:-0}" = "1" ] || flags="${flags} --skip-nvim-tools"
  srv_user bash -c "./bootstrap.sh server ${flags}" >tests/.work/client-server.log 2>&1 || fail 'server bootstrap'
  srv_user bash tests/demo-projects.sh
  srv_user bash -c 'python3 tests/pty_run.py 14 "exit\r" zsh -i' >/dev/null 2>&1

  cli_user bash -c 'mkdir -p ~/.ssh && ssh-keygen -q -t ed25519 -N "" -f ~/.ssh/id_ed25519 && printf "Host my-server\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null\n  LogLevel ERROR\n" >~/.ssh/config'
  key="$(cli_user cat /home/tester/.ssh/id_ed25519.pub)"
  srv_user bash -c "mkdir -p ~/.ssh && echo '${key}' >>~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
  if cli_user ./bootstrap.sh client --server my-server >tests/.work/client.log 2>&1; then pass 'client bootstrap'; else fail 'client bootstrap'; tail -n 8 tests/.work/client.log; fi
}

# open_ghostty starts the display and a Ghostty window that runs OPEN_CMD.
open_ghostty() {
  cli_user bash -c 'Xvfb :9 -screen 0 1400x940x24 +extension GLX >/tmp/x 2>&1 &'
  sleep 2
  cli_user bash -c 'openbox >/dev/null 2>&1 &'
  sleep 1
  cli_user bash -c "nohup dbus-run-session -- ghostty --window-width=150 --window-height=42 --command=${OPEN_CMD:-/home/tester/repo/tests/open-demo.sh} >/tmp/ghostty.log 2>&1 &"
  win=""
  for _ in $(seq 1 30); do
    win="$(cli_user xdotool search --onlyvisible --class ghostty 2>/dev/null | tail -n 1)"
    [ -n "$win" ] && break
    sleep 2
  done
  sleep 12
  if [ -z "$win" ]; then
    fail 'ghostty window'
    cli_user tail -n 5 /tmp/ghostty.log
    # Stop here. The key and screenshot steps wait forever without a window.
    echo "RESULT exit=1"
    exit 1
  fi
  cli_user xdotool windowactivate --sync "$win" >/dev/null 2>&1
}

key() { cli_user xdotool key --clearmodifiers "$@"; sleep "${WAIT:-2}"; }
type_text() { cli_user xdotool type --delay "${TYPE_DELAY:-40}" "$1"; sleep 0.5; cli_user xdotool key Return; sleep "${WAIT:-2}"; }
shot() { cli_user import -window "$win" "/tmp/$1.png"; docker cp "$cli:/tmp/$1.png" "tests/.work/shots/$1.png" >/dev/null; }
