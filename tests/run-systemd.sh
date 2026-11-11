#!/usr/bin/env bash
# run-systemd.sh tests the Linux login service in a container with real systemd.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
# shellcheck source=tests/lib-docker.sh
source tests/lib-docker.sh
mkdir -p tests/.work
tag="hb-test-systemd"
name="${tag}-$$"
# shellcheck disable=SC2046 # build_flags prints one option or nothing.
docker build -q $(build_flags) -f tests/Dockerfile.systemd -t "$tag" . >/dev/null || exit 1
apt_cache_args ubuntu:24.04
docker run -d --rm --name "$name" --privileged --cgroupns=private ${APT_CACHE[@]+"${APT_CACHE[@]}"} \
  --tmpfs /run --tmpfs /run/lock "$tag" >/dev/null || exit 1
trap 'docker rm -f "$name" >/dev/null 2>&1; remove_images "$tag"' EXIT

uid="$(docker exec "$name" id -u tester)"
for _ in $(seq 1 60); do
  [ "$(docker exec "$name" systemctl is-system-running 2>/dev/null)" != starting ] && break
  sleep 1
done
docker exec "$name" loginctl enable-linger tester
for _ in $(seq 1 30); do
  docker exec "$name" test -S "/run/user/${uid}/bus" && break
  sleep 1
done

as_tester() {
  docker exec -u tester -w /home/tester/repo -e "XDG_RUNTIME_DIR=/run/user/${uid}" \
    -e "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus" -e LANG=C.UTF-8 \
    -e PATH=/home/tester/.local/bin:/usr/local/bin:/usr/bin:/bin -e HOME=/home/tester "$name" "$@"
}

status=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; status=1; }

as_tester ./bootstrap.sh server --skip-nvim-tools >tests/.work/systemd.log 2>&1 || fail 'bootstrap'
grep -E '\[(warn|err)\]' tests/.work/systemd.log | cut -c1-160
if [ "$(as_tester systemctl --user is-active herdr.service)" = active ]; then pass 'service is active'; else fail 'service is active'; fi
if [ "$(as_tester systemctl --user is-enabled herdr.service)" = enabled ]; then pass 'service is enabled'; else fail 'service is enabled'; fi
case "$(as_tester herdr workspace list 2>&1)" in *workspace_list*) pass 'herdr answers' ;; *) fail 'herdr answers' ;; esac
if docker exec "$name" loginctl show-user tester --property=Linger | grep -q yes; then pass 'linger is on'; else fail 'linger is on'; fi
before="$(as_tester systemctl --user show -p MainPID --value herdr.service)"
as_tester ./bootstrap.sh server --skip-nvim-tools >>tests/.work/systemd.log 2>&1 || fail 'second run'
after="$(as_tester systemctl --user show -p MainPID --value herdr.service)"
if [ -n "$before" ] && [ "$before" = "$after" ] && [ "$before" != 0 ]; then pass 'second run keeps the server'; else fail "second run keeps the server: ${before} ${after}"; fi
as_tester kill -9 "$before" >/dev/null 2>&1
for _ in $(seq 1 45); do
  now="$(as_tester systemctl --user show -p MainPID --value herdr.service)"
  [ -n "$now" ] && [ "$now" != 0 ] && [ "$now" != "$before" ] && break
  sleep 1
done
if [ "$now" != "$before" ] && [ "$now" != 0 ]; then pass 'service restarts after a crash'; else fail 'service restarts after a crash'; fi
if [ "$status" -ne 0 ]; then
  echo "== systemd state: $(docker exec "$name" systemctl is-system-running 2>&1)"
  docker logs "$name" 2>&1 | tail -n 30
fi
echo "RESULT exit=${status}"
exit "$status"
